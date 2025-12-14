-- lane.lua
-- Core sequencing unit. Each lane owns a motif and manages its playback through stages.
--
-- Responsibilities:
--   - State: playing, current_stage_index, motif, active_notes, trails
--   - Playback: play(), stop(), schedule_stage(), stage transitions
--   - Event scheduling: quantization, swing, speed scaling, conductor insertion
--   - Note output: routes to all active voices (MIDI, MX Samples, Crow, JF, wsyn, etc.)
--
-- Architecture debt: Voice routing (~350 lines) should be extracted to a VoiceRouter module.
-- The on_note_on/on_note_off methods handle 8 different voice types inline.

local mx_samples = include('lib/modes/motif/infrastructure/voices/mx_samples')
local Motif = include('lib/modes/motif/core/motif')
-- Stage type modules for mode-specific preparation
local tape_transform = include('lib/modes/motif/types/tape/transform')
local composer_generator = include('lib/modes/motif/types/composer/generator')
local sampler_transforms = include('lib/modes/motif/types/sampler/transforms')
-- Note: Performance state is accessed via _seeker.{type}.perform at runtime

-- Motif type constants
local TAPE_MODE = 1
local COMPOSER_MODE = 2
local SAMPLER_MODE = 3
local GridConstants = include('lib/grid/constants')
local theory = include('lib/modes/motif/core/theory')
local musicutil = require('musicutil')
local Lane = {}
Lane.__index = Lane

-- Quantization helper function
local function quantize_to_interval(time, interval_beats)
  if interval_beats <= 0 then
    return time -- No quantization
  end
  return math.floor(time / interval_beats + 0.5) * interval_beats
end

  -- Helper for trail keys
  local function trail_key(x, y)
    return string.format("%d,%d", x, y)
  end

-- Create a new lane with the given config
-- Config: { id, speed?, stages? }
function Lane.new(config)
  local lane = {}
  setmetatable(lane, Lane)

  -- Core identity and playback state
  lane.id = config.id
  lane.playing = false
  lane.instrument = params:get("lane_" .. lane.id .. "_instrument")
  lane.volume = params:get("lane_" .. lane.id .. "_volume")
  lane.speed = config.speed or 1.0
  lane.current_stage_index = 1
  lane.midi_out_device = params:get("lane_" .. lane.id .. "_midi_device")
  lane.delay_send = params:get("lane_" .. lane.id .. "_delay_send")
  lane.reverb_send = params:get("lane_" .. lane.id .. "_reverb_send")
  lane.chord_phase_offset = 0  -- Track chord position for phasing across loops

  -- Voice routing flags (cached from params, updated via param actions)
  lane.mx_samples_active = params:get("lane_" .. lane.id .. "_mx_samples_active") == 1
  lane.midi_active = params:get("lane_" .. lane.id .. "_midi_active") == 1
  lane.eurorack_active = params:get("lane_" .. lane.id .. "_eurorack_active") == 1
  lane.just_friends_active = params:get("lane_" .. lane.id .. "_just_friends_active") == 1
  lane.wsyn_active = params:get("lane_" .. lane.id .. "_wsyn_active") == 1
  lane.osc_active = params:get("lane_" .. lane.id .. "_osc_active") == 1
  lane.disting_active = params:get("lane_" .. lane.id .. "_disting_active") == 1
  lane.txo_osc_active = params:get("lane_" .. lane.id .. "_txo_osc_active") == 1

  -- Stage configuration (4 stages per lane, each with loops/active/reset_motif/transforms)
  -- Stage 1 defaults active, stages 2-4 default inactive
  lane.stages = config.stages or {
    {
      id = 1,
      active = true,
      mute = false,
      reset_motif = true,
      loops = 2,
      transforms = {
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        }
      }
    },
    {
      id = 2,
      active = false,
      mute = false,
      reset_motif = false,
      loops = 2,
      transforms = {
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        }
      }
    },
    {
      id = 3,
      active = false,
      mute = false,
      reset_motif = false,
      loops = 2,
      transforms = {
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        }
      }
    },
    {
      id = 4,
      active = false,
      mute = false,
      reset_motif = false,
      loops = 2,
      transforms = {
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        },
        {
          name = "none",
          config = {}
        }
      }
    }
  }
  
  -- Create empty motif
  lane.motif = Motif.new()
  
  -- Initialize stage loop counters
  for _, stage in ipairs(lane.stages) do
    stage.current_loop = 0
  end

  -- Sync stage configuration with params
  lane:sync_all_stages_from_params()
  
  -- Add trails state
  lane.trails = {}  -- Store fading note trails
  
  -- Add active notes tracking
  lane.active_notes = {}  -- Track currently active notes with their grid positions
  
  print(string.format('⌸ LANE_%d Manifested', lane.id))
  return lane
end

---------------------------------------------------------
-- Lane:play()
--   Start scheduling from the current stage, if playing = true
---------------------------------------------------------
function Lane:play()
  if #self.motif.events == 0 then 
    print('∅ No events to play')
    return
  end
  
  if not self.playing then
    self.playing = true
    -- Sync stage config from params before starting
    self:sync_all_stages_from_params()
    -- Reset motif and loop counters when starting playback
    self:reset_motif()
    for _, stage in ipairs(self.stages) do
      stage.current_loop = 0
    end
  end

  print(string.format('֍ Started LANE_%d', self.id))
  -- schedule the first iteration
  self:schedule_stage(self.current_stage_index, clock.get_beats())
end

---------------------------------------------------------
-- Lane:stop()
--   Stop scheduling further loops and reset loop counters
---------------------------------------------------------
function Lane:stop()
  self.playing = false
  -- Reset loop counters
  for _, stage in ipairs(self.stages) do
    stage.current_loop = 0
  end
  self.current_stage_index = 1
  -- Clear any pending events for this lane
  _seeker.conductor.clear_events_for_lane(self.id)
  print(string.format('֎ Stopped LANE_%d', self.id))
end

---------------------------------------------------------
-- prepare_stage(stage)
--   Prepares the working_motif for the stage by applying mode-specific transforms
--   Returns true if successful, false if transform failed
---------------------------------------------------------
function Lane:prepare_stage(stage)
  -- Delegate to mode-specific stage preparation
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")

  if motif_type == TAPE_MODE then
    tape_transform.prepare_stage(self.id, stage.id, self.motif)
  elseif motif_type == COMPOSER_MODE then
    composer_generator.prepare_stage(self.id, stage.id, self.motif)
  elseif motif_type == SAMPLER_MODE then
    -- Reset motif events to genesis if configured
    local reset_motif = params:get("lane_" .. self.id .. "_stage_" .. stage.id .. "_reset_motif") == 2
    if reset_motif then
      self.motif:reset_to_genesis()
    end
    -- Get and apply sampler transform (matching tape pattern)
    local transform_ui_name = params:string("lane_" .. self.id .. "_sampler_transform_stage_" .. stage.id)
    local transform_id = sampler_transforms.get_transform_id_by_ui_name(transform_ui_name)
    if transform_id and transform_id ~= "none" then
      local transform = sampler_transforms.available[transform_id]
      self.motif.events = transform.fn(self.motif.events, self.id, stage.id)
    end
  end

  return true
end

---------------------------------------------------------
-- schedule_stage(stage_index, start_time)
--   Core scheduling loop. Iterates motif events and inserts them into conductor.
--
--   Flow:
--   1. Prepare stage (apply mode-specific transforms)
--   2. For each event: apply quantize/swing, scale by speed, insert into conductor
--   3. Schedule end-of-loop callback (triggers next loop or stage transition)
--
--   Timing:
--   - base_duration: Motif length in beats (custom_duration or recorded)
--   - speed_adjusted_duration: base_duration / speed
--   - Events scheduled at: start_time + (event.time / speed)
---------------------------------------------------------
function Lane:schedule_stage(stage_index, start_time)
  local stage = self.stages[stage_index]

  -- Prepare the stage's motif FIRST (only on first loop or if reset_motif is true)
  if stage.current_loop == 0 or stage.reset_motif then
    if not self:prepare_stage(stage) then
      return
    end
  end

  -- Calculate timing info AFTER preparation
  local base_duration = self.motif:get_duration()
  local speed_adjusted_duration = base_duration / self.speed

  -- Store the start time in the stage for visualization synchronization
  stage.last_start_time = start_time
  
  -- Create visual markers for the hierarchy
  local stage_marker = stage.current_loop == 0 and "╔" or "╠"
  local timing_info = string.format("@%.2f", start_time)
  
  -- Print stage/loop info with timing
  -- print(string.format('%s══ L_%d S_%d (%d/%d loops) %s\n', 
    -- stage_marker,
    -- self.id,
    -- stage_index,
    -- stage.current_loop + 1,
    -- stage.loops,
    -- timing_info))
    
  local stage = self.stages[stage_index]

  -- Track which notes we've started playing to ensure proper note-off handling
  local active_notes = {}
  local first_event_time = nil

  -- Get quantization and swing settings
  local quantize_option = params:get("lane_" .. self.id .. "_quantize")
  local quantize_values = {0, 1/32, 1/16, 1/12, 1/11, 1/10, 1/9, 1/8, 1/7, 1/6, 1/5, 1/4, 1/3, 1/2, 1}
  local quantize_interval = quantize_values[quantize_option]
  local swing_amount = params:get("lane_" .. self.id .. "_swing") / 100

  -- Track timing offsets per note to preserve durations
  -- Use note+instance as key to handle polyphony
  local note_trigger_counts = {}
  local note_timing_offsets = {}

  -- Process all events in the motif
  for i, event in ipairs(self.motif.events) do
    local event_time = event.time

    if event.type == "note_on" then
      -- Only start notes that fall within the duration window
      if event_time <= base_duration then
        -- Track instance for polyphony support
        note_trigger_counts[event.note] = (note_trigger_counts[event.note] or 0) + 1
        local note_instance_id = event.note .. "_" .. note_trigger_counts[event.note]
        local total_offset = 0

        -- Apply quantization in musical time before speed scaling
        if quantize_interval > 0 then
          local quantized_time = quantize_to_interval(event_time, quantize_interval)
          local quantize_offset = quantized_time - event_time
          event_time = quantized_time
          total_offset = total_offset + quantize_offset

          -- Delay even subdivisions to create swing feel
          if swing_amount > 0 then
            local subdivision_position = event_time / quantize_interval
            local subdivision_index = math.floor(subdivision_position + 0.5)

            -- Even subdivisions get pushed later
            if subdivision_index % 2 == 0 then
              local swing_offset = quantize_interval * swing_amount * 0.5
              event_time = event_time + swing_offset
              total_offset = total_offset + swing_offset
            end
          end
        end

        -- Store offset for corresponding note_off
        note_timing_offsets[note_instance_id] = total_offset

        -- Scale timing by playback speed
        local speed_adjusted_time = event_time / self.speed
        local absolute_time = start_time + speed_adjusted_time
        
        if not stage.mute then
          -- Apply stage volume to velocity
          local stage_volume = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_volume")
          local velocity_with_stage_volume = event.velocity * stage_volume
          

          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = self.id,
            type = event.type,  -- Pass through the motif event type
            callback = function()
              self:on_note_on({
                note = event.note,
                velocity = velocity_with_stage_volume,
                x = event.x,
                y = event.y,
                is_playback = true,
                event_index = i,
                -- Tape mode values
                attack = event.attack,
                decay = event.decay,
                sustain = event.sustain,
                release = event.release,
                pan = event.pan,
                -- Sampler mode values
                fade_time = event.fade_time,
                rate = event.rate,
                pitch_offset = event.pitch_offset,
                max_volume = event.max_volume,
                mode = event.mode,
                filter_type = event.filter_type,
                lpf = event.lpf,
                hpf = event.hpf,
                resonance = event.resonance,
                start_pos = event.start_pos,
                stop_pos = event.stop_pos
              })
            end
          })
          -- Track that we started this note so we know to stop it
          active_notes[event.note] = true
        end
      end
    elseif event.type == "note_off" then
      -- Only process note-offs for notes we actually started
      if active_notes[event.note] then
        -- Find the most recent note_on for this note and apply same timing offset
        local note_instance_id = event.note .. "_" .. (note_trigger_counts[event.note] or 1)
        local offset = note_timing_offsets[note_instance_id] or 0

        -- Apply same timing offset as note_on to preserve duration
        event_time = event_time + offset

        -- If note would end after duration window, end it at window boundary
        if event_time > base_duration then
          event_time = base_duration
        end

        -- Apply speed adjustment
        local speed_adjusted_time = event_time / self.speed
        local absolute_time = start_time + speed_adjusted_time
        
        if not stage.mute then
          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = self.id,
            type = event.type,
            note = event.note,  -- Store the note in the event data
            callback = function() 
              self:on_note_off({
                note = event.note,
                velocity = 0,
                x = event.x,
                y = event.y,
                is_playback = true
              }) 
            end
          })
        end
      end
    end
  end
  
  -- Schedule the next loop or stage transition
  local end_time = start_time + speed_adjusted_duration
  
  _seeker.conductor.insert_event({
    time = end_time,
    lane_id = self.id,
    callback = function()
      if not self.playing then return end

      if stage.current_loop < (stage.loops - 1) then
        -- Continue to next loop of current stage
        stage.current_loop = stage.current_loop + 1
        self:schedule_stage(stage_index, end_time)  -- Use end_time as the start of next loop
      else
        -- Move to next stage
        print(string.format('╚══ L_%d S_%d complete @%.2f', self.id, stage_index, end_time))
        stage.current_loop = 0  -- Reset loop counter
        self:on_motif_end(stage_index, end_time)
      end
    end
  })

  -- Fire loop start trigger if configured
  local trigger = params:get("lane_" .. self.id .. "_loop_start_trigger")
  if trigger > 1 then
    -- Schedule the trigger at the start of the loop
    _seeker.conductor.insert_event({
      time = start_time,
      lane_id = self.id,
      callback = function()
        -- Convert 10ms to beats for conductor scheduling
        local trigger_duration_beats = 0.01 / clock.get_beat_sec()

        if trigger <= 5 then
          -- Crow trigger
          crow.output[trigger - 1].volts = 5
          -- Schedule trigger off after 10ms (converted to beats)
          _seeker.conductor.insert_event({
            time = clock.get_beats() + trigger_duration_beats,
            lane_id = self.id,
            callback = function()
              crow.output[trigger - 1].volts = 0
            end
          })
        else
          -- TXO trigger (subtract 5 to get 1-4 range)
          crow.ii.txo.tr(trigger - 5, 1)
          -- Schedule trigger off after 10ms (converted to beats)
          _seeker.conductor.insert_event({
            time = clock.get_beats() + trigger_duration_beats,
            lane_id = self.id,
            callback = function()
              crow.ii.txo.tr(trigger - 5, 0)
            end
          })
        end
        print(string.format("⚡ Loop start trigger fired for L_%d", self.id))
      end
    })
  end
  

  -- Trigger stage config button blink on stage start (first loop only)
  if stage.current_loop == 0 and self.id == _seeker.ui_state.get_focused_lane() then
    local motif_type = params:get("lane_" .. self.id .. "_motif_type")
    local stage_config = nil

    if motif_type == 1 and _seeker.tape and _seeker.tape.stage_config then
      stage_config = _seeker.tape.stage_config
    elseif motif_type == 3 and _seeker.sampler_type and _seeker.sampler_type.stage_config then
      stage_config = _seeker.sampler_type.stage_config
    end

    if stage_config and stage_config.grid then
      _seeker.conductor.insert_event({
        time = start_time,
        lane_id = self.id,
        callback = function()
          stage_config.grid:trigger_stage_blink(stage_index)
        end
      })
    end
  end

  -- Print debug info about events
  -- self:debug_print_events(false)
end

---------------------------------------------------------
-- on_motif_end(stage_index, end_time)
--   Called when all loops of the current stage are complete.
--   Advances to next stage or loops back to first stage.
--   Skips disabled stages during transition.
---------------------------------------------------------
function Lane:on_motif_end(stage_index, end_time)
  if not self.playing then
    return
  end

  -- Find the next active stage
  local next_index = stage_index + 1
  local stages_checked = 0
  
  -- Keep looking for the next active stage, wrapping around if needed
  while stages_checked < #self.stages do
    -- Wrap around to first stage if we've gone past the last stage
    if next_index > #self.stages then
      next_index = 1
    end
    
    -- Check if this stage is active
    if self.stages[next_index].active then
      break
    end
    
    -- This stage is inactive, try the next one
    next_index = next_index + 1
    stages_checked = stages_checked + 1
  end
  
  -- If no active stages found, stop playback
  if stages_checked >= #self.stages then
    print(string.format('⚠ No active stages found for L_%d, stopping playback', self.id))
    self:stop()
    return
  end
  
  self.current_stage_index = next_index
  self:schedule_stage(next_index, end_time)
  _seeker.ui_state.set_focused_stage(next_index)
end

---------------------------------------------------------
-- on_note_on(event)
--   Main note trigger. Called by conductor when a scheduled note_on fires.
--   Checks performance state, applies transforms, then routes to all active voices.
--
--   Event fields: note, velocity, x, y, is_playback, plus voice-specific params
--   (attack/decay/sustain/release/pan for tape, chop params for sampler)
---------------------------------------------------------
function Lane:on_note_on(event)
  -- Check performance mute by motif type
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")

  -- Tape performance
  local tape_performance = _seeker and _seeker.tape and _seeker.tape.perform
  if motif_type == TAPE_MODE and tape_performance and tape_performance.is_muted(self.id) then
    return
  end

  -- Sampler performance
  local sampler_performance = _seeker and _seeker.sampler_type and _seeker.sampler_type.perform
  if motif_type == SAMPLER_MODE and sampler_performance and sampler_performance.is_muted(self.id) then
    return
  end

  -- Composer performance
  local composer_performance = _seeker and _seeker.composer and _seeker.composer.perform
  if motif_type == COMPOSER_MODE and composer_performance and composer_performance.is_muted(self.id) then
    return
  end

  -- Apply performance velocity multiplier by motif type
  if motif_type == TAPE_MODE and tape_performance then
    event.velocity = event.velocity * tape_performance.get_velocity_multiplier(self.id)
  elseif motif_type == SAMPLER_MODE and sampler_performance then
    event.velocity = event.velocity * sampler_performance.get_velocity_multiplier(self.id)
  elseif motif_type == COMPOSER_MODE and composer_performance then
    event.velocity = event.velocity * composer_performance.get_velocity_multiplier(self.id)
  end

  -- Get the note, applying playback offset if this is a playback event
  local note = event.note
  if event.is_playback then
    -- This is a playback event, apply offsets that come from motif_playback component
    local octave_offset = params:get("lane_" .. self.id .. "_octave_offset") * 12
    local scale_degree_offset = params:get("lane_" .. self.id .. "_scale_degree_offset")
    
    if scale_degree_offset ~= 0 then
      -- Get current scale and find the new note by moving scale degrees
      local scale = musicutil.generate_scale(0, musicutil.SCALES[params:get("scale_type")].name, 128)
      -- Find current note's position in scale
      local current_pos = 1
      for i, scale_note in ipairs(scale) do
        if scale_note > note then break end
        if scale_note == note then current_pos = i end
      end
      -- Calculate new position and get the note
      local new_pos = current_pos + scale_degree_offset
      if new_pos >= 1 and new_pos <= #scale then
        note = scale[new_pos]
      end
    end
    
    -- Apply octave offset after scale degree offset
    note = note + octave_offset
  end

  -- Get all grid positions for this note
  local positions
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")

  if event.positions then
    positions = event.positions
  elseif event.x and event.y then
    -- Tape mode: notes may appear at multiple grid positions (same pitch on different rows)
    -- Composer/Sampler: each note has a single grid position from the event
    if motif_type == TAPE_MODE then
      local keyboard = _seeker.tape.type.get_keyboard()
      positions = keyboard.note_to_positions(note) or {{x = event.x, y = event.y}}
    else
      positions = {{x = event.x, y = event.y}}
    end
  end

  -- Store note with all its positions
  if positions then
    -- For composer keyboard mode, use step-based key to allow multiple simultaneous steps
    local motif_type = params:get("lane_" .. self.id .. "_motif_type")
    local note_key
    if motif_type == 2 and event.step then
      -- Composer mode: use step number as key to allow multiple active steps
      note_key = "step_" .. event.step
    else
      -- Tape mode: use note number as key (existing behavior)
      note_key = note
    end

    self.active_notes[note_key] = {
      positions = positions,
      note = note,
      velocity = event.velocity,
      original_note = event.note,
      event_index = event.event_index
    }

  end 

  --------------------------------
  -- VOICE OUTPUT ROUTING
  -- Routes note to all active voice outputs for this lane.
  -- Each voice type checks its _active flag before outputting.
  --------------------------------

  -- MIDI Output
  if self.midi_active then
    local midi_voice_volume = params:get("lane_" .. self.id .. "_midi_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    local device_idx = params:get("lane_" .. self.id .. "_midi_device")
    local channel = params:get("lane_" .. self.id .. "_midi_channel")
    if device_idx > 1 and channel > 0 then
      self.midi_out_device:note_on(note, event.velocity * midi_voice_volume * lane_volume, channel)
    end
  end

  --------------------------------
  -- MX Samples Output
  --------------------------------

  -- If MX Samples is active, play the event using that voice
  if self.mx_samples_active then
    -- Normalize velocity for MX Samples and apply both voice and lane volume
    local mx_voice_volume = params:get("lane_" .. self.id .. "_mx_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    local mx_samples_volume = (event.velocity / 127) * mx_voice_volume * lane_volume

    -- Play engine using instrument from params
    local instrument = self:get_instrument()
    if instrument then
      -- Get ADSR/pan values from event if it's playback, otherwise from current params
      local attack, decay, sustain, release, pan
      if event.is_playback then
        attack = event.attack
        decay = event.decay
        sustain = event.sustain
        release = event.release
        pan = event.pan
      else
        attack = params:get("lane_" .. self.id .. "_attack")
        decay = params:get("lane_" .. self.id .. "_decay")
        sustain = params:get("lane_" .. self.id .. "_sustain")
        release = params:get("lane_" .. self.id .. "_release")
        pan = params:get("lane_" .. self.id .. "_pan")
      end
      
      _seeker.skeys:on({
        name = instrument,
        midi = note,
        amp = mx_samples_volume,
        pan = pan,
        lpf = self.lpf,
        resonance = self.resonance,
        hpf = self.hpf,
        delay_send = self.delay_send or 0,
        reverb_send = self.reverb_send or 0,
        attack = attack,
        decay = decay,
        sustain = sustain,
        release = release
      })
    end
  end

  --------------------------------
  -- Sampler Output
  --------------------------------

  -- If in sampler mode, trigger the sampler pad
  if motif_type == SAMPLER_MODE then
    if _seeker and _seeker.sampler then
      -- Note number IS the pad number for sampler mode (1-16)
      -- Apply lane volume to velocity before passing to sampler
      local lane_volume = params:get("lane_" .. self.id .. "_volume")
      local scaled_velocity = event.velocity * lane_volume
      -- Pass full event so trigger_pad can use recorded chop values
      _seeker.sampler.trigger_pad(self.id, note, scaled_velocity, event)
    end
  end

  --------------------------------
  -- CV/Gate Output
  --------------------------------

  -- If CV/Gate is active, send the note via Crow/TXO
  if self.eurorack_active then
    -- Send hardware output if enabled
    local gate_out = params:get("lane_" .. self.id .. "_gate_out")
    local cv_out = params:get("lane_" .. self.id .. "_cv_out")
    
    -- Calculate CV voltage (V/oct)
    local cv_volts = (note - 12) / 12  -- Reference from C0 (MIDI note 12)
      
    -- Handle CV output
    if cv_out > 1 then
      if cv_out <= 5 then
        -- Crow CV
        crow.output[cv_out - 1].volts = cv_volts
      else
        -- TXO CV (subtract 5 to get 1-4 range as we're passing in an index from params that includes crow)
        crow.ii.txo.cv(cv_out - 5, cv_volts)
      end
    end
    
    -- Handle gate output
    if gate_out > 1 then
      if gate_out <= 5 then
        -- Calculate crow gate volume with 5v as max, applying both voice and lane volume
        local eurorack_voice_volume = params:get("lane_" .. self.id .. "_eurorack_voice_volume")
        local lane_volume = params:get("lane_" .. self.id .. "_volume")
        local gate_volume = eurorack_voice_volume * lane_volume
        crow.output[gate_out - 1].volts = gate_volume * 5
      else
        -- TXO gate (subtract 5 to get 1-4 as we're passing in an index from params that includes crow)
        crow.ii.txo.tr(gate_out - 5, 1)
      end
    end
  end

  --------------------------------
  -- Just Friends Output
  --------------------------------  

  -- Handle Just Friends if active
  if self.just_friends_active then
    -- Convert MIDI velocity (0-127) to JF velocity (0-10V), applying both voice and lane volume
    local just_friends_voice_volume = params:get("lane_" .. self.id .. "_just_friends_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    local jf_velocity = (event.velocity / 127) * just_friends_voice_volume * lane_volume * 5

    -- TODO: I'm not entirely sure why subtracting 60 bring this into a reasonable range. It's held over from previous code.
    local adjusted_note = note - 60
    local jf_voice_select = params:get("lane_" .. self.id .. "_just_friends_voice_select")
    if jf_voice_select == 1 then
      -- All voices (original behavior)
      crow.ii.jf.play_note(adjusted_note / 12, jf_velocity)
    else
      -- Individual voice (1-6)
      crow.ii.jf.play_voice(jf_voice_select - 1, adjusted_note / 12, jf_velocity)
    end
  end

  --------------------------------
  -- w/syn Output
  --------------------------------

  if self.wsyn_active then
    -- Apply both voice and lane volume
    local wsyn_voice_volume = params:get("lane_" .. self.id .. "_wsyn_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    local wsyn_volume = (event.velocity / 127) * wsyn_voice_volume * lane_volume
    -- TODO: I'm not entirely sure why subtracting 60 bring this into a reasonable range. It's held over from previous code.
    local adjusted_note = note - 60
    local wsyn_voice_select = params:get("lane_" .. self.id .. "_wsyn_voice_select")
    if wsyn_voice_select == 1 then
      -- All voices (Default/Dynamic)
      crow.ii.wsyn.play_note(adjusted_note/12, wsyn_volume)
    else
      -- Individual voice (1-6)
      crow.ii.wsyn.play_voice(wsyn_voice_select - 1, adjusted_note/12, wsyn_volume)
    end
  end

  --------------------------------
  -- OSC Output
  --------------------------------

  if self.osc_active then
    local dest_ip = params:get("osc_dest_octet_1") .. "." ..
                    params:get("osc_dest_octet_2") .. "." ..
                    params:get("osc_dest_octet_3") .. "." ..
                    params:get("osc_dest_octet_4")
    local dest_port = params:get("osc_dest_port")

    -- Send trigger high
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/trigger_active", {1})
    -- Send note value
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/note", {note})
    -- Send velocity
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/velocity", {event.velocity})
  end

  --------------------------------
  -- Disting EX Note On
  --------------------------------

  if self.disting_active then
    -- Set up event params
    local disting_voice_volume = params:get("lane_" .. self.id .. "_disting_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    -- TODO: volume_scaler is a magic number that seems to work. Need to understand what value range DEX is expecting.
    local volume_scaler = 12
    local disting_volume = (event.velocity * disting_voice_volume * lane_volume ) / volume_scaler
    local adjusted_note = note - 60
    local v8_note = adjusted_note / 12
    
    local algorithm = params:get("lane_" .. self.id .. "_disting_algorithm")
    -- Multisample
    if algorithm == 1 then
      crow.ii.disting.note_pitch(note, v8_note)
      crow.ii.disting.note_velocity(note, disting_volume)
      -- Rings
    elseif algorithm == 2 then
      -- N.B. Disting docs say to set voice number to 0. This seems to handle Resonator's internal polyphony.
      crow.ii.disting.voice_pitch(0, v8_note)
      crow.ii.disting.voice_on(0, disting_volume)
    -- Plaits
    elseif algorithm == 3 then
      -- Check if we're playing in poly or mono
      local polyphony = params:get("lane_" .. self.id .. "_disting_plaits_voice_select")
      if polyphony == 1 then
        crow.ii.disting.note_pitch(note, v8_note)
        crow.ii.disting.note_velocity(note, disting_volume)
      else
        -- N.B. Subtract 2 to handle lua 1 index and "All" voice option at start of list.
        local selected_voice = params:get("lane_" .. self.id .. "_disting_plaits_voice_select") - 2
        crow.ii.disting.voice_pitch(selected_voice, v8_note)
        crow.ii.disting.voice_on(selected_voice, disting_volume)
      end
    -- DX7
    elseif algorithm == 4 then
      crow.ii.disting.note_pitch(note, v8_note)
      crow.ii.disting.note_velocity(note, disting_volume)
    end
  end

  --------------------------------
  -- TXO Oscillator Output
  --------------------------------

  if self.txo_osc_active then
    local osc_select = params:get("lane_" .. self.id .. "_txo_osc_select")
    local mode = params:get("lane_" .. self.id .. "_txo_osc_mode")

    -- Set oscillator pitch (MIDI note number)
    crow.ii.txo.osc_n(osc_select, note)

    if mode == 2 then -- triggered mode: set CV and trigger AD envelope
      local txo_voice_volume = params:get("lane_" .. self.id .. "_txo_osc_volume")
      local lane_volume = params:get("lane_" .. self.id .. "_volume")
      local amplitude_volts = txo_voice_volume * lane_volume * (event.velocity / 127) * 5
      crow.ii.txo.cv(osc_select, amplitude_volts)
      crow.ii.txo.env_trig(osc_select, 1)
    end
    -- drone mode: CV already set high on activation, just pitch changes
  end

  --------------------------------
  -- GRID TRAIL VISUALIZATION
  -- Creates fading brightness trails on grid when notes play.
  -- Composer mode skips this (uses keyboard's built-in feedback).
  --------------------------------

  local motif_type = params:get("lane_" .. self.id .. "_motif_type")
  local is_composer_mode = (motif_type == 2)

  if is_composer_mode then
    return
  end

  -- Tape/Sampler: gradual fade trails
  local trail_brightness = GridConstants.BRIGHTNESS.HIGH
  local trail_decay = 0.95

  if positions then
    for _, pos in ipairs(positions) do
      local key = trail_key(pos.x, pos.y)
      self.trails[key] = {
        brightness = trail_brightness,
        decay = trail_decay,
        is_new = true  -- Mark as new activation
      }
    end
  elseif event.x and event.y then
    -- Fallback for direct position
    local key = trail_key(event.x, event.y)
    self.trails[key] = {
      brightness = trail_brightness,
      decay = trail_decay,
      is_new = true
    }
  end
end

---------------------------------------------------------
-- on_note_off(event)
--   Note release. Called by conductor when a scheduled note_off fires.
--   Stops voices, clears active note tracking, manages gate output.
---------------------------------------------------------
function Lane:on_note_off(event)
  -- Simple unconditional logging
  -- print("NOTE_OFF: note=" .. tostring(event.note))

  -- Get the note, applying playback offset if this is a playback event
  local note = event.note
  if event.is_playback then
    -- This is a playback event, apply offsets that come from motif_playback component
    local octave_offset = params:get("lane_" .. self.id .. "_octave_offset") * 12
    local scale_degree_offset = params:get("lane_" .. self.id .. "_scale_degree_offset")
    
    if scale_degree_offset ~= 0 then
      -- Get current scale and find the new note by moving scale degrees
      local scale = musicutil.generate_scale(0, musicutil.SCALES[params:get("scale_type")].name, 128)
      -- Find current note's position in scale
      local current_pos = 1
      for i, scale_note in ipairs(scale) do
        if scale_note > note then break end
        if scale_note == note then current_pos = i end
      end
      -- Calculate new position and get the note
      local new_pos = current_pos + scale_degree_offset
      if new_pos >= 1 and new_pos <= #scale then
        note = scale[new_pos]
      end
    end
    
    -- Apply octave offset after scale degree offset
    note = note + octave_offset
  end

  -- Stop MIDI if configured
  local device_idx = params:get("lane_" .. self.id .. "_midi_device")
  local channel = params:get("lane_" .. self.id .. "_midi_channel")
  if device_idx > 1 and channel > 0 then
    self.midi_out_device:note_off(note, 0, channel)
  end
  
  -- Send OSC note_off if configured
  if self.osc_active then
    local dest_ip = params:get("osc_dest_octet_1") .. "." ..
                    params:get("osc_dest_octet_2") .. "." ..
                    params:get("osc_dest_octet_3") .. "." ..
                    params:get("osc_dest_octet_4")
    local dest_port = params:get("osc_dest_port")

    -- Send trigger low
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/trigger_active", {0})
    -- Send note value
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/note", {note})
    -- Send velocity 0
    osc.send({dest_ip, dest_port}, "/seeker/lane/" .. self.id .. "/velocity", {0})
  end
  
  -- Stop engine using instrument from params
  local instrument = self:get_instrument()
  if instrument then
    _seeker.skeys:off({
      name = instrument,
      midi = note
    })
  end

  --------------------------------
  -- Disting EX note off
  --------------------------------
  if self.disting_active then
    local algorithm = params:get("lane_" .. self.id .. "_disting_algorithm")
    -- Convert note to v8 format for Disting EX
    local adjusted_note = note - 60
    local v8_note = adjusted_note / 12
    
    -- Multisample
    if algorithm == 1 then
      crow.ii.disting.note_off(note)
    -- Rings
    elseif algorithm == 2 then
      -- N.B. Subtract one to handle lua 1 index and disting 0 index
      local voice_select = params:get("lane_" .. self.id .. "_disting_rings_mode") - 1
      crow.ii.disting.voice_off(voice_select)
    -- Plaits
    elseif algorithm == 3 then
      local voice_select = params:get("lane_" .. self.id .. "_disting_plaits_voice_select")
      if voice_select == 1 then
        -- "All" mode uses note-based commands
        crow.ii.disting.note_off(note)
      else
        -- Specific voice: subtract 2 for lua 1-index + "All" option offset
        crow.ii.disting.voice_off(voice_select - 2)
      end
    -- DX7
    elseif algorithm == 4 then
      crow.ii.disting.note_off(note)

    end
  end

  --------------------------------
  -- TXO Oscillator note off
  --------------------------------
  -- drone mode: no action (stays on, just pitch changes)
  -- triggered mode: let AD envelope decay naturally (no action needed)

  --------------------------------
  -- Sampler Output
  --------------------------------

  -- Handle sampler note_off events according to pad mode settings (Gate/Loop/One-Shot)
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")
  if motif_type == SAMPLER_MODE then
    if _seeker and _seeker.sampler then
      local chop = _seeker.sampler.get_chop(self.id, note)
      if chop then
        -- Gate mode: stop playback on note_off
        if chop.mode == 1 then  -- MODE_GATE from sampler/manager.lua
          _seeker.sampler.stop_pad(self.id, note)
        end
        -- Loop mode: ignore note_off, let it loop continuously
        -- One-shot mode: already auto-stops after playback, ignore note_off
      end
    end
  end

  -- Stop hardware output if enabled
  local gate_out = params:get("lane_" .. self.id .. "_gate_out")
  
  -- Remove this note from active notes and get its positions
  -- Use same key logic as on_note_on for composer mode
  local note_key
  if motif_type == 2 and event.step then
    -- Composer mode: use step number as key to match on_note_on
    note_key = "step_" .. event.step
  else
    -- Tape mode: use note number as key (existing behavior)
    note_key = note
  end

  local note_data = self.active_notes[note_key]
  self.active_notes[note_key] = nil

  
  -- Count remaining active notes
  local remaining_notes = 0
  for _, active_note in pairs(self.active_notes) do
    remaining_notes = remaining_notes + 1
  end
  
  -- Only turn off gate if this was the last note
  if remaining_notes == 0 and gate_out > 1 then
    if gate_out <= 5 then
      -- Crow gate
      crow.output[gate_out - 1].volts = 0
    else
      -- TXo gate
      crow.ii.txo.tr(gate_out - 5, 0)
    end
  end

  -- Handle trails based on keyboard mode
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")
  local is_composer_mode = (motif_type == 2)

  if is_composer_mode then
    -- Composer mode: remove trails immediately for on/off behavior
    if note_data and note_data.positions then
      for _, pos in ipairs(note_data.positions) do
        local key = trail_key(pos.x, pos.y)
        self.trails[key] = nil  -- Remove trail immediately
      end
    elseif event.x and event.y then
      local key = trail_key(event.x, event.y)
      self.trails[key] = nil  -- Remove trail immediately
    end
  else
    -- Tape mode: create fading trails (existing behavior)
    if note_data and note_data.positions then
      for _, pos in ipairs(note_data.positions) do
        local key = trail_key(pos.x, pos.y)
        self.trails[key] = {
          brightness = GridConstants.BRIGHTNESS.HIGH,
          decay = 0.95,
          is_new = true  -- Mark as new activation
        }
      end
    elseif event.x and event.y then
      local key = trail_key(event.x, event.y)
      self.trails[key] = {
        brightness = GridConstants.BRIGHTNESS.HIGH,
        decay = 0.95,
        is_new = true
      }
    end
  end
end

function Lane:reset_motif()
  self.motif:reset_to_genesis()
end

function Lane:get_instrument()
  local instrument_id = params:get("lane_" .. self.id .. "_instrument")
  local instruments = mx_samples.get_instrument_list()

  if self.id == 99 then
    return instruments[1]
  else
    return instruments[instrument_id]
  end
end

-- Set motif data after recording
function Lane:set_motif(recorded_data)
  self.motif:store_events(recorded_data)
  return self.motif
end

-- Clear lane state and motif data
function Lane:clear()
  self:stop()  -- Stop playback
  self.motif:clear()  -- Clear motif data
end

---------------------------------------------------------
-- change_stage_transform(stage_index, transform_index, transform_name)
---------------------------------------------------------
function Lane:change_stage_transform(lane_idx, stage_idx, transform_idx, transform_name)
  local stage = self.stages[stage_idx]
  local transform = transforms.available[transform_name]

  -- Initialize config with defaults
  local transform_config = {}
  for param_name, param_spec in pairs(transform.params) do
    transform_config[param_name] = param_spec.default
  end

  -- Update the transform at the specified index
  stage.transforms[transform_idx] = {
    name = transform_name,
    config = transform_config
  }
end

---------------------------------------------------------
-- sync_stage_from_params(stage_index)
--   Syncs a stage's configuration with its parameters
---------------------------------------------------------
function Lane:sync_stage_from_params(stage_index)
    local stage = self.stages[stage_index]
    stage.active = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_active") == 2
    stage.reset_motif = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_reset_motif") == 2
    stage.loops = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_loops")
end

---------------------------------------------------------
-- sync_all_stages_from_params()
--   Syncs all stages' configuration with their parameters
---------------------------------------------------------
function Lane:sync_all_stages_from_params()
    for i = 1, #self.stages do
        self:sync_stage_from_params(i)
    end
end

function Lane:get_active_positions()
  local positions = {}
  local motif_type = params:get("lane_" .. self.id .. "_motif_type")

  -- For composer mode, use note-based illumination
  if motif_type == 2 then
    if not self.playing then
      return positions
    end

    local composer_keyboard = _seeker.composer.keyboard.grid
    for key, note in pairs(self.active_notes) do
      local current_positions = composer_keyboard.note_to_positions(note.note)
      if current_positions then
        for _, pos in ipairs(current_positions) do
          table.insert(positions, {x = pos.x, y = pos.y, note = note.note})
        end
      end
    end

    return positions
  end

  -- For sampler mode, use stored positions from active_notes
  if motif_type == SAMPLER_MODE then
    for key, note in pairs(self.active_notes) do
      if note.positions then
        for _, pos in ipairs(note.positions) do
          table.insert(positions, {x = pos.x, y = pos.y})
        end
      end
    end
    return positions
  end

  -- Tape mode: illuminate all grid positions where this note appears
  local keyboard = _seeker.tape.type.get_keyboard()

  for key, note in pairs(self.active_notes) do
    local current_positions = keyboard.note_to_positions(note.note)
    if current_positions then
      for _, pos in ipairs(current_positions) do
        table.insert(positions, {x = pos.x, y = pos.y})
      end
    end
  end

  return positions
end

-- Helper function to convert interval string to beats (copied from motif_recorder.lua)
function Lane:_interval_to_beats(interval_str)
  if tonumber(interval_str) then
    return tonumber(interval_str)
  end
  local num, den = interval_str:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num) / tonumber(den)
  end
  return 1/8
end

-- Temporary debug function for event timing
function Lane:debug_print_events(show_notes)
  print("\n⎆ ═══ Event Debug Info ═══\n")
  print(string.format("⌸ Lane %d  ◈  Stage %d  ◈  Loop %d/%d\n", 
    self.id, 
    self.current_stage_index,
    self.stages[self.current_stage_index].current_loop + 1,
    self.stages[self.current_stage_index].loops))
  print(string.format("∿ Duration: %.2f (%.2f at %.1fx speed)\n", 
    self.motif:get_duration(),
    self.motif:get_duration() / self.speed,
    self.speed))
  
  -- Count transforms that aren't none
  local active_transforms = 0
  for _, transform in ipairs(self.stages[self.current_stage_index].transforms) do
    if transform.name ~= "none" then
      active_transforms = active_transforms + 1
    end
  end
  
  print(string.format("♫ Events: %d  ⎊ Active Transforms: %d\n", #self.motif.events, active_transforms))

  -- Detailed note listing if requested
  if show_notes then
    print("\n--- Note Events ---")
    for i, evt in ipairs(self.motif.events) do
      if evt.type == "note_on" then
        print(string.format("[%d] ON  t=%.2f note=%d pos=(%d,%d) vel=%d", 
          i, evt.time, evt.note, evt.x or -1, evt.y or -1, evt.velocity))
      elseif evt.type == "note_off" then
        print(string.format("[%d] OFF t=%.2f note=%d pos=(%d,%d)", 
          i, evt.time, evt.note, evt.x or -1, evt.y or -1))
      end
    end
    print("----------------\n")
  end
  
  print("⎆ ═════════════════════\n")
end

return Lane
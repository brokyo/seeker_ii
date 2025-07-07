-- lane.lua
local params_manager_ii = include('lib/params_manager_ii')
local Motif = include('lib/motif_ii')
local forms = include('lib/forms')
local transforms = include('lib/transforms')
local GridConstants = include('lib/grid_constants')
local theory = include('lib/theory_utils')
local musicutil = require('musicutil')
local Lane = {}
Lane.__index = Lane

  -- Helper for trail keys
  local function trail_key(x, y)
    return string.format("%d,%d", x, y)
  end

function Lane.new(config)
  local lane = {}
  setmetatable(lane, Lane)

  -- Copy over config fields matching archetype structure
  lane.id = config.id
  lane.playing = false
  lane.instrument = params:get("lane_" .. lane.id .. "_instrument")
  lane.volume = params:get("lane_" .. lane.id .. "_volume")
  lane.speed = config.speed or 1.0
  lane.current_stage_index = 1 
  lane.midi_out_device = params:get("lane_" .. lane.id .. "_midi_device")
  lane.delay_send = params:get("lane_" .. lane.id .. "_delay_send")
  lane.reverb_send = params:get("lane_" .. lane.id .. "_reverb_send")
  
  -- Initialize with four default stages if none provided
  lane.stages = config.stages or {
    {
      id = 1,
      enabled = true,
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
      enabled = false,
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
      enabled = false,
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
      enabled = false,
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
--   Prepares the working_motif for the stage by applying its transform
--   Returns true if successful, false if transform failed
---------------------------------------------------------
function Lane:prepare_stage(stage)
  local reset_motif = params:get("lane_" .. self.id .. "_stage_" .. stage.id .. "_reset_motif") == 1
  
  if reset_motif then
    self.motif:reset_to_genesis()
  end
  
  local transform_ui_name = params:string("lane_" .. self.id .. "_transform_stage_" .. stage.id)
  local transform_id = transforms.get_transform_id_by_ui_name(transform_ui_name)
  if transform_id and transform_id ~= "none" then
    self.motif:apply_transform(transform_id, self.id, stage.id)
  end
  
  return true
end

---------------------------------------------------------
-- schedule_stage(stage_index, start_time)
--   Creates the series of note events for a single pass of that stage.
--   Handles looping within the stage before moving to next stage.
--   
--   Key timing concepts:
--   - base_duration: The effective duration (custom or recorded)
--   - speed_adjusted_duration: Duration modified by lane's speed
--   - loop_offset: Time offset for current loop iteration
---------------------------------------------------------
function Lane:schedule_stage(stage_index, start_time)
  -- Calculate timing info for logging
  local stage = self.stages[stage_index]
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
  
  -- Process all events in the motif
  for i, event in ipairs(self.motif.events) do
    local event_time = event.time
    
    if event.type == "note_on" then
      -- Only start notes that fall within the duration window
      if event_time <= base_duration then
        local speed_adjusted_time = event_time / self.speed
        local absolute_time = start_time + speed_adjusted_time
        
        if not stage.mute then
          _seeker.conductor.insert_event({
            time = absolute_time,
            lane_id = self.id,
            type = event.type,  -- Pass through the motif event type
            callback = function() 
              self:on_note_on({
                note = event.note,
                velocity = event.velocity,
                x = event.x,
                y = event.y,
                is_playback = true,
                event_index = i,
                -- Pass through the stored ADSR and pan values
                attack = event.attack,
                decay = event.decay,
                sustain = event.sustain,
                release = event.release,
                pan = event.pan
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
        local speed_adjusted_time = event_time / self.speed
        
        -- If note would end after duration window, end it at window boundary
        if event_time > base_duration then
          speed_adjusted_time = base_duration / self.speed
        end
        
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
        if trigger <= 5 then
          -- Crow trigger
          crow.output[trigger - 1].volts = 5
          -- Schedule trigger off after 10ms
          _seeker.conductor.insert_event({
            time = start_time + 0.01,
            lane_id = self.id,
            callback = function()
              crow.output[trigger - 1].volts = 0
            end
          })
        else
          -- TXO trigger (subtract 5 to get 1-4 range)
          crow.ii.txo.tr(trigger - 5, 1)
          -- Schedule trigger off after 10ms
          _seeker.conductor.insert_event({
            time = start_time + 0.01,
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
  
  -- Prepare the stage's motif (only on first loop or if reset_motif is true)
  if stage.current_loop == 0 or stage.reset_motif then
    if not self:prepare_stage(stage) then
      return
    end
  end

  -- Trigger stage_config button blink on stage start (first loop only)
  if stage.current_loop == 0 and _seeker.stage_config and _seeker.stage_config.grid then
    -- Only trigger for the focused lane
    if self.id == _seeker.ui_state.get_focused_lane() then
      _seeker.conductor.insert_event({
        time = start_time,
        lane_id = self.id,
        callback = function()
          _seeker.stage_config.grid:trigger_stage_blink(stage_index)
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

  -- Find the next enabled stage
  local next_index = stage_index + 1
  local stages_checked = 0
  
  -- Keep looking for the next enabled stage, wrapping around if needed
  while stages_checked < #self.stages do
    -- Wrap around to first stage if we've gone past the last stage
    if next_index > #self.stages then
      next_index = 1
    end
    
    -- Check if this stage is enabled
    if self.stages[next_index].enabled then
      break
    end
    
    -- This stage is disabled, try the next one
    next_index = next_index + 1
    stages_checked = stages_checked + 1
  end
  
  -- If no enabled stages found, stop playback
  if stages_checked >= #self.stages then
    print(string.format('⚠ No enabled stages found for L_%d, stopping playback', self.id))
    self:stop()
    return
  end
  
  self.current_stage_index = next_index
  self:schedule_stage(next_index, end_time)
  _seeker.ui_state.set_focused_stage(next_index)
end

---------------------------------------------------------
-- on_note_on(note)
--   Send MIDI or engine note_on
---------------------------------------------------------
function Lane:on_note_on(event)
  -- Get the note, applying playback offset if this is a playback event
  local note = event.note
  if event.is_playback then
    -- This is a playback event, apply offsets that come from `MotifSection`
    local octave_offset = params:get("lane_" .. self.id .. "_playback_offset") * 12
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
  if event.positions then
    positions = event.positions
  elseif event.x and event.y then
    -- If we only got a single position, get all positions for this note
    local keyboard_octave = params:get("lane_" .. self.id .. "_keyboard_octave")
    positions = theory.note_to_grid(note, keyboard_octave) or {{x = event.x, y = event.y}}
  end

  -- Store note with all its positions
  if positions then
    self.active_notes[note] = {
      positions = positions,
      note = note,
      velocity = event.velocity,
      original_note = event.note,
      event_index = event.event_index
    }
  end 

  -- If MIDI is active, play the note
  local midi_active = params:get("lane_" .. self.id .. "_midi_active")
  if midi_active == 1 then
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
  local mx_samples_active = params:get("lane_" .. self.id .. "_mx_samples_active")
  if mx_samples_active == 1 then
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
  -- CV/Gate Output
  --------------------------------

  -- If CV/Gate is active, send the note via Crow/TXO
  local cv_gate_active = params:get("lane_" .. self.id .. "_eurorack_active")
  if cv_gate_active == 1 then
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
        local euro_voice_volume = params:get("lane_" .. self.id .. "_euro_voice_volume")
        local lane_volume = params:get("lane_" .. self.id .. "_volume")
        local gate_volume = euro_voice_volume * lane_volume
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
  local just_friends_active = params:get("lane_" .. self.id .. "_just_friends_active")

  if just_friends_active == 1 then
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

  local wsyn_active = params:get("lane_" .. self.id .. "_wsyn_active")
  if wsyn_active == 1 then
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

  local osc_active = params:get("lane_" .. self.id .. "_osc_active")
  if osc_active == 1 then
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

  local disting_ex_active = params:get("lane_" .. self.id .. "_disting_ex_active")
  if disting_ex_active == 1 then
    -- Set up event params
    local disting_ex_voice_volume = params:get("lane_" .. self.id .. "_disting_ex_voice_volume")
    local lane_volume = params:get("lane_" .. self.id .. "_volume")
    -- TODO: This calculation seems to be ignored
    local disting_ex_volume = (event.velocity / 127) * disting_ex_voice_volume * lane_volume    
    local adjusted_note = note - 60
    local v8_note = adjusted_note / 12
    
    local algorithm = params:get("lane_" .. self.id .. "_disting_ex_algorithm")
    if algorithm == 1 then
      -- N.B. Subtract one to handle lua 1 index and disting 0 index
      local selected_voice = params:get("lane_" .. self.id .. "_disting_ex_macro_osc_2_voice_select") - 1
      crow.ii.disting.voice_pitch(selected_voice, v8_note)
      crow.ii.disting.voice_on(selected_voice, disting_ex_volume)
    elseif algorithm == 2 then
      crow.ii.disting.note_pitch(4, v8_note)
      crow.ii.disting.note_velocity(4, disting_ex_volume)
    end
  end
end

---------------------------------------------------------
-- on_note_off(note)
---------------------------------------------------------
function Lane:on_note_off(event)
  -- Get the note, applying playback offset if this is a playback event
  local note = event.note
  if event.is_playback then
    -- This is a playback event, apply offsets that come from `MotifSection`
    local octave_offset = params:get("lane_" .. self.id .. "_playback_offset") * 12
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
  local osc_active = params:get("lane_" .. self.id .. "_osc_active")
  if osc_active == 1 then
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
  local disting_ex_active = params:get("lane_" .. self.id .. "_disting_ex_active")
  if disting_ex_active == 1 then
    local algorithm = params:get("lane_" .. self.id .. "_disting_ex_algorithm")
    if algorithm == 1 then
      -- N.B. Subtract one to handle lua 1 index and disting 0 index
      local voice_select = params:get("lane_" .. self.id .. "_disting_ex_macro_osc_2_voice_select") - 1
      crow.ii.disting.voice_off(voice_select)
    elseif algorithm == 2 then
      crow.ii.disting.note_off(0)
    end
  end

  -- Stop hardware output if enabled
  local gate_out = params:get("lane_" .. self.id .. "_gate_out")
  
  -- Remove this note from active notes and get its positions
  local note_data = self.active_notes[note]
  self.active_notes[note] = nil
  
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

  -- Add trails for all positions
  if note_data and note_data.positions then
    for _, pos in ipairs(note_data.positions) do
      local key = trail_key(pos.x, pos.y)
      -- Create new trail or update existing one to full brightness
      self.trails[key] = {
        brightness = GridConstants.BRIGHTNESS.HIGH,
        decay = 0.95,
        is_new = true  -- Mark as new activation
      }
    end
  elseif event.x and event.y then
    -- Fallback for direct position
    local key = trail_key(event.x, event.y)
    self.trails[key] = {
      brightness = GridConstants.BRIGHTNESS.HIGH,
      decay = 0.95,
      is_new = true
    }
  end
end

function Lane:reset_motif()
  self.motif:reset_to_genesis()
end

function Lane:get_instrument()
  local instrument_id = params:get("lane_" .. self.id .. "_instrument")
  local instruments = params_manager_ii.get_instrument_list()

  if self.id == 99 then
    return instruments[1]
  else
    return instruments[instrument_id]
  end
end

-- Set motif data after recording
function Lane:set_motif(recorded_data)
  -- Add debug to verify events have positions
  for _, evt in ipairs(recorded_data.events) do
  end
  self.motif:store_events(recorded_data)
  return self.motif
end

-- Clear lane state and motif data
function Lane:clear()
  self:stop()  -- Stop playback
  self.motif:clear()  -- Clear motif data
end

---------------------------------------------------------
-- apply_arrangement(arrangement_name)
--   Apply an arrangement preset to this lane's stages
---------------------------------------------------------
function Lane:apply_arrangement(arrangement_name)
    local arrangement = forms.arrangements[arrangement_name]    
    for i, stage_config in ipairs(arrangement.stages) do
        -- Copy all fields from the stage config
        for k, v in pairs(stage_config) do
            if k == "transform_config" then
                -- Deep copy transform config
                self.stages[i][k] = {}
                for param_k, param_v in pairs(v) do
                    self.stages[i][k][param_k] = param_v
                end
            else
                self.stages[i][k] = v
            end
        end
    end
end

---------------------------------------------------------
-- update_stage_param(stage_num, param_name, value)
--   Update a parameter for a specific stage
---------------------------------------------------------
function Lane:update_stage_param(stage_num, param_name, value)
    local stage = self.stages[stage_num]
    stage.transform_config[param_name] = value
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
    stage.enabled = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_enabled") == 1
    stage.mute = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_mute") == 1
    stage.reset_motif = params:get("lane_" .. self.id .. "_stage_" .. stage_index .. "_reset_motif") == 1
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
  local keyboard_octave = params:get("lane_" .. self.id .. "_keyboard_octave")
  
  for _, note in pairs(self.active_notes) do
    -- Recalculate positions based on current octave
    local current_positions = theory.note_to_grid(note.note, keyboard_octave)
    if current_positions then
      for _, pos in ipairs(current_positions) do
        table.insert(positions, {x = pos.x, y = pos.y})
      end
    end
  end
  return positions
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
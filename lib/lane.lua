-- lane.lua
local params_manager_ii = include('lib/params_manager_ii')
local Motif = include('lib/motif_ii')
local forms = include('lib/forms')
local transforms = include('lib/transforms')
local GridConstants = include('lib/grid_constants')
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
  
  -- Initialize with four default stages if none provided
  lane.stages = config.stages or {
    {
      id = 1,
      mute = false,
      reset_motif = true,
      loops = 4,
      transforms = {
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        }
      }
    },
    {
      id = 2,
      mute = false,
      reset_motif = false,
      loops = 4,
      transforms = {
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        }
      }
    },
    {
      id = 3,
      mute = false,
      reset_motif = false,
      loops = 4,
      transforms = {
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        }
      }
    },
    {
      id = 4,
      mute = false,
      reset_motif = false,
      loops = 4,
      transforms = {
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
          config = {}
        },
        {
          name = "noop",
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
  print(string.format('֎ Stopped LANE_%d', self.id))
end

---------------------------------------------------------
-- prepare_stage(stage)
--   Prepares the working_motif for the stage by applying its transform
--   Returns true if successful, false if transform failed
---------------------------------------------------------
function Lane:prepare_stage(stage)
  -- Reset motif if stage requires it
  if stage.reset_motif then
    self.motif:reset_to_genesis()
  end
  
  -- Apply each transform in sequence
  for _, transform in ipairs(stage.transforms) do
    self.motif:apply_transform(transform.name, transform.config)
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
  local loop_offset = stage.current_loop * speed_adjusted_duration
  
  -- Create visual markers for the hierarchy
  local stage_marker = stage.current_loop == 0 and "╔" or "╠"
  local timing_info = string.format("@%.2f", start_time)
  
  -- Print stage/loop info with timing
  print(string.format('%s══ L_%d S_%d (%d/%d loops) %s\n', 
    stage_marker,
    self.id,
    stage_index,
    stage.current_loop + 1,
    stage.loops,
    timing_info))
    
  local stage = self.stages[stage_index]
  
  -- Prepare the stage's motif (only on first loop or if reset_motif is true)
  if stage.current_loop == 0 or stage.reset_motif then
    if not self:prepare_stage(stage) then
      return
    end
  end

  -- Print debug info about events
  self:debug_print_events()

  -- Track which notes we've started playing to ensure proper note-off handling
  local active_notes = {}
  
  -- Process all events in the motif
  for _, event in ipairs(self.motif.events) do
    local event_time = event.time
    
    if event.type == "note_on" then
      -- Only start notes that fall within the duration window
      if event_time <= base_duration then
        local speed_adjusted_time = event_time / self.speed
        local absolute_time = start_time + speed_adjusted_time + loop_offset
        
        if not stage.mute then
          _seeker.conductor.insert_event({
            time = absolute_time,
            callback = function() 
              self:on_note_on({
                note = event.note,
                velocity = event.velocity * self.volume,
                x = event.x,
                y = event.y
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
        
        local absolute_time = start_time + speed_adjusted_time + loop_offset
        
        if not stage.mute then
          _seeker.conductor.insert_event({
            time = absolute_time,
            callback = function() 
              self:on_note_off({
                note = event.note,
                velocity = 0,
                x = event.x,
                y = event.y
              }) 
            end
          })
        end
      end
    end
  end
  
  -- Schedule the next loop or stage transition
  local end_time = start_time + speed_adjusted_duration  -- Remove loop_offset from end_time calculation
  
  _seeker.conductor.insert_event({
    time = end_time,
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
end

---------------------------------------------------------
-- on_motif_end(stage_index, end_time)
--   Called when all loops of the current stage are complete.
--   Advances to next stage or loops back to first stage.
---------------------------------------------------------
function Lane:on_motif_end(stage_index, end_time)
  if not self.playing then
    return
  end

  local next_index = stage_index + 1
  if next_index > #self.stages then
    next_index = 1
  end
  self.current_stage_index = next_index

  self:schedule_stage(next_index, end_time)
end

---------------------------------------------------------
-- on_note_on(note)
--   Send MIDI or engine note_on
---------------------------------------------------------
function Lane:on_note_on(event)
  -- Play MIDI if configured
  local device_idx = params:get("lane_" .. self.id .. "_midi_device")
  local channel = params:get("lane_" .. self.id .. "_midi_channel")
  if device_idx > 1 and channel > 0 then
    self.midi_out_device:note_on(event.note, event.velocity * self.volume, channel)
  end

  -- Play engine using instrument from params
  local instrument = self:get_instrument()
  if instrument then
    _seeker.skeys:on({
      name = instrument,
      midi = event.note,
      velocity = event.velocity * self.volume
    })
  end

  -- Send crow output if enabled
  local gate_out = params:get("lane_" .. self.id .. "_crow_gate")
  local cv_out = params:get("lane_" .. self.id .. "_crow_cv")
  
  -- Handle CV output
  if cv_out > 0 then
    -- Set CV output (V/oct)
    local cv_volts = (event.note - 60) / 12
    crow.output[cv_out].volts = cv_volts
  end
  
  -- Handle gate output independently
  if gate_out > 0 then
    -- Set gate high
    crow.output[gate_out].volts = 5
  end

  -- Track active note with grid position
  if event.x and event.y then
    local key = event.note
    self.active_notes[key] = {
      x = event.x,
      y = event.y,
      note = event.note,
      velocity = event.velocity
    }
  end
end

---------------------------------------------------------
-- on_note_off(note)
---------------------------------------------------------
function Lane:on_note_off(event)
  -- Stop MIDI if configured
  local device_idx = params:get("lane_" .. self.id .. "_midi_device")
  local channel = params:get("lane_" .. self.id .. "_midi_channel")
  if device_idx > 1 and channel > 0 then
    self.midi_out_device:note_off(event.note, 0, channel)
  end
  
  -- Stop engine using instrument from params
  local instrument = self:get_instrument()
  if instrument then
    _seeker.skeys:off({
      name = instrument,
      midi = event.note
    })
  end

  -- Stop crow output if enabled
  local gate_out = params:get("lane_" .. self.id .. "_crow_gate")
  if gate_out > 0 then
    -- Only set gate low if this was the last active note
    local has_active_notes = false
    for _ in pairs(self.active_notes) do
      has_active_notes = true
      break
    end
    if not has_active_notes then
      -- Set gate low
      crow.output[gate_out].volts = 0
    end
  end

  -- Add trail and remove from active notes
  if event.x and event.y then
    local key = trail_key(event.x, event.y)
    self.trails[key] = {
      brightness = GridConstants.BRIGHTNESS.HIGH,
      decay = 0.95
    }
    -- Remove from active notes
    self.active_notes[event.note] = nil
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
  for _, note in pairs(self.active_notes) do
    if note.x and note.y then
      table.insert(positions, {x = note.x, y = note.y})
    end
  end
  return positions
end

-- Temporary debug function for event timing
function Lane:debug_print_events()
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
  
  -- Count transforms that aren't noop
  local active_transforms = 0
  for _, transform in ipairs(self.stages[self.current_stage_index].transforms) do
    if transform.name ~= "noop" then
      active_transforms = active_transforms + 1
    end
  end
  
  print(string.format("♫ Events: %d  ⎊ Active Transforms: %d\n", #self.motif.events, active_transforms))
  print("⎆ ═════════════════════\n")
end

return Lane
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
      reset_motif = false,
      loops = 1,
      transform_name = "noop",
      transform_config = {}
    },
    {
      id = 2,
      mute = false,
      reset_motif = false,
      loops = 1,
      transform_name = "noop",
      transform_config = {}
    },
    {
      id = 3,
      mute = false,
      reset_motif = false,
      loops = 1,
      transform_name = "noop",
      transform_config = {}
    },
    {
      id = 4,
      mute = false,
      reset_motif = false,
      loops = 1,
      transform_name = "noop",
      transform_config = {}
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
  
  -- Apply stage transform if it has one
  if stage.transform_name then
    self.motif:apply_transform(stage.transform_name, stage.transform_config)
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
  print(string.format('〰 Scheduling L_%s S_%s (loop %d/%d)', 
    self.id,
    stage_index, 
    self.stages[stage_index].current_loop + 1,
    self.stages[stage_index].loops))
    
  local stage = self.stages[stage_index]
  
  -- Prepare the stage's motif (only on first loop or if reset_motif is true)
  if stage.current_loop == 0 or stage.reset_motif then
    if not self:prepare_stage(stage) then
      return
    end
  end

  -- Print debug info about events
  self:debug_print_events()

  -- Calculate timing parameters for this stage
  local base_duration = self.motif:get_duration()
  local speed_adjusted_duration = base_duration / self.speed
  local loop_offset = stage.current_loop * speed_adjusted_duration

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
  local end_time = start_time + speed_adjusted_duration + loop_offset
  
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
        stage.current_loop = 0  -- Reset loop counter
        self:on_motif_end(stage_index)
      end
    end
  })
end

---------------------------------------------------------
-- on_motif_end(stage_index)
--   Called when all loops of the current stage are complete.
--   Advances to next stage or loops back to first stage.
---------------------------------------------------------
function Lane:on_motif_end(stage_index)
  if not self.playing then
    return
  end

  local next_index = stage_index + 1
  if next_index > #self.stages then
    next_index = 1
  end
  self.current_stage_index = next_index

  local now = clock.get_beats()
  self:schedule_stage(next_index, now)
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
-- change_stage_transform(stage_index, transform_name)
---------------------------------------------------------
function Lane:change_stage_transform(lane_idx, stage_idx, transform_name)
  local stage = self.stages[stage_idx]
  local transform = transforms.available[transform_name]

  -- Update the stage's transform name
  stage.transform_name = transform_name
  
  -- Reset transform config with defaults
  stage.transform_config = {}
  for param_name, param_spec in pairs(transform.params) do
    stage.transform_config[param_name] = param_spec.default
  end
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
  print("\n⎆ ═══ Event Debug Info ═══")
  print(string.format("⌸ Lane %d  ◈  Stage %d  ◈  Loop %d/%d", 
    self.id, 
    self.current_stage_index,
    self.stages[self.current_stage_index].current_loop + 1,
    self.stages[self.current_stage_index].loops))
  print("∿ Base duration: " .. self.motif:get_duration())
  print("∿ Speed adjusted: " .. self.motif:get_duration() / self.speed)
  print("\n♫ Events:")
  for i, event in ipairs(self.motif.events) do
    print(string.format("  %d │ %s │ note: %s │ time: %.3f │ pos: (%s,%s)", 
      i,
      event.type == "note_on" and "▶" or "⏹",
      event.note or "∅",
      event.time or 0,
      event.x or "∅",
      event.y or "∅"))
  end
  print("⎆ ═════════════════════\n")
end

return Lane
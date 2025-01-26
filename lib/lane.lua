-- lane.lua
local Transforms = include('lib/transforms')
local params_manager_ii = include('lib/params_manager_ii')

local Lane = {}
Lane.__index = Lane

function Lane.new(config)
  local lane = {}
  setmetatable(lane, Lane)

  -- Copy over config fields matching archetype structure
  lane.id = config.id
  lane.playing = false
  lane.voice = config.voice or ""
  lane.volume = config.volume or 1.0
  lane.midi = config.midi or {}
  lane.speed = config.speed or 1.0
  lane.stages = config.stages or {}
  lane.original_motif = config.motif or {}
  lane.working_motif = config.motif or {} 
  lane.motif_duration = config.motif_duration or 1.0

  -- Initialize stage loop counters
  for _, stage in ipairs(lane.stages) do
    stage.current_loop = 0
  end

  lane.current_stage_index = 1 
  print(string.format('⌸ LANE_%d 実体化', lane.id))
  return lane
end

---------------------------------------------------------
-- Lane:play()
--   Start scheduling from the current stage, if playing = true
---------------------------------------------------------
function Lane:play()
  if not self.playing then
    self.playing = true
    -- Reset motif and loop counters when starting playback
    self:reset_motif()
    for _, stage in ipairs(self.stages) do
      stage.current_loop = 0
    end
  end
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
end

---------------------------------------------------------
-- prepare_stage(stage)
--   Prepares the working_motif for the stage by applying its transform
--   Returns true if successful, false if transform failed
---------------------------------------------------------
function Lane:prepare_stage(stage)
  -- Reset motif if stage requires it
  if stage.reset_motif then
    self:reset_motif()
  end
  
  -- Apply stage transform if it has one
  if stage.transform_name then
    local transformed_motif = Transforms.apply(stage.transform_name, self.working_motif, stage.transform_config or {})
    self.working_motif = transformed_motif
  end
  
  return true
end

---------------------------------------------------------
-- schedule_stage(stage_index, start_time)
--   Creates the series of note events for a single pass of that stage.
--   Handles looping within the stage before moving to next stage.
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

  -- Calculate loop offset for timing
  local loop_offset = (stage.current_loop * self.motif_duration * self.speed)
  
  -- Schedule all events with loop offset
  for _, event in ipairs(self.working_motif) do
    local absolute_time = start_time + (event.time * self.speed) + loop_offset
    
    if event.type == "note_on" and not stage.mute then
      _seeker.conductor.insert_event({
        time = absolute_time,
        callback = function() 
          self:on_note_on({
            note = event.note,
            velocity = math.min(127, event.velocity * self.volume)
          }) 
        end
      })
    elseif event.type == "note_off" and not stage.mute then
      _seeker.conductor.insert_event({
        time = absolute_time,
        callback = function() self:on_note_off(event) end
      })
    end
  end

  -- Schedule end of current loop
  local end_time = start_time + (self.motif_duration * self.speed) + loop_offset
  _seeker.conductor.insert_event({
    time = end_time,
    callback = function()
      if not self.playing then return end
      
      if stage.current_loop < (stage.loops - 1) then
        -- Continue to next loop of current stage
        stage.current_loop = stage.current_loop + 1
        self:schedule_stage(stage_index, start_time)
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
-- on_note_on(event)
--   Send MIDI or engine note_on
---------------------------------------------------------
function Lane:on_note_on(event)
  -- Play MIDI if configured
  if self.midi.device then
    local device = midi.connect(self.midi.device)
    device:note_on(event.note, event.velocity, self.midi.channel)
  end
  
  -- Play engine using instrument from params
  local instrument = self:get_instrument()
  if instrument then
    _seeker.skeys:on({
      name = instrument,
      midi = event.note,
      velocity = event.velocity
    })
  end
end

---------------------------------------------------------
-- on_note_off(event)
---------------------------------------------------------
function Lane:on_note_off(event)
  -- Stop MIDI if configured
  if self.midi.device then
    local device = midi.connect(self.midi.device)
    device:note_off(event.note, 0, self.midi.channel)
  end
  
  -- Stop engine using instrument from params
  local instrument = self:get_instrument()
  if instrument then
    _seeker.skeys:off({
      name = instrument,
      midi = event.note
    })
  end
end

function Lane:reset_motif()
  -- Deep copy the original motif to working_motif
  self.working_motif = {}
  for _, event in ipairs(self.original_motif) do
    local cloned = {
      time = event.time,
      type = event.type,
      note = event.note,
      velocity = event.velocity
    }
    table.insert(self.working_motif, cloned)
  end
end

function Lane:get_instrument()
  -- Always use Lane 1's instrument for our test Lane 99
  local lane_id = self.id == 99 and 1 or self.id
  local instrument_id = params:get("lane_" .. lane_id .. "_instrument")
  local instruments = params_manager_ii.get_instrument_list()
  return instruments[instrument_id]
end

return Lane

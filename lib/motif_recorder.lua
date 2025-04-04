-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note events

local theory = include('lib/theory_utils')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m:reset_state()
  return m
end

-- Reset all internal state
function MotifRecorder:reset_state()
  self.is_recording = false
  self.events = {}
  self.start_time = 0
  self.loop_length = nil
  self.waiting_for_first_note = false
  self.original_motif = nil  -- Track original motif for overdub
  self.current_generation = 1  -- Track which generation we're recording
end

-- Helper function to quantize a beat value using global quantize division
function MotifRecorder:_quantize_beat(beat)
  -- Get selected division string (e.g. "1/16") and extract denominator
  local division_str = params:lookup_param("quantize_division").options[params:get("quantize_division")]
  local denom = tonumber(division_str:match("/(%d+)"))
  return math.floor(beat * denom + 0.5) / denom
end

--- onNoteOn: called when a grid button is pressed (z=1)
function MotifRecorder:on_note_on(event)
  if not self.is_recording then return end
   
  -- If this is our first note in a new recording, set the start time with a small offset
  if self.waiting_for_first_note then
    self.start_time = clock.get_beats() - 0.02  -- Small offset for scheduling
    self.waiting_for_first_note = false
  end

  -- Calculate timing
  local now = clock.get_beats()
  local position
  
  if self.loop_length then
    -- For overdub, properly sync with current playback position
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[focused_lane]
    
    if lane.playing then
      -- Get timing from the currently playing stage
      local current_stage = lane.stages[lane.current_stage_index]
      if current_stage.last_start_time then
        -- Calculate position based on lane's stage start time, same as visualization
        local elapsed_time = now - current_stage.last_start_time
        position = (elapsed_time * lane.speed) % self.loop_length
      else
        -- Fallback if stage start time not available
        position = now % self.loop_length
      end
    else
      -- Not playing, use modulo loop length
      position = now % self.loop_length
    end
  else
    -- For new recording, measure from start
    position = now - self.start_time
  end
  
  local quantized_time = self:_quantize_beat(position)
  if self.loop_length then
    print(string.format("⊕ Recording note %d at position: %.3f (gen: %d)", event.note, quantized_time, self.current_generation))
  end
    
  -- Store note_on event
  local focused_lane = _seeker.ui_state.get_focused_lane()
  table.insert(self.events, {
    time = quantized_time,
    type = "note_on",
    note = event.note,
    velocity = event.velocity,
    x = event.x,
    y = event.y,
    generation = self.current_generation,
    attack = params:get("lane_" .. focused_lane .. "_attack"),
    decay = params:get("lane_" .. focused_lane .. "_decay"),
    sustain = params:get("lane_" .. focused_lane .. "_sustain"),
    release = params:get("lane_" .. focused_lane .. "_release"),
    pan = params:get("lane_" .. focused_lane .. "_pan")
  })
end

--- onNoteOff: called when a grid button is released (z=0)
function MotifRecorder:on_note_off(event)
  if not self.is_recording then return end

  -- Calculate timing
  local now = clock.get_beats()
  local position
  
  if self.loop_length then
    -- For overdub, properly sync with current playback position
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[focused_lane]
    
    if lane.playing then
      -- Get timing from the currently playing stage
      local current_stage = lane.stages[lane.current_stage_index]
      if current_stage.last_start_time then
        -- Calculate position based on lane's stage start time, same as visualization
        local elapsed_time = now - current_stage.last_start_time
        position = (elapsed_time * lane.speed) % self.loop_length
      else
        -- Fallback if stage start time not available
        position = now % self.loop_length
      end
    else
      -- Not playing, use modulo loop length
      position = now % self.loop_length
    end
  else
    -- For new recording, measure from start
    position = now - self.start_time
  end
  
  local quantized_time = self:_quantize_beat(position)
  
  -- Store note_off event
  table.insert(self.events, {
    time = quantized_time,
    type = "note_off",
    note = event.note,
    x = event.x,
    y = event.y,
    generation = self.current_generation  -- Add generation to event
  })
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording(existing_motif)
  -- First reset all state
  self:reset_state()
  
  -- If overdubbing, store original duration and events
  if params:get("recording_mode") == 2 and existing_motif then -- 2 = Overdub
    self.loop_length = existing_motif.duration
    self.original_motif = existing_motif -- Store reference to original
    
    -- Copy existing events and preserve their generations
    local max_gen = 1
    for _, evt in ipairs(existing_motif.events) do
      -- Add events to recorder
      table.insert(self.events, {
        time = evt.time,
        type = evt.type,
        note = evt.note,
        velocity = evt.velocity,
        x = evt.x,
        y = evt.y,
        generation = evt.generation,
        attack = evt.attack,
        decay = evt.decay,
        sustain = evt.sustain,
        release = evt.release,
        pan = evt.pan
      })
      
      -- Track the highest generation we've seen
      if evt.generation and evt.generation > max_gen then
        max_gen = evt.generation
      end
    end
    
    -- Set new generation for upcoming events
    self.current_generation = max_gen + 1
    print(string.format("⊕ Starting overdub with generation %d", self.current_generation))
  else
    -- New recording
    self.waiting_for_first_note = true  -- Only set this for new recordings
    self.current_generation = 1
  end

  -- Start recording
  self.is_recording = true
end

--- Stop recording and return the event table
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:stop_recording()
  if not self.is_recording then return end
  
  self.is_recording = false
  
  -- Sort all events by time
  table.sort(self.events, function(a, b)
    return a.time < b.time
  end)
  
  -- Create recorded data package
  local recorded_data = {
    events = self.events,
    duration = self.loop_length or (clock.get_beats() - self.start_time)
  }

  -- Clear recorder state
  self.events = {}
  self.loop_length = nil
  print("⊞ Recording stopped")
  return recorded_data
end

return MotifRecorder
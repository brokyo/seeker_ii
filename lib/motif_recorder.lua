-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note events

local theory = include('lib/theory_utils')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.recording_mode = 1  -- 1 = New, 2 = Overdub, 3 = Arpeggio
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
  
  -- Arpeggio mode state
  self.arpeggio_step = 0  -- Current step in arpeggio sequence
  self.arpeggio_interval = 1  -- Interval between steps in beats
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
  
  -- Handle arpeggio mode differently
  if self.recording_mode == 3 then
    self:_arpeggio_add_note(event)
    return
  end
   
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
  
  -- Arpeggio mode doesn't use note_off events during recording
  if self.recording_mode == 3 then
    return
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

--- Set the recording mode
-- @param mode: 1 for New, 2 for Overdub
function MotifRecorder:set_recording_mode(mode)
  self.recording_mode = mode
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording(existing_motif)
  -- Reset all state
  self:reset_state()
  
  -- If overdubbing, store original duration and events
  if self.recording_mode == 2 and existing_motif then -- 2 = Overdub
    print('we dubbing')
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
    print('we recording')
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

--- Helper function to convert interval string to beats
function MotifRecorder:_interval_to_beats(interval_str)
  if tonumber(interval_str) then
    return tonumber(interval_str)
  end
  local num, den = interval_str:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num) / tonumber(den)
  end
  return 1/8
end

--- Add a note to the arpeggio sequence
function MotifRecorder:_arpeggio_add_note(event)
  -- Get interval directly from params
  local interval_str = params:string("arpeggio_interval")
  self.arpeggio_interval = self:_interval_to_beats(interval_str)
  
  local note_time = self.arpeggio_step * self.arpeggio_interval
  local focused_lane = _seeker.ui_state.get_focused_lane()
  
  -- Add note_on event
  table.insert(self.events, {
    time = note_time,
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
  
  -- Add note_off event at the end of the interval (slightly before next step)
  local note_off_time = note_time + (self.arpeggio_interval * 0.9) -- 90% of interval duration
  table.insert(self.events, {
    time = note_off_time,
    type = "note_off",
    note = event.note,
    x = event.x,
    y = event.y,
    generation = self.current_generation
  })
  
  self.arpeggio_step = self.arpeggio_step + 1
  print(string.format("♪ Arpeggio step %d: note %d at %.3f beats", self.arpeggio_step, event.note, note_time))
end

--- Add a rest to the arpeggio sequence
function MotifRecorder:add_arpeggio_rest()
  if not self.is_recording or self.recording_mode ~= 3 then return end
  
  -- Get interval directly from params
  local interval_str = params:string("arpeggio_interval")
  self.arpeggio_interval = self:_interval_to_beats(interval_str)
  
  local rest_time = self.arpeggio_step * self.arpeggio_interval
  
  -- Add rest event
  table.insert(self.events, {
    time = rest_time,
    type = "rest",
    generation = self.current_generation
  })
  
  self.arpeggio_step = self.arpeggio_step + 1
  print(string.format("♪ Arpeggio step %d: rest at %.3f beats", self.arpeggio_step, rest_time))
end

--- Start arpeggio recording
function MotifRecorder:start_arpeggio_recording()
  self:reset_state()
  self.recording_mode = 3
  self.is_recording = true
  self.arpeggio_step = 0
  print("♪ Starting arpeggio recording")
end

--- Stop arpeggio recording and return the event table
function MotifRecorder:stop_arpeggio_recording()
  if not self.is_recording or self.recording_mode ~= 3 then return end
  
  self.is_recording = false
  
  -- Sort all events by time
  table.sort(self.events, function(a, b)
    return a.time < b.time
  end)
  
  -- Calculate total duration based on steps
  local total_duration = self.arpeggio_step * self.arpeggio_interval
  
  -- Create recorded data package
  local recorded_data = {
    events = self.events,
    duration = total_duration
  }

  -- Clear recorder state
  self.events = {}
  self.arpeggio_step = 0
  print("♪ Arpeggio recording stopped")
  return recorded_data
end

return MotifRecorder
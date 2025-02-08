-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note events

local theory = include('lib/theory_utils')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.is_recording = false
  m.events = {}
  m.start_time = 0
  m.loop_length = nil -- Duration to wrap events to during overdub
  m.waiting_for_first_note = false 
  return m
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
    -- For overdub, just use the current position in the loop
    position = now % self.loop_length
  else
    -- For new recording, measure from start
    position = now - self.start_time
  end
  
  local quantized_time = self:_quantize_beat(position)
  if self.loop_length then
    print(string.format("⊕ Recording note %d at position: %.3f", event.note, quantized_time))
  end
    
  -- Store note_on event
  table.insert(self.events, {
    time = quantized_time,
    type = "note_on",
    note = event.note,
    velocity = event.velocity,
    x = event.x,
    y = event.y
  })
end

--- onNoteOff: called when a grid button is released (z=0)
function MotifRecorder:on_note_off(event)
  if not self.is_recording then return end

  -- Calculate timing
  local now = clock.get_beats()
  local position
  
  if self.loop_length then
    -- For overdub, just use the current position in the loop
    position = now % self.loop_length
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
    y = event.y
  })
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording(existing_motif)
  -- If overdubbing, store original duration and events
  if params:get("recording_mode") == 2 and existing_motif then -- 2 = Overdub
    self.loop_length = existing_motif.duration
    -- Copy existing events
    self.events = {}
    for _, evt in ipairs(existing_motif.events) do
      table.insert(self.events, {
        time = evt.time,
        type = evt.type,
        note = evt.note,
        velocity = evt.velocity,
        x = evt.x,
        y = evt.y
      })
    end
    
  else
    -- New recording
    self.events = {}
    self.loop_length = nil
    self.waiting_for_first_note = true  -- Only set this for new recordings
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
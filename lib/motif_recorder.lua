-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note eventsto

local theory = include('lib/theory_utils')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.is_recording = false
  m.events = {}  -- Stores all note_on/note_off events
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
-- n.b We don't yet have velocity but may eventually 
function MotifRecorder:on_note_on(event)
   -- Calculate timing
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  local quantized_time = self:_quantize_beat(time_from_start)
  
  -- Store note_on event
  table.insert(self.events, {
    time = quantized_time,
    type = "note_on",
    note = event.note,
    velocity = event.velocity,
    pos = {x = event.x, y = event.y}
  })
end

--- onNoteOff: called when a grid button is released (z=0)
function MotifRecorder:on_note_off(event)
  -- Calculate timing
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  local quantized_time = self:_quantize_beat(time_from_start)
  
  -- Store note_off event
  table.insert(self.events, {
    time = quantized_time,
    type = "note_off",
    note = event.note,
    pos = {x = event.x, y = event.y}
  })
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording()  
  self.is_recording = true
  self.events = {}
  self.start_time = clock.get_beats()
  print("⧉ Recording started")
end

--- Stop recording and return the event table
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:stop_recording(lane_num)
  if not self.is_recording then return end
  
  self.is_recording = false
  local end_time = clock.get_beats()
  local recorded_duration = end_time - self.start_time
  
  -- Sort all events by time
  table.sort(self.events, function(a, b)
    return a.time < b.time
  end)
  
  -- Create recorded data package
  local recorded_data = {
    events = self.events,
    duration = recorded_duration
  }

  -- Clear recorder state
  self.events = {}
  print("⊞ Recording stopped")
  return recorded_data
end

return MotifRecorder
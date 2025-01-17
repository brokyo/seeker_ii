-- motif_recorder.lua
-- Uses norns clock system for timing

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder
local logger = include('lib/logger')

--- Constructor
-- @param opts (optional) table of settings:
--    * quantize: quantization amount in beats (default = nil for no quantization)
function MotifRecorder.new(opts)
  local mr = setmetatable({}, MotifRecorder)
  opts = opts or {}
  
  -- Quantization is optional - nil means no quantization
  mr.quantize = opts.quantize
  
  mr.is_recording = false
  mr.recorded_events = {}
  mr.start_time = nil  -- Store recording start time
  
  -- Use a unique ID for each note to handle polyphony
  mr.active_notes = {}
  mr.next_note_id = 1
  
  return mr
end

-- Helper function to quantize a beat value if quantization is enabled
function MotifRecorder:_quantize_beat(beat)
  if not self.quantize then return beat end
  return math.floor(beat / self.quantize + 0.5) * self.quantize
end

--- onNoteOn: called when a MIDI/keyboard note-on is received
-- @param pitch (number)
-- @param velocity (number)
-- @param pos (table) grid position {x,y}
function MotifRecorder:onNoteOn(pitch, velocity, pos)
  if not self.is_recording then return end
  
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  local beat_time = self:_quantize_beat(time_from_start)
  
  local note_id = self.next_note_id
  self.next_note_id = self.next_note_id + 1
  
  local new_event = {
    id = note_id,
    pitch = pitch,
    velocity = velocity or 100,
    time = beat_time,
    duration = 0,
    pos = pos or {x=0, y=0}
  }
  self.active_notes[note_id] = new_event

  -- Store the note_id for this pitch (can be multiple)
  if not self.active_notes_by_pitch then self.active_notes_by_pitch = {} end
  if not self.active_notes_by_pitch[pitch] then self.active_notes_by_pitch[pitch] = {} end
  table.insert(self.active_notes_by_pitch[pitch], note_id)

  logger.music({
    event = "note_on",
    n = pitch,
    id = note_id,
    absolute_time = string.format("%.2f", now),
    relative_time = string.format("%.2f", time_from_start),
    quantized_time = string.format("%.2f", beat_time),
    velocity = velocity,
    pos = string.format("%d,%d", pos.x, pos.y)
  }, "▓▓")
end

--- onNoteOff: called when a MIDI/keyboard note-off is received
-- @param pitch (number)
function MotifRecorder:onNoteOff(pitch)
  if not self.is_recording then return end
  if not self.active_notes_by_pitch or not self.active_notes_by_pitch[pitch] then return end

  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  
  -- Get the oldest note of this pitch (FIFO)
  local note_id = table.remove(self.active_notes_by_pitch[pitch], 1)
  local evt = self.active_notes[note_id]
  
  if evt then
    -- Calculate final duration
    evt.duration = time_from_start - evt.time
    
    table.insert(self.recorded_events, evt)
    self.active_notes[note_id] = nil
    
    logger.music({
      event = "note_off",
      n = pitch,
      id = note_id,
      t = string.format("%.2f", evt.time),
      velocity = 0,
      pos = string.format("%d,%d", evt.pos.x, evt.pos.y),
      d = string.format("%.2f", evt.duration)
    }, "▓▓")
  end
end

--- Start a new recording
function MotifRecorder:startRecording()  
  self.is_recording = true
  self.recorded_events = {}
  self.active_notes = {}
  self.start_time = clock.get_beats()  -- Store the absolute start time
  
  logger.status({
    event = "Recording Started",
    quantize = self.quantize or "off"
  }, "▓▓")
end

--- Stop recording and return the event table
function MotifRecorder:stopRecording()
  if not self.is_recording then return end
  
  self.is_recording = false
  local end_time = clock.get_beats()
  local time_from_start = end_time - self.start_time
  
  for note_id, evt in pairs(self.active_notes) do
    evt.duration = time_from_start - evt.time
    table.insert(self.recorded_events, evt)
    self.active_notes[note_id] = nil
  end
  
  logger.status({
    event = "Recording Stopped",
    notes = #self.recorded_events,
    dur = string.format("%.2f", time_from_start)
  }, "▓▓")
  
  local notes = self.recorded_events
  self.recorded_events = {}
  return notes  -- Simply return the recorded notes
end

return MotifRecorder
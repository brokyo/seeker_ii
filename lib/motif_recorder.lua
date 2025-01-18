-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note events
-- Grid interaction flow:
--   1. Grid press -> GridUI.handle_note_record -> onNoteOn
--   2. Grid release -> GridUI.handle_note_record -> onNoteOff
--   3. Recording stops -> stopRecording -> returns note table to Motif

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

-- Debug flag for development
local DEBUG = false

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
  
  -- Polyphony management:
  -- active_notes: Tracks currently held notes by their unique ID
  -- active_notes_by_pitch: Groups held notes by pitch for FIFO release
  mr.active_notes = {}
  mr.active_notes_by_pitch = {}
  mr.next_note_id = 1
  
  return mr
end

-- Helper function to quantize a beat value if quantization is enabled
-- Used to align note timings to a musical grid
function MotifRecorder:_quantize_beat(beat)
  if not self.quantize then return beat end
  return math.floor(beat / self.quantize + 0.5) * self.quantize
end

--- onNoteOn: called when a MIDI/keyboard note-on is received
-- Grid interaction: Called from GridUI.handle_note_record when z=1
-- @param pitch (number) MIDI note number
-- @param velocity (number) Note velocity (usually 100 from grid)
-- @param pos (table) Grid position {x,y} - important for UI feedback
function MotifRecorder:on_note_on(pitch, velocity, pos)
  if not self.is_recording then return end
  
  -- Calculate timing relative to recording start
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  local beat_time = self:_quantize_beat(time_from_start)
  
  -- Create unique note ID for polyphony tracking
  local note_id = self.next_note_id
  self.next_note_id = self.next_note_id + 1
  
  -- Create the note event with initial data
  -- Duration will be set when note is released
  local new_event = {
    id = note_id,
    pitch = pitch,
    velocity = velocity or 100,
    time = beat_time,
    duration = 0,
    pos = pos or {x=0, y=0}  -- Store grid position for UI feedback
  }
  self.active_notes[note_id] = new_event

  -- Track notes by pitch for FIFO note-off handling
  -- This allows holding multiple notes of same pitch
  if not self.active_notes_by_pitch then self.active_notes_by_pitch = {} end
  if not self.active_notes_by_pitch[pitch] then self.active_notes_by_pitch[pitch] = {} end
  table.insert(self.active_notes_by_pitch[pitch], note_id)

  if DEBUG then
    print(string.format("● REC NOTE ON | id=%d pitch=%d vel=%d pos=%d,%d time=%.2f", 
      note_id, pitch, velocity, pos.x, pos.y, time_from_start))
  end
end

--- onNoteOff: called when a MIDI/keyboard note-off is received
-- Grid interaction: Called from GridUI.handle_note_record when z=0
-- Uses FIFO (First In First Out) for handling multiple held notes of same pitch
-- @param pitch (number) MIDI note number
function MotifRecorder:on_note_off(pitch)
  if not self.is_recording then return end
  if not self.active_notes_by_pitch or not self.active_notes_by_pitch[pitch] then return end

  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  
  -- Get the oldest note of this pitch (FIFO)
  local note_id = table.remove(self.active_notes_by_pitch[pitch], 1)
  local evt = self.active_notes[note_id]
  
  if evt then
    -- Calculate final duration from note start to now
    evt.duration = time_from_start - evt.time
    
    -- Move from active to recorded events
    table.insert(self.recorded_events, evt)
    self.active_notes[note_id] = nil
  
    if DEBUG then
      print(string.format("● REC NOTE OFF | id=%d pitch=%d duration=%.2f", 
        note_id, pitch, evt.duration))
    end
  end
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording()  
  self.is_recording = true
  self.recorded_events = {}
  self.active_notes = {}
  self.start_time = clock.get_beats()  -- Store the absolute start time
  
end

--- Stop recording and return the event table
-- Grid interaction: Called from GridUI.handle_record_toggle
-- Finalizes any held notes and returns the complete note table to Motif
function MotifRecorder:stop_recording()
  if not self.is_recording then return end
  
  self.is_recording = false
  local end_time = clock.get_beats()
  local time_from_start = end_time - self.start_time
  
  -- Finalize any notes still being held
  for note_id, evt in pairs(self.active_notes) do
    evt.duration = time_from_start - evt.time
    table.insert(self.recorded_events, evt)
    self.active_notes[note_id] = nil
  end
  
  -- Return and clear recorded events
  local notes = self.recorded_events
  self.recorded_events = {}
  return notes  -- This table becomes Motif.notes
end

return MotifRecorder
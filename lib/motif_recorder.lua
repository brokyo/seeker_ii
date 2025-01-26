-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a sequence of timed note events
-- Grid interaction flow:
--   1. Grid press -> GridUI.handle_note_record -> onNoteOn
--   2. Grid release -> GridUI.handle_note_record -> onNoteOff
--   3. Recording stops -> stopRecording -> returns note table to Motif

local Log = include('lib/log')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.is_recording = false
  m.next_note_id = 1
  m.active_notes = {}
  m.recorded_events = {}
  m.position_to_note = {}
  return m
end

-- Helper function to get quantization value in beats
function MotifRecorder:_get_quantize_value()
  if not self.lane_num then return nil end
  
  -- Check if quantization is enabled
  local rec_mode = params:get("lane_" .. self.lane_num .. "_recording_mode")
  if rec_mode == 1 then return nil end -- "free" mode
  
  -- Get quantization value
  local quant_option = params:get("lane_" .. self.lane_num .. "_quantize_value")
  -- Values are relative to quarter note (1 beat)
  local quant_values = {4/64, 4/32, 4/16, 4/8, 4/4}  -- 1/16 = 0.25 beats
  return quant_values[quant_option]
end

-- Helper function to get recording mode as string
function MotifRecorder:_get_recording_mode_str()
  if not self.lane_num then return "unknown" end
  local rec_mode = params:get("lane_" .. self.lane_num .. "_recording_mode")
  return rec_mode == 1 and "free" or "quantized"
end

-- Helper function to get quantize value as string
function MotifRecorder:_get_quantize_str()
  if not self.lane_num then return "unknown" end
  local quant_option = params:get("lane_" .. self.lane_num .. "_quantize_value")
  local quant_strings = {"1/64", "1/32", "1/16", "1/8", "1/4"}
  return quant_strings[quant_option] or "unknown"
end

-- Helper function to quantize a beat value if quantization is enabled
function MotifRecorder:_quantize_beat(beat)
  local quant = self:_get_quantize_value()
  if not quant then return beat end
  return math.floor(beat / quant + 0.5) * quant
end

--- onNoteOn: called when a MIDI/keyboard note-on is received
-- Grid interaction: Called from GridUI.handle_note_record when z=1
function MotifRecorder:on_note_on(pitch, velocity, pos)
  if not self.is_recording then return end
  
  -- Calculate raw timing
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  
  -- Create unique note ID. Used for deduping multiple MIDI notes played simultaneously
  local note_id = self.next_note_id
  self.next_note_id = self.next_note_id + 1
  
  -- Store position mapping with adjusted coordinates
  if pos then
    -- Get keyboard offsets
    local offset_x = params:get("lane_" .. self.lane_num .. "_keyboard_x") or 0
    local offset_y = params:get("lane_" .. self.lane_num .. "_keyboard_y") or 0
    
    -- Apply offsets to position
    local adj_pos = {
      x = pos.x + offset_x,
      y = pos.y + offset_y
    }
    
    if not self.position_to_note[adj_pos.x] then 
      self.position_to_note[adj_pos.x] = {} 
    end
    self.position_to_note[adj_pos.x][adj_pos.y] = note_id
  end
  
  -- Create note event with raw timing
  local new_event = {
    id = note_id,
    pitch = pitch,
    velocity = velocity or 127,
    raw_start = time_from_start,
    pos = pos or {x=0, y=0},
    adj_pos = adj_pos  -- Store adjusted position for reference
  }
  self.active_notes[note_id] = new_event

  Log.log("MOTIF_REC", "NOTES", string.format("%s Note ON  | id=%d pitch=%d vel=%d pos=%d,%d time=%.3f", Log.ICONS.NOTE_ON, note_id, pitch, velocity, pos.x, pos.y, time_from_start))
end

--- onNoteOff: called when a MIDI/keyboard note-off is received
-- Grid interaction: Called from GridUI.handle_note_record when z=0
-- Uses FIFO (First In First Out) for handling multiple held notes of same pitch
-- @param pitch (number) MIDI note number
function MotifRecorder:on_note_off(pitch, pos)
  if not self.is_recording then return end
  
  -- Find note ID from adjusted position if provided
  local note_id
  if pos then
    -- Get keyboard offsets
    local offset_x = params:get("lane_" .. self.lane_num .. "_keyboard_x") or 0
    local offset_y = params:get("lane_" .. self.lane_num .. "_keyboard_y") or 0
    
    -- Apply offsets to position
    local adj_pos = {
      x = pos.x + offset_x,
      y = pos.y + offset_y
    }
    
    if self.position_to_note[adj_pos.x] then
      note_id = self.position_to_note[adj_pos.x][adj_pos.y]
      -- Clear position mapping
      self.position_to_note[adj_pos.x][adj_pos.y] = nil
    end
  end
  
  local now = clock.get_beats()
  local time_from_start = now - self.start_time
  local evt = self.active_notes[note_id]
  
  -- Calculate duration using raw times
  evt.duration = time_from_start - evt.raw_start
  
  -- Apply quantization to start time only
  evt.time = self:_quantize_beat(evt.raw_start)
  evt.raw_start = nil  -- Clean up temp data
  
  -- Move to recorded events
  table.insert(self.recorded_events, evt)
  self.active_notes[note_id] = nil

  Log.log("MOTIF_REC", "NOTES", string.format("%s Note OFF | id=%d pitch=%d duration=%.3f", Log.ICONS.NOTE_OFF, note_id, pitch, evt.duration))
end

--- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording(lane_num)  
  self.is_recording = true
  self.recorded_events = {}
  self.active_notes = {}
  self.position_to_note = {}  -- Reset position tracking
  self.start_time = clock.get_beats()
  self.lane_num = lane_num
  
  Log.log("MOTIF_REC", "STATUS", string.format("%s Recording Started | Lane %d | Mode: %s | Grid: %s", Log.ICONS.RECORD_ON, lane_num, self:_get_recording_mode_str(), self:_get_quantize_str()))
end

--- Stop recording and return the event table
-- Grid interaction: Called from GridUI.handle_record_toggle
-- Finalizes any held notes and returns the complete note table to Motif
function MotifRecorder:stop_recording()
  if not self.is_recording then return end
  
  self.is_recording = false
  local end_time = clock.get_beats()
  local recorded_duration = end_time - self.start_time
  
  -- Finalize any held notes
  for note_id, evt in pairs(self.active_notes) do
    -- Calculate duration using raw time
    evt.duration = recorded_duration - evt.raw_start
    -- Apply quantization to start time
    evt.time = self:_quantize_beat(evt.raw_start)
    evt.raw_start = nil
    table.insert(self.recorded_events, evt)
  end
  
  -- Clear state
  self.active_notes = {}
  self.position_to_note = {}
  
  -- Sort notes by start time
  table.sort(self.recorded_events, function(a, b)
    return a.time < b.time
  end)
  
  -- Log recording completion
  Log.log("MOTIF_REC", "STATUS", string.format("%s Recording Stopped | Lane %d | Events: %d | Duration: %.3f", Log.ICONS.RECORD_OFF, self.lane_num, #self.recorded_events, recorded_duration))
  
  if #self.recorded_events > 0 then
    Log.log("MOTIF_REC", "STATUS", Log.format.motif_table(self.recorded_events))
  end
  
  local recorded_data = {
    notes = self.recorded_events,
    recorded_duration = recorded_duration
  }
  self.recorded_events = {}
  return recorded_data
end

return MotifRecorder
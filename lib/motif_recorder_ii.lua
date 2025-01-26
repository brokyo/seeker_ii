-- motif_recorder_ii.lua
-- Records grid/MIDI input into a sequence of note events
-- Maintains the excellent quantization system from the original

local Log = include('lib/log')

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.is_recording = false
  m.events = {}          -- Recorded events in chronological order
  m.active_notes = {}    -- Currently held notes by position
  return m
end

-- Get quantization value in beats
function MotifRecorder:_get_quantize_value()
  if not self.lane_num then return nil end
  
  -- Check if quantization is enabled
  local rec_mode = params:get("lane_" .. self.lane_num .. "_recording_mode")
  if rec_mode == 1 then return nil end -- "free" mode
  
  -- Get quantization value
  local quant_option = params:get("lane_" .. self.lane_num .. "_quantize_value")
  local quant_values = {4/64, 4/32, 4/16, 4/8, 4/4}  -- Relative to quarter note
  return quant_values[quant_option]
end

-- Quantize a beat value if quantization is enabled
function MotifRecorder:_quantize_beat(beat)
  local quant = self:_get_quantize_value()
  if not quant then return beat end
  return math.floor(beat / quant + 0.5) * quant
end

-- Handle note on from grid or MIDI
function MotifRecorder:on_note_on(note, velocity, pos)
  if not self.is_recording then return end
  
  -- Calculate timing
  local now = clock.get_beats()
  local raw_time = now - self.start_time
  local time = self:_quantize_beat(raw_time)
  
  -- Create note_on event
  local evt = {
    time = time,
    type = "note_on",
    note = note,
    velocity = velocity or 127,
    pos = pos and {x = pos.x, y = pos.y} or nil
  }
  
  -- Store event
  table.insert(self.events, evt)
  
  -- Track active note for this position
  if pos then
    -- Get keyboard offsets
    local offset_x = params:get("lane_" .. self.lane_num .. "_keyboard_x") or 0
    local offset_y = params:get("lane_" .. self.lane_num .. "_keyboard_y") or 0
    
    -- Store with adjusted position
    local key = string.format("%d,%d", pos.x + offset_x, pos.y + offset_y)
    self.active_notes[key] = {
      note = note,
      time = time,
      pos = pos
    }
  end
  
  Log.log("MOTIF_REC", "NOTES", string.format("%s Note ON  | note=%d vel=%d time=%.3f", Log.ICONS.NOTE_ON, note, velocity, time))
end

-- Handle note off from grid or MIDI
function MotifRecorder:on_note_off(note, pos)
  if not self.is_recording then return end
  
  -- Calculate timing
  local now = clock.get_beats()
  local raw_time = now - self.start_time
  local time = self:_quantize_beat(raw_time)
  
  -- Find matching note_on event
  local active_note
  if pos then
    -- Get keyboard offsets
    local offset_x = params:get("lane_" .. self.lane_num .. "_keyboard_x") or 0
    local offset_y = params:get("lane_" .. self.lane_num .. "_keyboard_y") or 0
    
    -- Look up by adjusted position
    local key = string.format("%d,%d", pos.x + offset_x, pos.y + offset_y)
    active_note = self.active_notes[key]
    self.active_notes[key] = nil
  end
  
  -- Create note_off event
  local evt = {
    time = time,
    type = "note_off",
    note = note,
    pos = pos and {x = pos.x, y = pos.y} or nil
  }
  
  -- Store event
  table.insert(self.events, evt)
  
  Log.log("MOTIF_REC", "NOTES", string.format("%s Note OFF | note=%d time=%.3f", Log.ICONS.NOTE_OFF, note, time))
end

-- Start recording
function MotifRecorder:start_recording(lane_num)
  self.is_recording = true
  self.events = {}
  self.active_notes = {}
  self.start_time = clock.get_beats()
  self.lane_num = lane_num
  
  Log.log("MOTIF_REC", "STATUS", string.format("%s Recording Started | Lane %d", Log.ICONS.RECORD_ON, lane_num))
end

-- Stop recording and return events
function MotifRecorder:stop_recording()
  if not self.is_recording then return end
  
  self.is_recording = false
  local end_time = clock.get_beats()
  local total_duration = end_time - self.start_time
  
  -- Add note_off events for any held notes
  for _, note in pairs(self.active_notes) do
    table.insert(self.events, {
      time = total_duration,
      type = "note_off",
      note = note.note,
      pos = note.pos
    })
  end
  
  -- Sort all events by time
  table.sort(self.events, function(a, b) return a.time < b.time end)
  
  Log.log("MOTIF_REC", "STATUS", string.format("%s Recording Stopped | Lane %d | Events: %d | Duration: %.3f", 
    Log.ICONS.RECORD_OFF, self.lane_num, #self.events, total_duration))
  
  -- Return recorded data
  local result = {
    events = self.events,
    duration = total_duration
  }
  
  -- Clear state
  self.events = {}
  self.active_notes = {}
  
  return result
end

return MotifRecorder 
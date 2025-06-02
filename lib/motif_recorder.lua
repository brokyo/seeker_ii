-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a table of note on/off events. Supports multiple recording modes:
-- 1. Tape: Record a new motif from scratch (duration is determined by time between stop and start)
-- 2. Overdub: Overdub onto an existing motif (duration is determined by the original motif)
-- 3. Arpeggio: Record a sequence of notes with consistent intervals (duration is determined by the number of notes and rests)

local MotifRecorder = {}
MotifRecorder.__index = MotifRecorder

function MotifRecorder.new()
  local m = setmetatable({}, MotifRecorder)
  m.recording_mode = 1
  m:reset_state()
  return m
end

-- Reset internal state to default values
function MotifRecorder:reset_state()
  self.is_recording = false
  self.events = {}
  self.start_time = 0
  self.loop_length = nil
  self.waiting_for_first_note = false
  self.original_motif = nil
  self.current_generation = 1
  
  -- Additional state for arpeggio mode
  self.arpeggio_interval = 1
  self.arpeggio_rest_count = 0
  
  -- Track active notes for overdub mode to handle loop wraparound
  self.active_notes = {}
end

-- Helper function to create a note key for tracking active notes
function MotifRecorder:_note_key(event)
  return string.format("%d,%d,%d", event.note, event.x, event.y)
end

-- on_note_on: called when a grid button is pressed (z=1)
function MotifRecorder:on_note_on(event)
  if not self.is_recording then return end

  -- Calculate timing
  local now = clock.get_beats()
  local position = 0
  

  -- Calculate note_on timing (position) based on the recording mode
  -- Mode 1: Tape recording (new motif)
  if self.recording_mode == 1 then
    if self.waiting_for_first_note then
      self.start_time = clock.get_beats() - 0.02  -- Small offset for better scheduling. Things can break otherwise.
      self.waiting_for_first_note = false
    end
    
    position = now - self.start_time
  -- Mode 2: Overdub recording
  elseif self.recording_mode == 2 then
    if self.waiting_for_first_note then
      self.start_time = clock.get_beats() - 0.02
      self.waiting_for_first_note = false
    end
    
    -- Calculate overdub position with current playback position
    if self.loop_length then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]
      
      if lane.playing then
        -- Get timing from the currently playing stage
        local current_stage = lane.stages[lane.current_stage_index]
        if current_stage.last_start_time then
          -- Calculate position based on lane's stage start time, sync with visualization
          local elapsed_time = now - current_stage.last_start_time
          position = (elapsed_time * lane.speed) % self.loop_length
        else
          -- Fallback if stage start time not available
          position = now % self.loop_length
        end
      else
        -- N.B. I don't think we ever get here.
        -- Not playing, use modulo loop length
        position = now % self.loop_length
      end
    else
      -- For new recording, measure from start
      position = now - self.start_time
    end
    
    -- Track this note as active for overdub mode
    local note_key = self:_note_key(event)
    self.active_notes[note_key] = position
  -- Mode 3: Arpeggio recording
  elseif self.recording_mode == 3 then
    -- Get interval from params
    local interval_str = params:string("arpeggio_interval")
    local interval = self:_interval_to_beats(interval_str)
    
    -- Calculate position based on number of notes played plus rests
    local note_count = 0
    for _, evt in ipairs(self.events) do
      if evt.type == "note_on" then
        note_count = note_count + 1
      end
    end
    position = (note_count + self.arpeggio_rest_count) * interval
  end
      
  -- Store note_on event
  -- N.B. ADSR/Pan are on a per-note basis
  local focused_lane = _seeker.ui_state.get_focused_lane()
  table.insert(self.events, {
    time = position,
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
  
  -- For arpeggio mode, immediately schedule the note_off based on duration parameter
  if self.recording_mode == 3 then
    local interval_str = params:string("arpeggio_interval")
    local interval = self:_interval_to_beats(interval_str)
    local note_duration_percentage = params:get("arpeggio_note_duration") / 100
    local note_duration = interval * note_duration_percentage
    
    -- Calculate note_off time
    local note_off_time = position + note_duration
    
    -- Store note_off event immediately
    table.insert(self.events, {
      time = note_off_time,
      type = "note_off",
      note = event.note,
      x = event.x,
      y = event.y,
      generation = self.current_generation
    })
  end
end

-- on_note_off: called when a grid button is released (z=0)
function MotifRecorder:on_note_off(event)
  if not self.is_recording then return end

  -- Skip note_off processing for arpeggio mode since we handle it in note_on
  if self.recording_mode == 3 then
    return
  end

  -- Calculate timing
  local now = clock.get_beats()
  local position
  
  -- Calculate note_off timing (position) based on the recording mode
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
    
    -- Handle loop wraparound for overdub mode
    if self.recording_mode == 2 then
      local note_key = self:_note_key(event)
      local note_on_position = self.active_notes[note_key]
      
      if note_on_position then
        -- If note_off position is less than note_on position, the note crossed the loop boundary
        -- Add loop_length to note_off to maintain proper temporal ordering
        if position < note_on_position then
          position = position + self.loop_length
        end
        
        -- Clear from active notes
        self.active_notes[note_key] = nil
      end
    end
  else
    -- For new recording, measure from start
    position = now - self.start_time
  end
      
  -- Store note_off event
  table.insert(self.events, {
    time = position,
    type = "note_off",
    note = event.note,
    x = event.x,
    y = event.y,
    generation = self.current_generation
  })
end

-- Set the recording mode
-- @param mode: 1 for Tape, 2 for Overdub, 3 for Arpeggio
function MotifRecorder:set_recording_mode(mode)
  self.recording_mode = mode
end

-- Start a new recording
-- Grid interaction: Called from GridUI.handle_record_toggle
function MotifRecorder:start_recording(existing_motif)
  -- Reset state
  self:reset_state()
  
  -- If overdubbing, store original duration and events
  if self.recording_mode == 2 and existing_motif then
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
  elseif self.recording_mode == 3 then
    self.current_generation = 1
  else
    -- New tape recording. Only set this for tape recordings
    self.waiting_for_first_note = true
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
  
  -- Calculate duration differently for arpeggio mode
  local duration
  if self.recording_mode == 3 then -- Arpeggio mode
    -- Count the number of notes played
    local note_count = 0
    for _, event in ipairs(self.events) do
      if event.type == "note_on" then
        note_count = note_count + 1
      end
    end
    
    -- Calculate duration to maintain consistent interval spacing on loop
    local interval_str = params:string("arpeggio_interval")
    local interval = self:_interval_to_beats(interval_str)
    duration = (note_count + self.arpeggio_rest_count) * interval
  else
    -- Use existing logic for tape/overdub modes
    duration = self.loop_length or (clock.get_beats() - self.start_time)
  end
  
  -- Create recorded data package
  local recorded_data = {
    events = self.events,
    duration = duration
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

--- Skip a position in the arpeggio sequence, creating a timing gap
function MotifRecorder:add_arpeggio_rest()
  if not self.is_recording or self.recording_mode ~= 3 then return end
  
  -- Simply increment the rest counter - this will create a gap in the sequence
  self.arpeggio_rest_count = self.arpeggio_rest_count + 1
end

--- Start arpeggio recording
function MotifRecorder:start_arpeggio_recording()
  self:set_recording_mode(3)
  self:start_recording(nil)
end

--- Stop arpeggio recording and return the event table
function MotifRecorder:stop_arpeggio_recording()
  return self:stop_recording()
end

return MotifRecorder
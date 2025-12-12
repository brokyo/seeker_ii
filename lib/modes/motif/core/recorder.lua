-- motif_recorder.lua
-- Real-time event capture for Tape and Sampler modes.
-- Captures grid/MIDI input as note_on/note_off events with timing.
--
-- Used by: Tape (keyboard notes), Sampler (pad triggers)
-- NOT used by: Composer (uses generator.lua for algorithmic motif creation)
--
-- Recording modes:
-- 1. New recording: Duration determined by start/stop timing
-- 2. Overdub: Layer onto existing motif, duration preserved

local musicutil = require('musicutil')

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

  -- Track active notes to handle held notes on recording stop and overdub wraparound
  -- Keys are note_key strings, values are {position, event_data} tables
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

  end

  -- Track active note in both modes (for held-note cleanup and overdub wraparound)
  local note_key = self:_note_key(event)
  self.active_notes[note_key] = {
    position = position,
    note = event.note,
    x = event.x,
    y = event.y
  }

  -- Store note_on event
  -- Tape mode: ADSR/Pan from params; Sampler mode: chop values from event
  local focused_lane = _seeker.ui_state.get_focused_lane()
  table.insert(self.events, {
    time = position,
    type = "note_on",
    note = event.note,
    velocity = event.velocity,
    x = event.x,
    y = event.y,
    generation = self.current_generation,
    -- Tape mode values (from params)
    attack = event.attack or params:get("lane_" .. focused_lane .. "_attack"),
    decay = event.decay or params:get("lane_" .. focused_lane .. "_decay"),
    sustain = event.sustain or params:get("lane_" .. focused_lane .. "_sustain"),
    release = event.release or params:get("lane_" .. focused_lane .. "_release"),
    pan = event.pan or params:get("lane_" .. focused_lane .. "_pan"),
    -- Sampler mode values (from event, nil for tape)
    fade_time = event.fade_time,
    rate = event.rate,
    pitch_offset = event.pitch_offset,
    max_volume = event.max_volume,
    mode = event.mode,
    filter_type = event.filter_type,
    lpf = event.lpf,
    hpf = event.hpf,
    resonance = event.resonance,
    start_pos = event.start_pos,
    stop_pos = event.stop_pos
  })
end

-- on_note_off: called when a grid button is released (z=0)
function MotifRecorder:on_note_off(event)
  if not self.is_recording then return end

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
      local active_note = self.active_notes[note_key]

      if active_note then
        -- If note_off position is less than note_on position, the note crossed the loop boundary
        -- Add loop_length to note_off to maintain proper temporal ordering
        if position < active_note.position then
          position = position + self.loop_length
        end
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

  -- Clear from active notes
  local note_key = self:_note_key(event)
  self.active_notes[note_key] = nil
end

-- Set the recording mode
-- @param mode: 1 for Tape, 2 for Overdub
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
    print('⊕ Overdub started')
    -- Use get_duration() to respect custom_duration if set
    self.loop_length = existing_motif:get_duration()
    self.original_motif = existing_motif -- Store reference to original

    -- Copy genesis events and preserve their generations
    local max_gen = 1
    for _, evt in ipairs(existing_motif.genesis.events) do
      -- Add events to recorder (include both tape and sampler fields)
      table.insert(self.events, {
        time = evt.time,
        type = evt.type,
        note = evt.note,
        velocity = evt.velocity,
        x = evt.x,
        y = evt.y,
        generation = evt.generation,
        -- Tape mode fields
        attack = evt.attack,
        decay = evt.decay,
        sustain = evt.sustain,
        release = evt.release,
        pan = evt.pan,
        -- Sampler mode fields
        fade_time = evt.fade_time,
        rate = evt.rate,
        pitch_offset = evt.pitch_offset,
        max_volume = evt.max_volume,
        mode = evt.mode,
        filter_type = evt.filter_type,
        lpf = evt.lpf,
        hpf = evt.hpf,
        resonance = evt.resonance,
        start_pos = evt.start_pos,
        stop_pos = evt.stop_pos
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

  -- Inject note_off events for any notes still held
  local now = clock.get_beats()
  for note_key, active_note in pairs(self.active_notes) do
    local position
    if self.recording_mode == 1 then
      -- Tape mode: note_off at current time relative to start
      position = now - self.start_time
    else
      -- Overdub mode: note_off at loop boundary (clamp to duration)
      position = self.loop_length
    end

    table.insert(self.events, {
      time = position,
      type = "note_off",
      note = active_note.note,
      x = active_note.x,
      y = active_note.y,
      generation = self.current_generation
    })
  end
  self.active_notes = {}

  self.is_recording = false

  local recorded_data
  if self.recording_mode == 1 then -- Tape mode
    recorded_data = self:_stop_tape_recording()
  elseif self.recording_mode == 2 then -- Overdub mode
    recorded_data = self:_stop_overdub_recording()
  else
    error("Invalid recording mode: " .. self.recording_mode)
  end

  -- Clear recorder state
  self.events = {}
  self.loop_length = nil
  print("⊞ Recording stopped")
  return recorded_data
end

-- Private method for tape recording
function MotifRecorder:_stop_tape_recording()
  table.sort(self.events, function(a, b) return a.time < b.time end)
  local duration = clock.get_beats() - self.start_time
  return {events = self.events, duration = duration}
end

-- Private method for overdub recording
function MotifRecorder:_stop_overdub_recording()
  table.sort(self.events, function(a, b) return a.time < b.time end)
  local duration = self.loop_length
  return {events = self.events, duration = duration}
end


return MotifRecorder
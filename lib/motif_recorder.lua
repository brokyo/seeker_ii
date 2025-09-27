-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a table of note on/off events. Supports multiple recording modes:
-- 1. Tape: Record a new motif from scratch (duration is determined by time between stop and start)
-- 2. Overdub: Overdub onto an existing motif (duration is determined by the original motif)
-- 3. Arpeggio: Record a sequence of notes with consistent intervals (duration is determined by the number of notes and rests)

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
-- @param mode: 1 for Tape, 2 for Overdub, 3 for Arpeggio, 4 for Trigger
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

  local recorded_data
  if self.recording_mode == 1 then -- Tape mode
    recorded_data = self:_stop_tape_recording()
  elseif self.recording_mode == 2 then -- Overdub mode
    recorded_data = self:_stop_overdub_recording()
  elseif self.recording_mode == 3 then -- Arpeggio mode
    recorded_data = self:_stop_arpeggio_recording()
  elseif self.recording_mode == 4 then -- Trigger mode
    recorded_data = self:_stop_trigger_recording()
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

-- Private method for arpeggio recording
function MotifRecorder:_stop_arpeggio_recording()
  table.sort(self.events, function(a, b) return a.time < b.time end)

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
  local duration = (note_count + self.arpeggio_rest_count) * interval

  return {events = self.events, duration = duration}
end

-- Private method for trigger recording
function MotifRecorder:_stop_trigger_recording()
  -- Store metadata for regeneration instead of fixed MIDI events
  local focused_lane = _seeker.ui_state.get_focused_lane()

  -- Create a single metadata event that will be used for regeneration
  self.events = {
    {
      time = 0,
      type = "trigger_pattern",
      lane_id = focused_lane,
      generation = self.current_generation,
      -- Parameters will be read fresh during regeneration
      attack = params:get("lane_" .. focused_lane .. "_attack"),
      decay = params:get("lane_" .. focused_lane .. "_decay"),
      sustain = params:get("lane_" .. focused_lane .. "_sustain"),
      release = params:get("lane_" .. focused_lane .. "_release"),
      pan = params:get("lane_" .. focused_lane .. "_pan")
    }
  }

  -- Duration will be calculated during regeneration, not here
  -- This ensures it updates when step parameters change
  local duration = 1.0  -- Placeholder duration

  return {events = self.events, duration = duration}
end

--- Generate chord notes with octave cycling (based on seeker/core.lua)
function MotifRecorder:_generate_chord(chord_root, chord_type, chord_length, chord_inversion)
  -- Convert UI chord root (1-12) to MIDI note (0-11)
  local chord_root_midi = (chord_root - 1) % 12

  -- Get base chord intervals from musicutil with inversion
  local base_chord = musicutil.generate_chord(chord_root_midi, chord_type, chord_inversion or 0, 3)

  -- Convert to intervals relative to root
  local chord_intervals = {}
  for _, note in ipairs(base_chord) do
    table.insert(chord_intervals, note - chord_root_midi)
  end

  -- Generate extended chord using seeker-style cycling
  local chord_notes = {}
  local note_index = 1
  local octave_offset = 0

  for i = 1, chord_length do
    local interval = chord_intervals[note_index]
    local note = chord_root_midi + interval + (octave_offset * 12)
    table.insert(chord_notes, note)

    note_index = note_index + 1
    if note_index > #chord_intervals then
      note_index = 1
      octave_offset = octave_offset + 1
    end
  end

  return chord_notes
end

--- Apply direction logic to chord sequence
function MotifRecorder:_apply_direction(chord_notes, direction, num_active_steps)
  local result = {}

  if direction == 1 then -- Up (default)
    return chord_notes
  elseif direction == 2 then -- Down
    -- Reverse the chord notes
    for i = #chord_notes, 1, -1 do
      table.insert(result, chord_notes[i])
    end
    return result
  elseif direction == 3 then -- Up-Down
    -- Go up then down
    for i = 1, #chord_notes do
      table.insert(result, chord_notes[i])
    end
    for i = #chord_notes - 1, 2, -1 do
      table.insert(result, chord_notes[i])
    end
    return result
  elseif direction == 4 then -- Down-Up
    -- Go down then up
    for i = #chord_notes, 1, -1 do
      table.insert(result, chord_notes[i])
    end
    for i = 2, #chord_notes - 1 do
      table.insert(result, chord_notes[i])
    end
    return result
  elseif direction == 5 then -- Random
    -- Shuffle the chord notes
    for i = 1, #chord_notes do
      table.insert(result, chord_notes[i])
    end
    for i = #result, 2, -1 do
      local j = math.random(i)
      result[i], result[j] = result[j], result[i]
    end
    return result
  end

  return chord_notes  -- Fallback to up
end

--- Regenerate trigger motif from current grid state and chord parameters
function MotifRecorder:regenerate_trigger_motif_from_current_state(lane_id, original_envelope_settings)
  -- Get current trigger parameters
  local step_length_str = params:string("lane_" .. lane_id .. "_trigger_step_length")
  local step_length = self:_interval_to_beats(step_length_str)
  local num_steps = params:get("lane_" .. lane_id .. "_trigger_num_steps")
  local chord_root = params:get("lane_" .. lane_id .. "_trigger_chord_root")
  local chord_type = params:string("lane_" .. lane_id .. "_trigger_chord_type")
  local chord_length = params:get("lane_" .. lane_id .. "_trigger_chord_length")
  local chord_inversion = params:get("lane_" .. lane_id .. "_trigger_chord_inversion") - 1  -- Convert to 0-based
  local chord_direction = params:get("lane_" .. lane_id .. "_trigger_chord_direction")
  local note_duration_percent = params:get("lane_" .. lane_id .. "_trigger_note_duration")
  local octave = params:get("lane_" .. lane_id .. "_keyboard_octave")

  -- Generate chord notes with specified length and inversion
  local effective_chord = self:_generate_chord(chord_root, chord_type, chord_length, chord_inversion)

  -- Store original chord for logging before direction is applied
  local original_chord = {}
  for i, note in ipairs(effective_chord) do
    table.insert(original_chord, note)
  end

  -- Ensure chord generation succeeded
  if not effective_chord or #effective_chord == 0 then
    print("ERROR: Failed to generate effective chord")
    return {}
  end

  -- Get active trigger keyboard using global reference
  local TriggerKeyboard = _seeker.keyboard_region.get_active_keyboard()

  -- First pass: collect active steps
  local active_steps = {}
  for step = 1, num_steps do
    if TriggerKeyboard.is_step_active(lane_id, step) then
      table.insert(active_steps, step)
    end
  end

  -- Apply direction logic to the chord based on number of active steps
  effective_chord = self:_apply_direction(effective_chord, chord_direction, #active_steps)

  -- Log the chord with direction info
  local original_str = table.concat(original_chord, ", ")
  local play_order_str = table.concat(effective_chord, ", ")
  local direction_names = {"Up", "Down", "Up-Down", "Down-Up", "Random"}
  print(string.format("🎼 Chord: [%s] → %s: [%s]", original_str, direction_names[chord_direction] or "Up", play_order_str))

  -- Generate events from active step sequence
  local events = {}
  for active_index, step in ipairs(active_steps) do
    local step_time = (step - 1) * step_length

    -- Map active sequence position to chord note with actual chord size wrapping
    local chord_position = ((active_index - 1) % #effective_chord) + 1
    local chord_note = effective_chord[chord_position]

    local final_note = chord_note + ((octave + 1) * 12)

    -- Get velocity for this step based on its state
    local step_velocity = TriggerKeyboard.get_step_velocity(lane_id, step)

    -- Get grid coordinates for this step
    local step_pos = TriggerKeyboard.step_to_grid(step)
    local step_x = step_pos and step_pos.x or 0
    local step_y = step_pos and step_pos.y or 0

    -- Add note_on event
    table.insert(events, {
      time = step_time,
      type = "note_on",
      note = final_note,
      velocity = step_velocity,
      x = step_x,
      y = step_y,
      generation = self.current_generation,
      attack = original_envelope_settings.attack,
      decay = original_envelope_settings.decay,
      sustain = original_envelope_settings.sustain,
      release = original_envelope_settings.release,
      pan = original_envelope_settings.pan
    })

    -- Add note_off event using duration parameter
    local note_duration = step_length * (note_duration_percent / 100)
    local note_off_time = step_time + note_duration
    table.insert(events, {
      time = note_off_time,
      type = "note_off",
      note = final_note,
      x = step_x,
      y = step_y,
      generation = self.current_generation
    })

  end

  -- Calculate duration based on current parameters
  local duration = num_steps * step_length

  return events, duration
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
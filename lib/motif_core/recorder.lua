-- motif_recorder.lua
-- Core responsibility: Convert grid/MIDI input into a table of note on/off events. Supports multiple recording modes:
-- 1. Tape: Record a new motif from scratch (duration is determined by time between stop and start)
-- 2. Overdub: Overdub onto an existing motif (duration is determined by the original motif)
-- 3. Arpeggio: Generate a motif from arpeggio sequencer pattern data (immediate, no real-time recording)

local musicutil = require('musicutil')
local arpeggio_gen = include('lib/motif_core/arpeggio_generator')

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
    self.loop_length = existing_motif.genesis.duration
    self.original_motif = existing_motif -- Store reference to original

    -- Copy genesis events and preserve their generations
    local max_gen = 1
    for _, evt in ipairs(existing_motif.genesis.events) do
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

-- Private method for arpeggio recording
function MotifRecorder:_stop_arpeggio_recording()
  -- Generate full note events immediately from current arpeggio state
  local focused_lane = _seeker.ui_state.get_focused_lane()

  print("🎹 Generating arpeggio motif from step pattern...")

  -- Get current arpeggio parameters
  local step_length_str = params:string("lane_" .. focused_lane .. "_arpeggio_step_length")
  local step_length = self:_interval_to_beats(step_length_str)
  local num_steps = params:get("lane_" .. focused_lane .. "_arpeggio_num_steps")
  local chord_root = params:get("lane_" .. focused_lane .. "_arpeggio_chord_root")
  local chord_type = params:string("lane_" .. focused_lane .. "_arpeggio_chord_type")
  local chord_length = params:get("lane_" .. focused_lane .. "_arpeggio_chord_length")
  local chord_inversion = params:get("lane_" .. focused_lane .. "_arpeggio_chord_inversion") - 1
  local chord_direction = params:get("lane_" .. focused_lane .. "_arpeggio_chord_direction")
  local note_duration_percent = params:get("lane_" .. focused_lane .. "_arpeggio_note_duration")
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")

  -- Get velocity curve parameters
  local velocity_curve = params:string("lane_" .. focused_lane .. "_arpeggio_velocity_curve")
  local velocity_min = params:get("lane_" .. focused_lane .. "_arpeggio_velocity_min")
  local velocity_max = params:get("lane_" .. focused_lane .. "_arpeggio_velocity_max")

  -- Get strum parameters
  local strum_curve = params:string("lane_" .. focused_lane .. "_arpeggio_strum_curve")
  local strum_amount = params:get("lane_" .. focused_lane .. "_arpeggio_strum_amount")
  local strum_direction = params:string("lane_" .. focused_lane .. "_arpeggio_strum_direction")

  print(string.format("  Chord: %s, Length: %d, Inversion: %d", chord_type, chord_length, chord_inversion))

  -- Generate chord notes
  local effective_chord = self:_generate_chord(chord_root, chord_type, chord_length, chord_inversion)

  if not effective_chord or #effective_chord == 0 then
    print("ERROR: Failed to generate chord for arpeggio recording")
    return {events = {}, duration = num_steps * step_length}
  end

  -- Get arpeggio keyboard to read step states
  local ArpeggioKeyboard = _seeker.keyboards[2]

  -- Collect active steps
  local active_steps = {}
  for step = 1, num_steps do
    if ArpeggioKeyboard.is_step_active(focused_lane, step) then
      table.insert(active_steps, step)
    end
  end

  print(string.format("  Found %d active steps out of %d total", #active_steps, num_steps))

  -- Apply direction to chord
  effective_chord = self:_apply_direction(effective_chord, chord_direction, #active_steps)

  -- Calculate sequence duration for strum calculation
  local sequence_duration = num_steps * step_length

  -- Generate note events for each active step
  local events = {}
  for active_index, step in ipairs(active_steps) do
    -- Calculate absolute time position using strum window
    local step_time = arpeggio_gen.calculate_strum_position(active_index, #active_steps, strum_curve, strum_amount, strum_direction, sequence_duration)

    -- Map to chord note
    local chord_position = ((active_index - 1) % #effective_chord) + 1
    local chord_note = effective_chord[chord_position]
    local final_note = chord_note + ((octave + 1) * 12)

    -- Calculate velocity using curve
    local step_velocity = arpeggio_gen.calculate_velocity(active_index, #active_steps, velocity_curve, velocity_min, velocity_max)

    -- Get grid coordinates
    local step_pos = ArpeggioKeyboard.step_to_grid(step)
    local step_x = step_pos and step_pos.x or 0
    local step_y = step_pos and step_pos.y or 0

    -- Add note_on event with step info for transform filtering
    table.insert(events, {
      time = step_time,
      type = "note_on",
      note = final_note,
      velocity = step_velocity,
      x = step_x,
      y = step_y,
      step = step,  -- Store step number for pattern preset filtering
      generation = self.current_generation,
      attack = params:get("lane_" .. focused_lane .. "_attack"),
      decay = params:get("lane_" .. focused_lane .. "_decay"),
      sustain = params:get("lane_" .. focused_lane .. "_sustain"),
      release = params:get("lane_" .. focused_lane .. "_release"),
      pan = params:get("lane_" .. focused_lane .. "_pan")
    })

    -- Add note_off event
    local note_duration = step_length * (note_duration_percent / 100)
    local note_off_time = step_time + note_duration
    table.insert(events, {
      time = note_off_time,
      type = "note_off",
      note = final_note,
      x = step_x,
      y = step_y,
      step = step,  -- Store step number for pattern preset filtering
      generation = self.current_generation
    })
  end

  -- Sort by time
  table.sort(events, function(a, b) return a.time < b.time end)

  -- Calculate duration
  local duration = num_steps * step_length

  return {events = events, duration = duration}
end

--- Generate chord notes with octave cycling (based on seeker/core.lua)
function MotifRecorder:_generate_chord(chord_root_degree, chord_type, chord_length, chord_inversion)
  -- Get global scale settings
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  -- Convert scale degree (1-7) to semitone offset from root
  local degree_index = ((chord_root_degree - 1) % #scale.intervals) + 1
  local semitone_offset = scale.intervals[degree_index]

  -- Calculate actual MIDI note for chord root
  local chord_root_midi = ((root_note - 1) + semitone_offset) % 12

  -- Map "Diatonic" to the appropriate chord quality based on scale degree
  if chord_type == "Diatonic" then
    -- Standard diatonic chord qualities (works for major and most modal scales)
    local diatonic_qualities = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
    local quality_index = ((chord_root_degree - 1) % 7) + 1
    chord_type = diatonic_qualities[quality_index]
  end

  -- Normalize chord type names to lowercase for musicutil compatibility
  local chord_type_map = {
    ["Major"] = "major",
    ["Minor"] = "minor",
    ["Sus2"] = "sus2",
    ["Sus4"] = "sus4",
    ["Maj7"] = "major 7",
    ["Min7"] = "minor 7",
    ["Dom7"] = "dom 7",
    ["Dim"] = "diminished",
    ["Aug"] = "augmented"
  }
  chord_type = chord_type_map[chord_type] or chord_type

  -- Get base chord intervals from musicutil with inversion
  local base_chord = musicutil.generate_chord(chord_root_midi, chord_type, chord_inversion or 0, 3)

  -- Error handling if chord type not recognized
  if not base_chord or #base_chord == 0 then
    print("ERROR: Unknown chord type '" .. chord_type .. "', falling back to major")
    base_chord = musicutil.generate_chord(chord_root_midi, "major", 0, 3)
  end

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
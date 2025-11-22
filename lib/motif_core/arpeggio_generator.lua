-- arpeggio_generator.lua
-- Unified arpeggio generation for both initial creation and stage regeneration
-- Provides velocity curve, strum position calculations, and complete motif generation
--
-- ARCHITECTURE NOTE: This is the pattern for future generator modes
-- When adding new generators (Foundations, Pulsar, etc. from lib/_to_assess/generators/):
-- 1. Create a generator module with generate_motif(lane_id, stage_id) function
-- 2. Create a stage handler (like generator_sequence.lua) that calls the generator
-- 3. Add the new motif_type to params and route in create_motif.lua
--
-- The separation is:
-- - Tape mode: recorder captures real-time input
-- - Arpeggio mode: this generator creates from sequencer parameters
-- - Future generator modes: similar pattern, different algorithms

local chord_generator = include('lib/motif_core/chord_generator')
local ArpeggioGenerator = {}

-- Calculate chord position with optional phasing
-- Phasing causes chord position to continue from previous loop instead of resetting
function ArpeggioGenerator.calculate_chord_position(active_index, chord_length, phase_offset)
  return ((active_index - 1 + phase_offset) % chord_length) + 1
end

-- Calculate velocity based on curve type and position in sequence
function ArpeggioGenerator.calculate_velocity(index, total_steps, curve_type, min_vel, max_vel)
  if curve_type == "Flat" then
    return (min_vel + max_vel) / 2
  end

  local progress = (index - 1) / math.max(total_steps - 1, 1)  -- 0 to 1
  local range = max_vel - min_vel

  if curve_type == "Crescendo" then
    return min_vel + (progress * range)
  elseif curve_type == "Decrescendo" then
    return max_vel - (progress * range)
  elseif curve_type == "Wave" then
    return min_vel + (math.sin(progress * math.pi) * range)
  elseif curve_type == "Alternating" then
    return (index % 2 == 1) and max_vel or min_vel
  elseif curve_type == "Accent First" then
    return (index == 1) and max_vel or min_vel
  elseif curve_type == "Accent Last" then
    return (index == total_steps) and max_vel or min_vel
  elseif curve_type == "Random" then
    return min_vel + (math.random() * range)
  end

  return (min_vel + max_vel) / 2
end

-- Calculate absolute time position within strum window
-- amount_percent is 0-100 (window size as percentage of sequence_duration)
-- Returns absolute time position where note should play
function ArpeggioGenerator.calculate_strum_position(index, total_steps, curve_type, amount_percent, direction, sequence_duration)
  if curve_type == "None" or amount_percent == 0 then
    -- No strum: return evenly spaced positions across full sequence
    return (index - 1) * (sequence_duration / total_steps)
  end

  -- Window size as percentage of total sequence duration
  local window_duration = sequence_duration * (amount_percent / 100)
  local progress = (index - 1) / math.max(total_steps - 1, 1)  -- 0 to 1
  local position_in_window = 0

  -- Apply curve shape to distribute notes within window
  if curve_type == "Linear" then
    -- Linear distribution
    position_in_window = progress * window_duration
  elseif curve_type == "Accelerating" then
    -- Quadratic acceleration (slow start, fast end)
    position_in_window = (progress * progress) * window_duration
  elseif curve_type == "Decelerating" then
    -- Inverse quadratic (fast start, slow end)
    position_in_window = (1 - math.pow(1 - progress, 2)) * window_duration
  elseif curve_type == "Sweep" then
    -- Sine curve acceleration
    position_in_window = math.sin(progress * math.pi / 2) * window_duration
  end

  -- Apply direction
  if direction == "Forward" then
    return position_in_window
  elseif direction == "Reverse" then
    return window_duration - position_in_window
  elseif direction == "Center Out" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return (distance / max_distance) * window_duration
  elseif direction == "Edges In" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return window_duration - ((distance / max_distance) * window_duration)
  elseif direction == "Alternating" then
    -- Split odd/even steps into two groups
    local half_window = window_duration / 2
    if index % 2 == 1 then
      -- Odd steps in first half
      local odd_index = math.floor((index - 1) / 2)
      local total_odds = math.ceil(total_steps / 2)
      local odd_progress = odd_index / math.max(total_odds - 1, 1)
      return odd_progress * half_window
    else
      -- Even steps in second half
      local even_index = (index / 2) - 1
      local total_evens = math.floor(total_steps / 2)
      local even_progress = even_index / math.max(total_evens - 1, 1)
      return half_window + (even_progress * half_window)
    end
  elseif direction == "Random" then
    return math.random() * window_duration
  end

  return position_in_window
end

--- Generate a complete arpeggio motif from parameters
-- @param lane_id: Lane index (1-4)
-- @param stage_id: Stage index (1-4)
-- @return: Motif table {events = [...], duration = number}
function ArpeggioGenerator.generate_motif(lane_id, stage_id)
  -- Get sequence structure (stays on lane)
  local step_length_str = params:string("lane_" .. lane_id .. "_arpeggio_step_length")
  local step_length = ArpeggioGenerator._interval_to_beats(step_length_str)
  local num_steps = params:get("lane_" .. lane_id .. "_arpeggio_num_steps")

  -- Get musical parameters from specified stage
  local octave = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_octave")
  local chord_root = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_chord_root")
  local chord_type = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_chord_type")
  local chord_length = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_chord_length")
  local chord_inversion = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_chord_inversion") - 1
  local note_duration_percent = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_note_duration")

  -- Get velocity curve parameters from stage
  local velocity_curve = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_velocity_curve")
  local velocity_min = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_velocity_min")
  local velocity_max = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_velocity_max")

  -- Get strum parameters from stage
  local strum_curve = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_strum_curve")
  local strum_amount = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_strum_amount")
  local strum_shape = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_strum_shape")

  -- Get phasing parameter
  local phasing_enabled = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_chord_phasing") == 2

  -- Generate chord using shared utility
  local effective_chord = chord_generator.generate_chord(chord_root, chord_type, chord_length, chord_inversion)

  if not effective_chord or #effective_chord == 0 then
    print("ERROR: Failed to generate chord for arpeggio")
    return {events = {}, duration = num_steps * step_length}
  end

  -- Get arpeggio keyboard to read step states
  local ArpeggioKeyboard = _seeker.keyboards[2]

  -- Collect active steps
  local active_steps = {}
  for step = 1, num_steps do
    if ArpeggioKeyboard.is_step_active(lane_id, step) then
      table.insert(active_steps, step)
    end
  end

  -- Calculate sequence duration for strum calculation
  local sequence_duration = num_steps * step_length

  -- Get phase offset from lane (only used if phasing enabled)
  local lane = _seeker.lanes[lane_id]
  local phase_offset = (phasing_enabled and lane) and lane.chord_phase_offset or 0

  -- Generate note events for each active step
  local events = {}
  for active_index, step in ipairs(active_steps) do
    -- Calculate absolute time position using strum window
    local step_time = ArpeggioGenerator.calculate_strum_position(active_index, #active_steps, strum_curve, strum_amount, strum_shape, sequence_duration)

    -- Map to chord note with optional phasing
    local chord_position = ArpeggioGenerator.calculate_chord_position(active_index, #effective_chord, phase_offset)
    local chord_note = effective_chord[chord_position]
    local final_note = chord_note + ((octave + 1) * 12)

    -- Calculate velocity using curve
    local step_velocity = ArpeggioGenerator.calculate_velocity(active_index, #active_steps, velocity_curve, velocity_min, velocity_max)

    -- Get grid coordinates
    local step_pos = ArpeggioKeyboard.step_to_grid(step)
    local step_x = step_pos and step_pos.x or 0
    local step_y = step_pos and step_pos.y or 0

    -- Add note_on event with step info for pattern filtering
    table.insert(events, {
      time = step_time,
      type = "note_on",
      note = final_note,
      velocity = step_velocity,
      x = step_x,
      y = step_y,
      step = step,
      generation = 1, -- Always 1 for generated arpeggios
      attack = params:get("lane_" .. lane_id .. "_attack"),
      decay = params:get("lane_" .. lane_id .. "_decay"),
      sustain = params:get("lane_" .. lane_id .. "_sustain"),
      release = params:get("lane_" .. lane_id .. "_release"),
      pan = params:get("lane_" .. lane_id .. "_pan")
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
      step = step,
      generation = 1
    })
  end

  -- Sort by time
  table.sort(events, function(a, b) return a.time < b.time end)

  -- Update phase offset for next loop if phasing enabled
  if phasing_enabled and lane then
    lane.chord_phase_offset = (lane.chord_phase_offset + #active_steps) % #effective_chord
  end

  return {
    events = events,
    duration = num_steps * step_length
  }
end

--- Helper function to convert interval string to beats
function ArpeggioGenerator._interval_to_beats(interval_str)
  if tonumber(interval_str) then
    return tonumber(interval_str)
  end
  local num, den = interval_str:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num) / tonumber(den)
  end
  return 1/8
end

return ArpeggioGenerator

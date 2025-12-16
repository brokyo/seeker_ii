-- generator.lua
-- Generates note sequences from chord and rhythm parameters
-- Each stage defines a complete chord pattern that plays when active
-- Contains all generation logic (chord, velocity, strum, pattern filtering)
-- Part of lib/modes/motif/types/composer/

local chord_generator = include('lib/modes/motif/core/chord_generator')
local ComposerGenerator = {}

-- Helper: Convert interval string to beats
local function interval_to_beats(interval_str)
  if tonumber(interval_str) then
    return tonumber(interval_str)
  end
  local num, den = interval_str:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num) / tonumber(den)
  end
  return 1/8
end

-- Maps step index to chord voice index
-- Phase offset rotates which chord voice plays on each loop
local function map_step_to_chord_voice(active_step_index, chord_length, phase_offset)
  return ((active_step_index - 1 + phase_offset) % chord_length) + 1
end

-- Returns MIDI velocity value (1-127) based on curve shape and position in sequence
local function calculate_velocity(step_index, total_steps, curve_type, min_vel, max_vel)
  if curve_type == "Flat" then
    return (min_vel + max_vel) / 2
  end

  local progress = (step_index - 1) / math.max(total_steps - 1, 1)  -- 0 to 1
  local range = max_vel - min_vel

  if curve_type == "Crescendo" then
    return min_vel + (progress * range)
  elseif curve_type == "Decrescendo" then
    return max_vel - (progress * range)
  elseif curve_type == "Wave" then
    return min_vel + (math.sin(progress * math.pi) * range)
  elseif curve_type == "Alternating" then
    return (step_index % 2 == 1) and max_vel or min_vel
  elseif curve_type == "Accent First" then
    return (step_index == 1) and max_vel or min_vel
  elseif curve_type == "Accent Last" then
    return (step_index == total_steps) and max_vel or min_vel
  elseif curve_type == "Random" then
    return min_vel + (math.random() * range)
  end

  return (min_vel + max_vel) / 2
end

-- Spreads notes across time (like strumming a guitar)
-- Returns time offset in beats for this voice
local function calculate_strum_position(note_index, total_steps, curve_type, amount_percent, direction, sequence_duration)
  if curve_type == "None" or amount_percent == 0 then
    return (note_index - 1) * (sequence_duration / total_steps)
  end

  local window_duration = sequence_duration * (amount_percent / 100)
  local progress = (note_index - 1) / math.max(total_steps - 1, 1)
  local position_in_window = 0

  -- Apply curve shape
  if curve_type == "Linear" then
    position_in_window = progress * window_duration
  elseif curve_type == "Accelerating" then
    position_in_window = (progress * progress) * window_duration
  elseif curve_type == "Decelerating" then
    position_in_window = (1 - math.pow(1 - progress, 2)) * window_duration
  elseif curve_type == "Sweep" then
    position_in_window = math.sin(progress * math.pi / 2) * window_duration
  end

  -- Apply direction
  if direction == "Forward" then
    return position_in_window
  elseif direction == "Reverse" then
    return window_duration - position_in_window
  elseif direction == "Center Out" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(note_index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return (distance / max_distance) * window_duration
  elseif direction == "Edges In" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(note_index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return window_duration - ((distance / max_distance) * window_duration)
  elseif direction == "Alternating" then
    local half_window = window_duration / 2
    if note_index % 2 == 1 then
      local odd_index = math.floor((note_index - 1) / 2)
      local total_odds = math.ceil(total_steps / 2)
      local odd_progress = odd_index / math.max(total_odds - 1, 1)
      return odd_progress * half_window
    else
      local even_index = (note_index / 2) - 1
      local total_evens = math.floor(total_steps / 2)
      local even_progress = even_index / math.max(total_evens - 1, 1)
      return half_window + (even_progress * half_window)
    end
  elseif direction == "Random" then
    return math.random() * window_duration
  end

  return position_in_window
end

-- Filter events by step pattern (e.g., 'Odds' keeps only odd-numbered steps)
local function filter_events_by_pattern(events, preset_name, num_steps)
  local step_filter = {}

  if preset_name == "All" then
    for i = 1, num_steps do
      step_filter[i] = true
    end
  elseif preset_name == "Odds" then
    for i = 1, num_steps, 2 do
      step_filter[i] = true
    end
  elseif preset_name == "Evens" then
    for i = 2, num_steps, 2 do
      step_filter[i] = true
    end
  elseif preset_name == "Downbeats" then
    for i = 1, num_steps, 4 do
      step_filter[i] = true
    end
  elseif preset_name == "Upbeats" then
    for i = 3, num_steps, 4 do
      step_filter[i] = true
    end
  elseif preset_name == "Sparse" then
    for i = 1, num_steps, 3 do
      step_filter[i] = true
    end
  else
    print("WARNING: Unknown pattern preset: " .. preset_name .. ", using All")
    for i = 1, num_steps do
      step_filter[i] = true
    end
  end

  local filtered_events = {}
  for _, event in ipairs(events) do
    if event.step and step_filter[event.step] then
      table.insert(filtered_events, event)
    elseif not event.step then
      table.insert(filtered_events, event)
    end
  end

  return filtered_events
end

-- Build complete note sequence for one stage using chord, velocity, and strum parameters
local function generate_motif(lane_id, stage_id)
  -- Get sequence structure (stays on lane)
  local step_length_str = params:string("lane_" .. lane_id .. "_composer_step_length")
  local step_length = interval_to_beats(step_length_str)
  local num_steps = params:get("lane_" .. lane_id .. "_composer_num_steps")

  -- Get musical parameters from specified stage
  local octave = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_octave")
  local chord_root = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_chord_root")
  local chord_type = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_chord_type")
  local chord_length = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_chord_length")
  local voice_rotation = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_voice_rotation")
  local voicing_style = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_voicing_style")
  local note_duration_percent = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_note_duration")

  -- Get velocity curve parameters
  local velocity_curve = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_velocity_curve")
  local velocity_min = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_velocity_min")
  local velocity_max = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_velocity_max")

  -- Get strum parameters
  local strum_curve = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_strum_curve")
  local strum_amount = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_strum_amount")
  local strum_shape = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_strum_shape")

  -- Get phasing parameter
  local phasing_enabled = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_chord_phasing") == 1

  -- Generate chord
  local effective_chord = chord_generator.generate_chord(chord_root, chord_type, chord_length, voice_rotation, voicing_style)

  if not effective_chord or #effective_chord == 0 then
    print("ERROR: Failed to generate chord for composer")
    return {events = {}, duration = num_steps * step_length}
  end

  -- Get composer keyboard to read step states
  local composer_keyboard = _seeker.composer.keyboard.grid

  -- Collect active steps
  local active_steps = {}
  for step = 1, num_steps do
    if composer_keyboard.is_step_active(lane_id, step) then
      table.insert(active_steps, step)
    end
  end

  local sequence_duration = num_steps * step_length

  -- Phase offset rotates chord voices on each loop when chord_phasing is enabled
  local lane = _seeker.lanes[lane_id]
  local phase_offset = (phasing_enabled and lane) and lane.chord_phase_offset or 0

  -- Generate note events
  local events = {}
  for active_index, step in ipairs(active_steps) do
    local step_time = calculate_strum_position(active_index, #active_steps, strum_curve, strum_amount, strum_shape, sequence_duration)
    local chord_voice = map_step_to_chord_voice(active_index, #effective_chord, phase_offset)
    local chord_note = effective_chord[chord_voice]
    -- Octave param is 1-indexed, MIDI calculation needs 0-indexed
    local final_note = chord_note + ((octave + 1) * 12)
    local step_velocity = calculate_velocity(active_index, #active_steps, velocity_curve, velocity_min, velocity_max)

    local step_pos = composer_keyboard.step_to_grid(step)
    local step_x = step_pos and step_pos.x or 0
    local step_y = step_pos and step_pos.y or 0

    table.insert(events, {
      time = step_time,
      type = "note_on",
      note = final_note,
      velocity = step_velocity,
      x = step_x,
      y = step_y,
      step = step,
      generation = 1,
      attack = params:get("lane_" .. lane_id .. "_attack"),
      decay = params:get("lane_" .. lane_id .. "_decay"),
      sustain = params:get("lane_" .. lane_id .. "_sustain"),
      release = params:get("lane_" .. lane_id .. "_release"),
      pan = params:get("lane_" .. lane_id .. "_pan")
    })

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

  table.sort(events, function(a, b) return a.time < b.time end)

  -- Update phase offset for next loop
  if phasing_enabled and lane then
    lane.chord_phase_offset = (lane.chord_phase_offset + #active_steps) % #effective_chord
  end

  return {
    events = events,
    duration = num_steps * step_length
  }
end

-- Build parameter list (shared by populate and rebuild)
local function build_param_list(lane_idx, stage_idx)
  return {
    { separator = true, title = "Timing" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_pattern" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_note_duration", arc_multi_float = {10, 5, 1} },
    { separator = true, title = "Strum" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_amount", arc_multi_float = {10, 5, 1} },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_shape" },
    { separator = true, title = "Dynamics" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_velocity_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_velocity_min", arc_multi_float = {10, 5, 1} },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_velocity_max", arc_multi_float = {10, 5, 1} }
  }
end

-- Populate initial parameters when entering stage config
function ComposerGenerator.populate_params(ui, lane_idx, stage_idx)
  ui.params = build_param_list(lane_idx, stage_idx)
end

-- Rebuild parameters (composer mode has fixed parameter set)
function ComposerGenerator.rebuild_params(ui, lane_idx, stage_idx)
  ui.params = build_param_list(lane_idx, stage_idx)
end

-- Draw grid UI (uses standard grid_ui draw from stage_config)
function ComposerGenerator.draw_grid(layers, grid_ui)
  -- Delegate to standard grid_ui draw method
  grid_ui:draw(layers)
end

-- Region visibility for composer mode
function ComposerGenerator.should_draw_region(region_name)
  -- Composer mode hides velocity and tuning regions
  return not (region_name == "velocity" or region_name == "tuning")
end

-- Prepare stage: Regenerate composer motif from parameters
function ComposerGenerator.prepare_stage(lane_id, stage_id, motif)
  local success, err = pcall(function()
    -- Generate core motif
    local regenerated = generate_motif(lane_id, stage_id)

    -- Apply pattern preset filter
    local pattern_preset = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_composer_pattern")
    if pattern_preset and pattern_preset ~= "All" then
      local num_steps = params:get("lane_" .. lane_id .. "_composer_num_steps")
      regenerated.events = filter_events_by_pattern(regenerated.events, pattern_preset, num_steps)
    end

    -- Update motif in place
    motif.events = regenerated.events
    motif.duration = regenerated.duration
  end)

  if not success then
    print("ERROR: Composer regeneration failed for lane " .. lane_id .. " stage " .. stage_id .. ": " .. tostring(err))
    -- Keep existing motif events on error
  end
end

-- Expose generate_motif for use by create component
ComposerGenerator.generate_motif = generate_motif

return ComposerGenerator

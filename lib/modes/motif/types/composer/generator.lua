-- generator.lua
-- Generates note sequences from chord and rhythm parameters
-- Each stage defines a complete chord pattern that plays when active
-- Contains all generation logic (chord, velocity, strum, pattern filtering)
-- Part of lib/modes/motif/types/composer/

local chord_generator = include('lib/modes/motif/core/chord_generator')
local ComposerGenerator = {}

-- Degree offsets for harmonic motion between stages
-- Maps option index to scale degree movement
local HARMONIC_MOTION = {
  0,   -- Hold
  1,   -- Step Up
  -1,  -- Step Down
  2,   -- Third Up
  -2,  -- Third Down
  3,   -- Fourth Up
  -3,  -- Fourth Down
  4,   -- Fifth Up
  -4,  -- Fifth Down
}

-- Resolve effective parameters for a stage, applying transform offsets when needed
-- Independent mode or Stage 1: reads params directly from that stage
-- Transform mode stages 2-4: reads Stage 1 as seed, applies cumulative drift
local function resolve_stage_params(lane_id, stage_id)
  local prefix = "lane_" .. lane_id .. "_stage_"
  local is_transform = params:string("lane_" .. lane_id .. "_composer_stage_mode") == "Transform"

  if not is_transform or stage_id == 1 then
    -- Read directly from this stage
    local s = prefix .. stage_id .. "_composer_"
    return {
      chord_root = params:get(s .. "chord_root"),
      chord_type = params:string(s .. "chord_type"),
      chord_length = params:get(s .. "chord_length"),
      voice_rotation = params:get(s .. "voice_rotation"),
      voicing_style = params:string(s .. "voicing_style"),
      octave = params:get(s .. "octave"),
      pattern = params:string(s .. "pattern"),
      note_duration = params:get(s .. "note_duration"),
      velocity_curve = params:string(s .. "velocity_curve"),
      velocity_min = params:get(s .. "velocity_min"),
      velocity_max = params:get(s .. "velocity_max"),
      strum_amount = params:get(s .. "strum_amount"),
      strum_curve = params:string(s .. "strum_curve"),
      strum_shape = params:string(s .. "strum_shape"),
      chord_phasing = params:get(s .. "chord_phasing") == 1,
    }
  end

  -- Transform mode: derive from Stage 1 seed with cumulative offsets
  local seed = prefix .. "1_composer_"
  local steps = stage_id - 1
  local degree_offset = HARMONIC_MOTION[params:get("lane_" .. lane_id .. "_composer_harmonic_motion")]
  local voice_drift = params:get("lane_" .. lane_id .. "_composer_voice_drift")
  local octave_drift = params:get("lane_" .. lane_id .. "_composer_octave_drift")
  local duration_drift = params:get("lane_" .. lane_id .. "_composer_duration_drift")
  local velocity_drift = params:get("lane_" .. lane_id .. "_composer_velocity_drift")
  local strum_drift = params:get("lane_" .. lane_id .. "_composer_strum_drift")

  local seed_root = params:get(seed .. "chord_root")
  local seed_rotation = params:get(seed .. "voice_rotation")
  local seed_octave = params:get(seed .. "octave")
  local seed_duration = params:get(seed .. "note_duration")
  local seed_vel_min = params:get(seed .. "velocity_min")
  local seed_vel_max = params:get(seed .. "velocity_max")
  local seed_strum = params:get(seed .. "strum_amount")

  return {
    chord_root = ((seed_root - 1 + degree_offset * steps) % 7) + 1,
    chord_type = params:string(seed .. "chord_type"),
    chord_length = params:get(seed .. "chord_length"),
    voice_rotation = util.clamp(seed_rotation + voice_drift * steps, -5, 5),
    voicing_style = params:string(seed .. "voicing_style"),
    octave = util.clamp(seed_octave + octave_drift * steps, 1, 7),
    pattern = params:string(seed .. "pattern"),
    note_duration = util.clamp(seed_duration + duration_drift * steps, 1, 300),
    velocity_curve = params:string(seed .. "velocity_curve"),
    velocity_min = util.clamp(seed_vel_min + velocity_drift * steps, 1, 127),
    velocity_max = util.clamp(seed_vel_max + velocity_drift * steps, 1, 127),
    strum_amount = util.clamp(seed_strum + strum_drift * steps, 0, 100),
    strum_curve = params:string(seed .. "strum_curve"),
    strum_shape = params:string(seed .. "strum_shape"),
    chord_phasing = params:get(seed .. "chord_phasing") == 1,
  }
end

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

-- Reorders index based on shape pattern
-- Used for both voice assignment and timing direction
-- Returns a reordered index (1-based) for mapping to chord voices
local function apply_shape_to_index(index, total, shape_type)
  if shape_type == "Forward" then
    return index
  elseif shape_type == "Reverse" then
    return total - index + 1
  elseif shape_type == "Center Out" then
    -- Middle indices get low values (play first), edges get high values
    local center = (total + 1) / 2
    local distance = math.abs(index - center)
    -- Create ranking: items closest to center get lowest ranks
    -- For 4 items: indices 2,3 are closest, then 1,4
    -- We need to convert distance to a rank
    local rank = 1
    for i = 1, total do
      local other_distance = math.abs(i - center)
      if other_distance < distance then
        rank = rank + 1
      elseif other_distance == distance and i < index then
        rank = rank + 1
      end
    end
    return rank
  elseif shape_type == "Edges In" then
    -- Edges get low values (play first), middle gets high values
    local center = (total + 1) / 2
    local distance = math.abs(index - center)
    local rank = 1
    for i = 1, total do
      local other_distance = math.abs(i - center)
      if other_distance > distance then
        rank = rank + 1
      elseif other_distance == distance and i < index then
        rank = rank + 1
      end
    end
    return rank
  elseif shape_type == "Alternating" then
    -- Odds first, then evens: 1,3,5,7,2,4,6,8
    if index % 2 == 1 then
      return math.ceil(index / 2)
    else
      return math.ceil(total / 2) + (index / 2)
    end
  elseif shape_type == "Random" then
    -- Random uses original index (timing randomness provides variation)
    return index
  end
  return index
end

-- Maps step index to chord voice index
-- Shape reorders which voice plays on which step
-- Phase offset rotates voices on each loop
local function map_step_to_chord_voice(active_step_index, total_active, chord_length, phase_offset, shape_type)
  local shaped_index = apply_shape_to_index(active_step_index, total_active, shape_type)
  return ((shaped_index - 1 + phase_offset) % chord_length) + 1
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
local function calculate_strum_position(note_index, total_steps, curve_type, amount_percent, shape, sequence_duration)
  if curve_type == "None" or amount_percent == 0 then
    return (note_index - 1) * (sequence_duration / total_steps)
  end

  local window_duration = sequence_duration * (amount_percent / 100)
  local progress = (note_index - 1) / math.max(total_steps - 1, 1)
  local position_in_window = 0

  -- Apply curve
  if curve_type == "Linear" then
    position_in_window = progress * window_duration
  elseif curve_type == "Accelerating" then
    position_in_window = (progress * progress) * window_duration
  elseif curve_type == "Decelerating" then
    position_in_window = (1 - math.pow(1 - progress, 2)) * window_duration
  elseif curve_type == "Sweep" then
    position_in_window = math.sin(progress * math.pi / 2) * window_duration
  end

  -- Apply shape
  if shape == "Forward" then
    return position_in_window
  elseif shape == "Reverse" then
    return window_duration - position_in_window
  elseif shape == "Center Out" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(note_index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return (distance / max_distance) * window_duration
  elseif shape == "Edges In" then
    local center = (total_steps + 1) / 2
    local distance = math.abs(note_index - center)
    local max_distance = math.max(center - 1, total_steps - center)
    return window_duration - ((distance / max_distance) * window_duration)
  elseif shape == "Alternating" then
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
  elseif shape == "Random" then
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
  -- Get sequence structure (lane-level)
  local step_length_str = params:string("lane_" .. lane_id .. "_composer_step_length")
  local step_length = interval_to_beats(step_length_str)
  local num_steps = params:get("lane_" .. lane_id .. "_composer_num_steps")

  -- Resolve all musical parameters (handles transform mode offsets)
  local p = resolve_stage_params(lane_id, stage_id)

  -- Generate chord
  local effective_chord = chord_generator.generate_chord(p.chord_root, p.chord_type, p.chord_length, p.voice_rotation, p.voicing_style)

  if not effective_chord or #effective_chord == 0 then
    print("ERROR: Failed to generate chord for composer")
    return {events = {}, duration = num_steps * step_length}
  end

  -- Get composer keyboard to read step states (old type-2 composer, may not exist)
  local composer_keyboard = _seeker.composer_mode and _seeker.composer_mode.keyboard
    and _seeker.composer_mode.keyboard.grid
  if not composer_keyboard then
    return {events = {}, duration = num_steps * step_length}
  end

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
  local phase_offset = (p.chord_phasing and lane) and lane.chord_phase_offset or 0

  -- Generate note events
  local events = {}
  for active_index, step in ipairs(active_steps) do
    local step_time = calculate_strum_position(active_index, #active_steps, p.strum_curve, p.strum_amount, p.strum_shape, sequence_duration)
    local chord_voice = map_step_to_chord_voice(active_index, #active_steps, #effective_chord, phase_offset, p.strum_shape)
    local chord_note = effective_chord[chord_voice]
    -- Octave param is 1-indexed, MIDI calculation needs 0-indexed
    local final_note = chord_note + ((p.octave + 1) * 12)
    local step_velocity = calculate_velocity(active_index, #active_steps, p.velocity_curve, p.velocity_min, p.velocity_max)

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

    local note_duration = step_length * (p.note_duration / 100)
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
  if p.chord_phasing and lane then
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
    { separator = true, title = "Rhythm" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_pattern" },
    { separator = true, title = "Shape" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_shape" },
    { separator = true, title = "Articulation" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_note_duration", arc_multi_float = {10, 5, 1} },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_amount", arc_multi_float = {10, 5, 1} },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_strum_curve" },
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

    -- Apply pattern preset filter using resolved params (respects transform mode)
    local p = resolve_stage_params(lane_id, stage_id)
    local pattern_preset = p.pattern
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

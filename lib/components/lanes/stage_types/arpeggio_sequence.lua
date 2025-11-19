-- arpeggio_sequence.lua
-- Stage configuration for arpeggio mode (parameter-driven chord sequencer)
-- Unlike tape mode (transform-based), arpeggio stages regenerate events from chord parameters

local arpeggio_gen = include('lib/motif_core/arpeggio_generator')
local ArpeggioSequence = {}

-- Populate initial parameters when entering stage config
function ArpeggioSequence.populate_params(ui, lane_idx, stage_idx)
  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Chord Sequence" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_root" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_type" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_length" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_inversion" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_direction" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern" },
    { separator = true, title = "Velocity" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_min" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_max" },
    { separator = true, title = "Strum" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_amount" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_direction" },
    { separator = true, title = "Advanced" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" }
  }

  ui.params = param_table
end

-- Rebuild parameters (arpeggio mode has fixed parameter set, no dynamic rebuilding)
function ArpeggioSequence.rebuild_params(ui, lane_idx, stage_idx)
  -- Arpeggio mode always shows the same parameters
  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Chord Sequence" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_root" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_type" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_length" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_inversion" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_direction" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern" },
    { separator = true, title = "Velocity" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_min" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_max" },
    { separator = true, title = "Strum" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_amount" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_direction" },
    { separator = true, title = "Advanced" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" }
  }

  -- Update the UI with the parameter table
  ui.params = param_table
end

-- Draw grid UI (uses standard grid_ui draw from stage_config)
function ArpeggioSequence.draw_grid(layers, grid_ui)
  -- Delegate to standard grid_ui draw method
  grid_ui:draw(layers)
end

-- Region visibility for arpeggio mode
function ArpeggioSequence.should_draw_region(region_name)
  -- Arpeggio mode hides velocity and tuning regions
  return not (region_name == "velocity" or region_name == "tuning")
end

-- Prepare stage: Regenerate arpeggio from parameters
function ArpeggioSequence.prepare_stage(lane_id, stage_id, motif)
  local success, err = pcall(function()
    local arpeggio_utils = include('lib/motif_core/arpeggio')
    local musicutil = require('musicutil')

  -- Collect parameters (stage overrides OR lane defaults)
  local function get_param(name)
    local stage_param = "lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_" .. name
    local lane_param = "lane_" .. lane_id .. "_arpeggio_" .. name

    -- Try stage override first, fall back to lane default
    local stage_value = params:get(stage_param)
    if stage_value and stage_value > 0 then
      return stage_value
    end
    return params:get(lane_param)
  end

  local function get_param_string(name)
    local stage_param = "lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_" .. name
    local lane_param = "lane_" .. lane_id .. "_arpeggio_" .. name

    local stage_value = params:string(stage_param)
    if stage_value and stage_value ~= "" then
      return stage_value
    end
    return params:string(lane_param)
  end

  -- Get generation parameters
  local chord_root_degree = get_param("chord_root")
  local chord_type = get_param_string("chord_type")
  local chord_length = get_param("chord_length")
  local chord_inversion = get_param("chord_inversion") - 1  -- Convert to 0-based
  local chord_direction = get_param("chord_direction")
  local pattern_preset = get_param_string("pattern")
  local num_steps = params:get("lane_" .. lane_id .. "_arpeggio_num_steps")
  local step_length_str = params:string("lane_" .. lane_id .. "_arpeggio_step_length")
  local note_duration_percent = params:get("lane_" .. lane_id .. "_arpeggio_note_duration")
  local octave = params:get("lane_" .. lane_id .. "_keyboard_octave")

  -- Get velocity curve parameters
  local velocity_curve = get_param_string("velocity_curve")
  local velocity_min = get_param("velocity_min")
  local velocity_max = get_param("velocity_max")

  -- Get strum parameters
  local strum_curve = get_param_string("strum_curve")
  local strum_amount = get_param("strum_amount")
  local strum_direction = get_param_string("strum_direction")

  -- Get global scale settings
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  -- Convert scale degree to semitone offset
  local degree_index = ((chord_root_degree - 1) % #scale.intervals) + 1
  local semitone_offset = scale.intervals[degree_index]
  local chord_root_midi = ((root_note - 1) + semitone_offset) % 12

  -- Generate chord using motif_recorder's method
  local motif_recorder = _seeker.motif_recorder
  local effective_chord = motif_recorder:_generate_chord(chord_root_degree, chord_type, chord_length, chord_inversion)

  -- Get arpeggio keyboard to check active steps (all steps active in current model)
  local ArpeggioKeyboard = _seeker.keyboards[2]
  local active_steps = {}
  for step = 1, num_steps do
    if ArpeggioKeyboard.is_step_active(lane_id, step) then
      table.insert(active_steps, step)
    end
  end

  -- Apply direction to chord
  effective_chord = motif_recorder:_apply_direction(effective_chord, chord_direction, #active_steps)

  -- Parse step length
  local step_length
  if tonumber(step_length_str) then
    step_length = tonumber(step_length_str)
  else
    local num, den = step_length_str:match("(%d+)/(%d+)")
    if num and den then
      step_length = tonumber(num) / tonumber(den)
    else
      step_length = 1/8  -- Default
    end
  end

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

    -- Add note_on event with step info for pattern filtering
    table.insert(events, {
      time = step_time,
      type = "note_on",
      note = final_note,
      velocity = step_velocity,
      x = step_x,
      y = step_y,
      step = step,
      generation = motif_recorder.current_generation,
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
      generation = motif_recorder.current_generation
    })
  end

  -- Sort by time
  table.sort(events, function(a, b) return a.time < b.time end)

  -- Apply pattern preset filter
  if pattern_preset and pattern_preset ~= "All" then
    events = arpeggio_utils.apply_pattern_preset(events, pattern_preset, num_steps)
  end

    -- Update motif with regenerated events
    motif.events = events
    motif.duration = num_steps * step_length
  end)

  if not success then
    print("ERROR: Arpeggio regeneration failed for lane " .. lane_id .. " stage " .. stage_id .. ": " .. tostring(err))
    -- Keep existing motif events on error
  end
end

return ArpeggioSequence

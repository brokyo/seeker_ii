-- tape_transform.lua
-- Stage configuration for tape mode (live recording)
-- Handles transform selection and transform-specific parameters

local TapeTransform = {}

-- Populate initial parameters when entering stage config
function TapeTransform.populate_params(ui, lane_idx, stage_idx)
  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Transform" },
    { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx },
    { separator = true, title = "Advanced" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" }
  }

  ui.params = param_table
end

-- Rebuild parameters based on selected transform
function TapeTransform.rebuild_params(ui, lane_idx, stage_idx)
  -- Get the current transform type
  local transform_type = params:string("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)

  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Transform" },
    { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx }
  }

  -- Add transform-specific parameters
  if transform_type == "None" then
    -- No additional parameters

  elseif transform_type == "Overdub Filter" then
    table.insert(param_table, { separator = true, title = "Overdub Filter Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round"
    })

  elseif transform_type == "Harmonize" then
    table.insert(param_table, { separator = true, title = "Harmonize Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume"
    })

  elseif transform_type == "Transpose" then
    table.insert(param_table, { separator = true, title = "Transpose Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount"
    })

  elseif transform_type == "Rotate" then
    table.insert(param_table, { separator = true, title = "Rotate Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount"
    })

  elseif transform_type == "Skip" then
    table.insert(param_table, { separator = true, title = "Skip Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_interval"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_offset"
    })

  elseif transform_type == "Ratchet" then
    table.insert(param_table, { separator = true, title = "Ratchet Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_chance"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_max_repeats"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_timing"
    })

  elseif transform_type == "Reverse" then
    -- No additional parameters

  elseif transform_type == "Arpeggio" then
    -- Arpeggio TRANSFORM (not mode) - transforms existing notes into arpeggios
    table.insert(param_table, { separator = true, title = "Arpeggio Config" })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_scale_degree"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_direction"
    })
    table.insert(param_table, {
      id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_inversion"
    })
  end

  -- Add Advanced section at the end
  table.insert(param_table, { separator = true, title = "Advanced" })
  table.insert(param_table, { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" })
  table.insert(param_table, { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" })

  -- Update the UI with the new parameter table
  ui.params = param_table
end

-- Draw grid UI (uses standard grid_ui draw from stage_config)
function TapeTransform.draw_grid(layers, grid_ui)
  -- Delegate to standard grid_ui draw method
  grid_ui:draw(layers)
end

-- Region visibility for tape mode
function TapeTransform.should_draw_region(region_name)
  -- Tape mode shows all regions (velocity, tuning, etc.)
  return true
end

-- Prepare stage: Reset to genesis and apply transform
function TapeTransform.prepare_stage(lane_id, stage_id, motif)
  local tape_transforms = include('lib/tape_transforms')

  -- Reset motif to genesis if configured
  local reset_motif = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_reset_motif") == 2
  if reset_motif then
    motif:reset_to_genesis()
  end

  -- Get and apply transform
  local transform_ui_name = params:string("lane_" .. lane_id .. "_transform_stage_" .. stage_id)
  local transform_id = tape_transforms.get_transform_id_by_ui_name(transform_ui_name)

  if transform_id and transform_id ~= "none" then
    local transform = tape_transforms.available[transform_id]
    motif.events = transform.fn(motif.events, lane_id, stage_id)
  end
end

return TapeTransform

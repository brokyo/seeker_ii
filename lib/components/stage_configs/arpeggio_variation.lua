-- arpeggio_variation.lua
-- Stage configuration for arpeggio mode (step sequencer)
-- Handles arpeggio-specific stage variations (scale degree, pattern, direction, inversion)
-- No transforms - arpeggio mode uses variations instead

local ArpeggioVariation = {}

-- Populate initial parameters when entering stage config
function ArpeggioVariation.populate_params(ui, lane_idx, stage_idx)
  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Arpeggio Variation" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_scale_degree" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_direction" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_inversion" },
    { separator = true, title = "Advanced" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" }
  }

  ui.params = param_table
end

-- Rebuild parameters (arpeggio mode has fixed parameter set, no dynamic rebuilding)
function ArpeggioVariation.rebuild_params(ui, lane_idx, stage_idx)
  -- Arpeggio mode always shows the same parameters
  local param_table = {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { separator = true, title = "Arpeggio Variation" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_scale_degree" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_direction" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_inversion" },
    { separator = true, title = "Advanced" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" }
  }

  -- Update the UI with the parameter table
  ui.params = param_table
end

-- Draw grid UI (uses standard grid_ui draw from stage_config)
function ArpeggioVariation.draw_grid(layers, grid_ui)
  -- Delegate to standard grid_ui draw method
  grid_ui:draw(layers)
end

-- Region visibility for arpeggio mode
function ArpeggioVariation.should_draw_region(region_name)
  -- Arpeggio mode hides velocity and tuning regions
  -- (uses step states and chord parameters instead)
  return not (region_name == "velocity" or region_name == "tuning")
end

return ArpeggioVariation

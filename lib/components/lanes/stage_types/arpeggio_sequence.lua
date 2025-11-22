-- arpeggio_sequence.lua
-- Stage configuration for arpeggio mode (parameter-driven chord sequencer)
-- Unlike tape mode (transform-based), arpeggio stages regenerate events from chord parameters

local arpeggio_gen = include('lib/motif_core/arpeggio_generator')
local ArpeggioSequence = {}

-- Build parameter list (shared by populate and rebuild)
local function build_param_list(lane_idx, stage_idx)
  return {
    { separator = true, title = "Stage " .. stage_idx .. " Settings" },
    { id = "lane_" .. lane_idx .. "_config_stage" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
    { separator = true, title = "Chord Sequence" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_root" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_type" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_length" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_inversion" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_octave" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_chord_phasing" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_pattern" },
    { separator = true, title = "Strum" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_note_duration" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_amount" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_strum_shape" },
    { separator = true, title = "Velocity" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_curve" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_min" },
    { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_arpeggio_velocity_max" }
  }
end

-- Populate initial parameters when entering stage config
function ArpeggioSequence.populate_params(ui, lane_idx, stage_idx)
  ui.params = build_param_list(lane_idx, stage_idx)
end

-- Rebuild parameters (arpeggio mode has fixed parameter set)
function ArpeggioSequence.rebuild_params(ui, lane_idx, stage_idx)
  ui.params = build_param_list(lane_idx, stage_idx)
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
    -- Use unified generator for core motif generation
    local regenerated = arpeggio_gen.generate_motif(lane_id, stage_id)

    -- Apply pattern preset filter (stage-specific feature)
    local pattern_preset = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_pattern")
    if pattern_preset and pattern_preset ~= "All" then
      local arpeggio_utils = include('lib/motif_core/arpeggio')
      local num_steps = params:get("lane_" .. lane_id .. "_arpeggio_num_steps")
      regenerated.events = arpeggio_utils.apply_pattern_preset(regenerated.events, pattern_preset, num_steps)
    end

    -- Update motif in place
    motif.events = regenerated.events
    motif.duration = regenerated.duration
  end)

  if not success then
    print("ERROR: Arpeggio regeneration failed for lane " .. lane_id .. " stage " .. stage_id .. ": " .. tostring(err))
    -- Keep existing motif events on error
  end
end

return ArpeggioSequence

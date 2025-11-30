-- keyboard_mode.lua
-- Full-page grid mode for keyboard/performance interface
-- Orchestrates keyboard, velocity, tuning, motif, and lane control components

local KeyboardRegion = include("lib/grid/keyboard_region")
local GridAnimations = include("lib/grid/animations")

local KeyboardMode = {}

-- Motif type constants
local TAPE_MODE = 1
local ARPEGGIO_MODE = 2

-- Determine which regions should be visible based on current motif type
-- NOTE: This duplicates logic from stage_types/tape_transform and arpeggio_sequence
-- See roadmap.md - Mode System Grid Component Registration debt
local function should_draw_region(region_name)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

  if motif_type == TAPE_MODE then
    -- Tape mode shows all regions
    return true
  elseif motif_type == ARPEGGIO_MODE then
    -- Arpeggio mode hides velocity and tuning regions
    return not (region_name == "velocity" or region_name == "tuning")
  end

  return true
end

-- Draw all keyboard mode elements
function KeyboardMode.draw_full_page(layers)
  -- Draw performance components with conditional visibility
  if should_draw_region("velocity") then
    _seeker.velocity.grid:draw(layers)
  end

  _seeker.motif_playback.grid:draw(layers)

  if should_draw_region("tuning") then
    _seeker.tuning.grid:draw(layers)
  end

  -- Draw harmonic config (row 2, arpeggio mode only)
  _seeker.harmonic_config.grid:draw(layers)

  -- Draw expression config (row 3, shares row position with tuning in tape mode)
  _seeker.expression_config.grid:draw(layers)

  -- Draw keyboard
  KeyboardRegion.draw(layers)

  -- Draw motif configuration buttons (bottom row)
  _seeker.clear_motif.grid:draw(layers)
  _seeker.create_motif.grid:draw(layers)
  _seeker.tape_stage_config.grid:draw(layers)

  -- Draw lane config (8-button grid)
  _seeker.lane_config.grid:draw(layers)

  -- Draw response layer elements
  KeyboardRegion.draw_motif_events(layers)

  -- Get trails from focused lane
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  GridAnimations.update_trails(layers.response, focused_lane.trails)

  -- Draw keyboard outline when recording
  GridAnimations.update_keyboard_outline(layers.response, { fps = 30 }, _seeker.motif_recorder)
end

-- Handle all keyboard mode input
function KeyboardMode.handle_full_page_key(x, y, z)
  -- Check if in keyboard region
  if KeyboardRegion.contains(x, y) then
    KeyboardRegion.handle_key(x, y, z)
    return true
  end

  -- Register activity for non-keyboard interactions
  _seeker.ui_state.register_activity()

  -- Route to appropriate component
  if _seeker.lane_config.grid:contains(x, y) then
    _seeker.lane_config.grid:handle_key(x, y, z)
  elseif _seeker.motif_playback.grid:contains(x, y) then
    _seeker.motif_playback.grid:handle_key(x, y, z)
  elseif _seeker.velocity.grid:contains(x, y) and should_draw_region("velocity") then
    _seeker.velocity.grid:handle_key(x, y, z)
  elseif _seeker.tuning.grid:contains(x, y) and should_draw_region("tuning") then
    _seeker.tuning.grid:handle_key(x, y, z)
  elseif _seeker.harmonic_config.grid:contains(x, y) then
    _seeker.harmonic_config.grid:handle_key(x, y, z)
  elseif _seeker.expression_config.grid:contains(x, y) then
    _seeker.expression_config.grid:handle_key(x, y, z)
  elseif _seeker.clear_motif.grid:contains(x, y) then
    _seeker.clear_motif.grid:handle_key(x, y, z)
  elseif _seeker.create_motif.grid:contains(x, y) then
    _seeker.create_motif.grid:handle_key(x, y, z)
  elseif _seeker.tape_stage_config.grid:contains(x, y) then
    _seeker.tape_stage_config.grid:handle_key(x, y, z)
  end

  return true
end

return KeyboardMode

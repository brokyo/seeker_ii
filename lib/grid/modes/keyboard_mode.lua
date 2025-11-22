-- keyboard_mode.lua
-- Full-page grid mode for keyboard/performance interface
-- Orchestrates keyboard, velocity, tuning, motif, and lane control components

local KeyboardRegion = include("lib/grid/keyboard_region")
local StageConfig = include("lib/components/lanes/stage_config")
local GridAnimations = include("lib/grid/animations")

local KeyboardMode = {}

-- Determine which regions should be visible based on current motif type
local function should_draw_region(region_name)
  -- Delegate mode-specific region visibility to active stage config
  local active_config = StageConfig.get_active_config()
  return active_config.should_draw_region(region_name)
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

  -- Draw keyboard
  KeyboardRegion.draw(layers)

  -- Draw motif configuration buttons (bottom row)
  _seeker.clear_motif.grid:draw(layers)
  _seeker.create_motif.grid:draw(layers)
  _seeker.stage_config.grid:draw(layers)

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
  elseif _seeker.clear_motif.grid:contains(x, y) then
    _seeker.clear_motif.grid:handle_key(x, y, z)
  elseif _seeker.create_motif.grid:contains(x, y) then
    _seeker.create_motif.grid:handle_key(x, y, z)
  elseif _seeker.stage_config.grid:contains(x, y) then
    _seeker.stage_config.grid:handle_key(x, y, z)
  end

  return true
end

return KeyboardMode

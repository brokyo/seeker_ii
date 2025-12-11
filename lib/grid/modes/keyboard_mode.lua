-- keyboard_mode.lua
-- Full-page grid mode for keyboard/performance interface
-- Orchestrates type-specific components via registry, plus shared infrastructure

local GridAnimations = include("lib/grid/animations")
local type_registry = include("lib/modes/motif/type_registry")

local KeyboardMode = {}

-- Draw all keyboard mode elements
function KeyboardMode.draw_full_page(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()

  -- Draw type-specific components via registry (Tape, Composer, Sampler)
  local current_type = type_registry.get_current()
  if current_type then
    current_type.draw(layers)
  end

  -- Shared infrastructure (all types)
  _seeker.lane_config.grid:draw(layers)

  -- Response layer elements
  local focused_lane = _seeker.lanes[focused_lane_id]
  GridAnimations.update_trails(layers.response, focused_lane.trails)
  GridAnimations.update_keyboard_outline(layers.response, { fps = 30 }, _seeker.motif_recorder)
end

-- Handle all keyboard mode input
function KeyboardMode.handle_full_page_key(x, y, z)
  -- Block non-keyboard input during sampler recording
  if _seeker.sampler and _seeker.sampler.is_recording then
    return true
  end

  -- Register activity for non-keyboard interactions
  _seeker.ui_state.register_activity()

  -- Shared infrastructure first (lane config)
  if _seeker.lane_config.grid:contains(x, y) then
    _seeker.lane_config.grid:handle_key(x, y, z)
    return true
  end

  -- Delegate to type-specific handler via registry (Tape, Composer, Sampler)
  local current_type = type_registry.get_current()
  if current_type then
    if current_type.handle_key(x, y, z) then
      return true
    end
  end

  return true
end

return KeyboardMode

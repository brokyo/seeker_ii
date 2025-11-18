-- mode_switcher.lua
-- Shared utilities for drawing and handling mode switcher buttons

local GridConstants = include("lib/grid/constants")
local GridModeRegistry = include("lib/grid/modes")

local ModeSwitcher = {}

-- Draw all mode switcher buttons with appropriate focus state
function ModeSwitcher.draw(layers)
  local current_mode = _seeker.current_mode

  for mode_id, config in pairs(GridModeRegistry.MODES) do
    local brightness = (current_mode == mode_id) and
      GridConstants.BRIGHTNESS.UI.FOCUSED or
      GridConstants.BRIGHTNESS.UI.NORMAL

    layers.ui[config.button.x][config.button.y] = brightness
  end
end

-- Check if a position is a mode switcher button
function ModeSwitcher.is_mode_button(x, y)
  for mode_id, config in pairs(GridModeRegistry.MODES) do
    if config.button.x == x and config.button.y == y then
      return mode_id
    end
  end
  return nil
end

-- Handle mode button press
function ModeSwitcher.handle_key(x, y, z)
  if z == 1 then
    local mode_id = ModeSwitcher.is_mode_button(x, y)
    if mode_id then
      local config = GridModeRegistry.get_mode(mode_id)
      _seeker.current_mode = mode_id
      _seeker.ui_state.set_current_section(config.default_section)
      return true
    end
  end
  return false
end

return ModeSwitcher

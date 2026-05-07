-- mode_switcher.lua
-- Shared utilities for drawing and handling mode switcher buttons
-- Mode buttons serve dual purpose: switch modes AND provide virtual navigation to primary component
-- Sub-mode buttons (row 3) switch grid layouts within a parent mode

local GridConstants = include("lib/grid/constants")
local GridModeRegistry = include("lib/grid/mode_registry")

local ModeSwitcher = {}

-- Draw all mode switcher buttons with appropriate focus state
function ModeSwitcher.draw(layers)
  local current_mode = _seeker.current_mode
  local current_sub_mode = _seeker.current_sub_mode

  for mode_id, config in pairs(GridModeRegistry.MODES) do
    -- Parent mode button
    local brightness = (current_mode == mode_id) and
      GridConstants.BRIGHTNESS.UI.FOCUSED or
      GridConstants.BRIGHTNESS.UI.NORMAL

    layers.ui[config.button.x][config.button.y] = brightness

    -- Sub-mode buttons (only drawn when parent mode is active)
    if config.sub_modes then
      for sub_id, sub_config in pairs(config.sub_modes) do
        local sub_brightness
        if current_mode == mode_id then
          sub_brightness = (current_sub_mode == sub_id) and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        else
          sub_brightness = GridConstants.BRIGHTNESS.OFF
        end
        layers.ui[sub_config.button.x][sub_config.button.y] = sub_brightness
      end
    end
  end
end

-- Check if a position is a mode switcher button
-- Returns mode_id, sub_mode_id (sub_mode_id is nil for parent buttons)
function ModeSwitcher.is_mode_button(x, y)
  for mode_id, config in pairs(GridModeRegistry.MODES) do
    if config.button.x == x and config.button.y == y then
      return mode_id, nil
    end
    -- Check sub-mode buttons
    if config.sub_modes then
      for sub_id, sub_config in pairs(config.sub_modes) do
        if sub_config.button.x == x and sub_config.button.y == y then
          return mode_id, sub_id
        end
      end
    end
  end
  return nil, nil
end

-- Handle mode button press
function ModeSwitcher.handle_key(x, y, z)
  if z == 1 then
    local mode_id, sub_mode_id = ModeSwitcher.is_mode_button(x, y)
    if mode_id then
      local config = GridModeRegistry.get_mode(mode_id)

      if sub_mode_id then
        -- Sub-mode button: switch to parent mode, restore sub-mode's last focused lane
        _seeker.current_mode = mode_id
        _seeker.ui_state.switch_sub_mode(sub_mode_id)
        _seeker.ui_state.set_current_section(config.sub_modes[sub_mode_id].default_section)
      else
        -- Parent mode button: navigate to parent default section
        _seeker.current_mode = mode_id
        _seeker.current_sub_mode = nil
        _seeker.ui_state.set_current_section(config.default_section)
      end
      return true
    end
  end
  return false
end

return ModeSwitcher

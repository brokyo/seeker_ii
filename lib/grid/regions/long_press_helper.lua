-- long_press_helper.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local LongPressHelper = {}

-- Configuration for different regions
LongPressHelper.REGION_CONFIGS = {
  GENERATE = {
    keyboard_outline = {
      x_start = 6,
      y_start = 2,
      width = 6,
      height = 6
    }
  },
  RECORDING = {
    keyboard_outline = {
      x_start = 6,
      y_start = 2,
      width = 6,
      height = 6
    }
  },
  OVERDUB = {
    keyboard_outline = {
      x_start = 6,
      y_start = 2,
      width = 6,
      height = 6
    }
  },
  MOTIF = {
    keyboard_outline = {
      x_start = 6,
      y_start = 2,
      width = 6,
      height = 6
    }
  }
}

-- Draw keyboard outline for a region
function LongPressHelper.draw_keyboard_outline(layers, config)
  -- Top row
  for x = 0, config.width - 1 do
    layers.response[config.x_start + x][config.y_start] = GridConstants.BRIGHTNESS.HIGH
  end
  -- Bottom row
  for x = 0, config.width - 1 do
    layers.response[config.x_start + x][config.y_start + config.height - 1] = GridConstants.BRIGHTNESS.HIGH
  end
  -- Side columns
  for y = 0, config.height - 1 do
    layers.response[config.x_start][config.y_start + y] = GridConstants.BRIGHTNESS.HIGH
    layers.response[config.x_start + config.width - 1][config.y_start + y] = GridConstants.BRIGHTNESS.HIGH
  end
end

-- Add long press behavior to a region
function LongPressHelper.add_to_region(region, section_id)
  -- Add is_holding_long_press method
  function region:is_holding_long_press()
    for key_id, press in pairs(self.press_state.pressed_keys) do
      local elapsed = util.time() - press.start_time
      if elapsed >= Section.LONG_PRESS_THRESHOLD then
        return true
      end
    end
    return false
  end

  -- Override draw to add keyboard outline
  local original_draw = region.draw
  function region.draw(layers)
    if region:is_holding_long_press() then
      LongPressHelper.draw_keyboard_outline(layers, LongPressHelper.REGION_CONFIGS[section_id].keyboard_outline)
    end
    original_draw(layers)
  end

  -- Override handle_key to add long press state management
  local original_handle_key = region.handle_key
  function region.handle_key(x, y, z)
    local key_id = string.format("%d,%d", x, y)
    
    if z == 1 then -- Key pressed
      region:start_press(key_id)
      _seeker.ui_state.set_current_section(section_id)
      _seeker.ui_state.set_long_press_state(true, section_id)
      _seeker.screen_ui.set_needs_redraw()
    else -- Key released
      if region:is_long_press(key_id) then
        if original_handle_key then
          original_handle_key(x, y, z)
        end
      end
      
      -- Always clear long press state on release
      _seeker.ui_state.set_long_press_state(false, nil)
      _seeker.screen_ui.set_needs_redraw()
      
      region:end_press(key_id)
    end
  end

  -- Override is_long_press to add UI feedback
  function region:is_long_press(key_id)
    local press = self.press_state.pressed_keys[key_id]
    if press then
      local elapsed = util.time() - press.start_time
      if elapsed >= Section.LONG_PRESS_THRESHOLD and not press.long_press_triggered then
        press.long_press_triggered = true
        _seeker.ui_state.set_long_press_state(true, section_id)
        _seeker.screen_ui.set_needs_redraw()
        return true
      end
    end
    return false
  end
end

return LongPressHelper 
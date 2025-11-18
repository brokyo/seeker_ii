-- osc_selector.lua
-- 3×4 grid for selecting and switching to OSC output screens (Float/LFO/Trigger 1-4)
-- Similar to lane_config - each button switches focus to that output's parameters

local GridConstants = include("lib/grid/constants")

local OscSelector = {}

-- Layout: 3 rows × 4 columns
local LAYOUT = {
  x_start = 13,
  x_end = 16,
  y_start = 5,
  y_end = 7,
  width = 4,
  height = 3
}

-- Type mapping (rows)
local TYPES = {
  [5] = { name = "Float", param_value = 1 },
  [6] = { name = "LFO", param_value = 2 },
  [7] = { name = "Trigger", param_value = 3 }
}

-- Number mapping (columns)
local NUMBERS = {
  [13] = 1,
  [14] = 2,
  [15] = 3,
  [16] = 4
}

-- Check if position is within selector region
function OscSelector.contains(x, y)
  return x >= LAYOUT.x_start and x <= LAYOUT.x_end and
         y >= LAYOUT.y_start and y <= LAYOUT.y_end
end

-- Draw the selector grid
function OscSelector.draw(layers)
  local current_section = _seeker.ui_state.get_current_section()
  local selected_type = params:get("osc_selected_type")
  local selected_number = params:get("osc_selected_number")

  -- Draw all buttons
  for y = LAYOUT.y_start, LAYOUT.y_end do
    for x = LAYOUT.x_start, LAYOUT.x_end do
      local type_info = TYPES[y]
      local number = NUMBERS[x]

      -- Determine if this button is the currently focused output
      local is_selected = (type_info.param_value == selected_type) and
                          (number == selected_number)
      local is_on_output_screen = current_section == "OSC_OUTPUT"

      local brightness
      if is_selected and is_on_output_screen then
        brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
      elseif is_selected then
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      else
        brightness = GridConstants.BRIGHTNESS.UI.NORMAL
      end

      layers.ui[x][y] = brightness
    end
  end
end

-- Handle key press in selector
function OscSelector.handle_key(x, y, z)
  if z == 1 then -- Key down only
    local type_info = TYPES[y]
    local number = NUMBERS[x]

    if type_info and number then
      -- Switch focus to this output (updates screen to show its params)
      params:set("osc_selected_type", type_info.param_value)
      params:set("osc_selected_number", number)

      -- Switch screen section to OSC_OUTPUT to show this output's parameters
      _seeker.ui_state.set_current_section("OSC_OUTPUT")

      print(string.format("OSC: Focused %s %d", type_info.name, number))
      return true
    end
  end

  return false
end

return OscSelector

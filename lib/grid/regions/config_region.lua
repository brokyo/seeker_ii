-- config_region.lua
local GridConstants = include("lib/grid_constants")

local ConfigRegion = {}

ConfigRegion.layout = {
  x = 16,
  y = 1,
  width = 1,
  height = 1
}

function ConfigRegion.contains(x, y)
  return x == ConfigRegion.layout.x and y == ConfigRegion.layout.y
end

function ConfigRegion.draw(layers)
  local brightness = (_seeker.ui_state.get_current_section() == "CONFIG") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  layers.ui[ConfigRegion.layout.x][ConfigRegion.layout.y] = brightness
end

function ConfigRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    _seeker.ui_state.set_current_section("CONFIG")
  end
end

return ConfigRegion 
-- eurorack_output_region.lua
local GridConstants = include("lib/grid_constants")

local EurorackOutputRegion = {}

EurorackOutputRegion.layout = {
  x = 15,
  y = 2,
  width = 1,
  height = 1
}

function EurorackOutputRegion.contains(x, y)
  return x == EurorackOutputRegion.layout.x and y == EurorackOutputRegion.layout.y
end

function EurorackOutputRegion.draw(layers)
  local brightness = (_seeker.ui_state.get_current_section() == "EURORACK_OUTPUT") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  layers.ui[EurorackOutputRegion.layout.x][EurorackOutputRegion.layout.y] = brightness
end

function EurorackOutputRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    _seeker.ui_state.set_current_section("EURORACK_OUTPUT")
  end
end

return EurorackOutputRegion 
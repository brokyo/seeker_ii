-- lane_region.lua
local GridConstants = include("lib/grid_constants")

local LaneRegion = {}

LaneRegion.layout = {
  x = 13,
  y = 7,
  width = 4,
  height = 1
}

function LaneRegion.contains(x, y)
  return x >= LaneRegion.layout.x and 
         x < LaneRegion.layout.x + LaneRegion.layout.width and 
         y == LaneRegion.layout.y
end

function LaneRegion.draw(layers)
  for i = 0, LaneRegion.layout.width - 1 do
    local brightness = (i + 1 == _seeker.ui_state.get_focused_lane()) and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    layers.ui[LaneRegion.layout.x + i][LaneRegion.layout.y] = brightness
  end
end

function LaneRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local new_lane_idx = (x - LaneRegion.layout.x) + 1
    _seeker.ui_state.set_focused_lane(new_lane_idx)
    _seeker.ui_state.set_current_section("LANE")
  end
end

return LaneRegion 
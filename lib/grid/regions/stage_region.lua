-- stage_region.lua
local GridConstants = include("lib/grid_constants")

local StageRegion = {}

StageRegion.layout = {
  x = 13,
  y = 6,
  width = 4,
  height = 1
}

function StageRegion.contains(x, y)
  return x >= StageRegion.layout.x and 
         x < StageRegion.layout.x + StageRegion.layout.width and 
         y == StageRegion.layout.y
end

function StageRegion.draw(layers)
  for i = 0, StageRegion.layout.width - 1 do
    local brightness = (i + 1 == _seeker.ui_state.get_focused_stage()) and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    layers.ui[StageRegion.layout.x + i][StageRegion.layout.y] = brightness
  end
end

function StageRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local new_stage_idx = (x - StageRegion.layout.x) + 1
    _seeker.ui_state.set_focused_stage(new_stage_idx)
    _seeker.ui_state.set_current_section("STAGE")
  end
end

return StageRegion 
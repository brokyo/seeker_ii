-- transform_region.lua
local GridConstants = include("lib/grid_constants")

local TransformRegion = {}

TransformRegion.layout = {
  x = 13,
  y = 5,
  width = 4,
  height = 1
}

function TransformRegion.contains(x, y)
  return x >= TransformRegion.layout.x and 
         x < TransformRegion.layout.x + TransformRegion.layout.width and 
         y == TransformRegion.layout.y
end

function TransformRegion.draw(layers)
  for i = 0, TransformRegion.layout.width - 1 do
    local brightness = (_seeker.ui_state.get_current_section() == "TRANSFORM") and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    layers.ui[TransformRegion.layout.x + i][TransformRegion.layout.y] = brightness
  end
end

function TransformRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local stage_idx = (x - TransformRegion.layout.x) + 1
    _seeker.ui_state.set_focused_stage(stage_idx)
    _seeker.ui_state.set_current_section("TRANSFORM")
  end
end

return TransformRegion 
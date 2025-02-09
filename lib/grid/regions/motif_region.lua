-- motif_region.lua
local GridConstants = include("lib/grid_constants")

local MotifRegion = {}

MotifRegion.layout = {
  x = 1,
  y = 6,
  width = 1,
  height = 1
}

function MotifRegion.contains(x, y)
  return x == MotifRegion.layout.x and y == MotifRegion.layout.y
end

function MotifRegion.draw(layers)
  local brightness = (_seeker.ui_state.get_current_section() == "MOTIF") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  layers.ui[MotifRegion.layout.x][MotifRegion.layout.y] = brightness
end

function MotifRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    _seeker.ui_state.set_current_section("MOTIF")
    _seeker.screen_ui.sections.MOTIF:update_focused_motif(_seeker.ui_state.get_focused_lane())
  end
end

return MotifRegion 
-- play_region.lua
local GridConstants = include("lib/grid_constants")

local PlayRegion = {}

PlayRegion.layout = {
  x = 4,
  y = 6,
  width = 1,
  height = 1
}

function PlayRegion.contains(x, y)
  return x == PlayRegion.layout.x and y == PlayRegion.layout.y
end

function PlayRegion.draw(layers)
  local brightness = _seeker.lanes[_seeker.ui_state.get_focused_lane()].playing and 
    GridConstants.BRIGHTNESS.CONTROLS.PLAY_ACTIVE or 
    GridConstants.BRIGHTNESS.CONTROLS.PLAY_INACTIVE
  layers.ui[PlayRegion.layout.x][PlayRegion.layout.y] = brightness
end

function PlayRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    if lane.playing then
      lane:stop()
    else
      lane:play()
    end
  end
end

return PlayRegion 
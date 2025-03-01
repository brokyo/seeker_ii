-- debug_region.lua
local GridConstants = include("lib/grid_constants")

local DebugRegion = {}

DebugRegion.layout = {
  x = 1,
  y = 1,
  width = 16,  -- Use full grid width
  height = 1
}

function DebugRegion.contains(x, y)
  return x >= DebugRegion.layout.x and 
         x < DebugRegion.layout.x + DebugRegion.layout.width and 
         y == DebugRegion.layout.y
end

function DebugRegion.draw(layers)
  -- Draw lane status indicators in a horizontal line
  for lane_idx = 1, 8 do  -- We have 8 lanes
    local lane = _seeker.lanes[lane_idx]
    
    -- Calculate x position for this lane's status group (2 LEDs per lane)
    local base_x = DebugRegion.layout.x + ((lane_idx - 1) * 2)
    
    -- First LED: Playing status
    local play_brightness = lane.playing and GridConstants.BRIGHTNESS.HIGH or GridConstants.BRIGHTNESS.LOW
    layers.ui[base_x][DebugRegion.layout.y] = play_brightness
    
    -- Second LED: Current stage (brightness varies by stage number)
    local stage_brightness = math.floor(GridConstants.BRIGHTNESS.LOW + 
      ((lane.current_stage_index or 1) / 4) * (GridConstants.BRIGHTNESS.HIGH - GridConstants.BRIGHTNESS.LOW))
    layers.ui[base_x + 1][DebugRegion.layout.y] = stage_brightness
  end
end

function DebugRegion.handle_key(x, y, z)
  -- No interaction needed for debug view
end

return DebugRegion 
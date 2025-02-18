-- lane_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local LaneRegion = setmetatable({}, Section)
LaneRegion.__index = LaneRegion

LaneRegion.layout = {
  x = 13,
  y = 6,
  width = 4,
  height = 2
}

-- Shared press state
LaneRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function LaneRegion.contains(x, y)
  return x >= LaneRegion.layout.x and 
         x < LaneRegion.layout.x + LaneRegion.layout.width and 
         y >= LaneRegion.layout.y and
         y < LaneRegion.layout.y + LaneRegion.layout.height
end

function LaneRegion.draw(layers)
  local is_lane_section = _seeker.ui_state.get_current_section() == "LANE"
  
  for row = 0, LaneRegion.layout.height - 1 do
    for i = 0, LaneRegion.layout.width - 1 do
      local lane_idx = (row * LaneRegion.layout.width) + i + 1
      local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[lane_idx]
      
      local brightness
      if is_lane_section then
        if is_focused then
          brightness = GridConstants.BRIGHTNESS.FULL
        else
          brightness = GridConstants.BRIGHTNESS.HIGH
        end
      else
        if lane.playing then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
      end
      
      layers.ui[LaneRegion.layout.x + i][LaneRegion.layout.y + row] = brightness
    end
  end
end

function LaneRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  local row = y - LaneRegion.layout.y
  local new_lane_idx = (row * LaneRegion.layout.width) + (x - LaneRegion.layout.x) + 1
  
  if z == 1 then -- Key pressed
    LaneRegion:start_press(key_id)
    
    -- Always focus the lane on press
    _seeker.ui_state.set_focused_lane(new_lane_idx)
    _seeker.ui_state.set_current_section("LANE")
    
  else -- Key released
    if LaneRegion:is_long_press(key_id) then
      -- Long press - toggle playback
      local lane = _seeker.lanes[new_lane_idx]
      if lane.playing then
        lane:stop()
      else
        lane:play()
      end
    end
    
    LaneRegion:end_press(key_id)
  end
end

return LaneRegion 
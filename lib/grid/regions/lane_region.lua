-- lane_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local LaneRegion = setmetatable({}, Section)
LaneRegion.__index = LaneRegion

LaneRegion.layout = {
  x = 13,
  y = 7,
  width = 4,
  height = 1
}

-- Shared press state
LaneRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function LaneRegion.contains(x, y)
  return x >= LaneRegion.layout.x and 
         x < LaneRegion.layout.x + LaneRegion.layout.width and 
         y == LaneRegion.layout.y
end

function LaneRegion.draw(layers)
  for i = 0, LaneRegion.layout.width - 1 do
    local lane_idx = i + 1
    local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_idx]
    
    local brightness
    if lane.playing and #lane.active_notes > 0 then
      -- Pulse only when there are active notes
      local pulse = math.sin(clock.get_beats() * 4) * 3
      brightness = is_focused and
        math.floor(GridConstants.BRIGHTNESS.UI.FOCUSED + pulse) or
        math.floor(GridConstants.BRIGHTNESS.UI.UNFOCUSED + pulse)
    else
      -- Static brightness when not playing or no active notes
      brightness = is_focused and 
        GridConstants.BRIGHTNESS.UI.FOCUSED or 
        (lane.playing and GridConstants.BRIGHTNESS.UI.UNFOCUSED or GridConstants.BRIGHTNESS.UI.NORMAL)
    end
    
    layers.ui[LaneRegion.layout.x + i][LaneRegion.layout.y] = brightness
  end
end

function LaneRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  local new_lane_idx = (x - LaneRegion.layout.x) + 1
  
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
-- lane_region.lua
local GridConstants = include("lib/grid_constants")

local LaneRegion = {}

LaneRegion.layout = {
  x = 13,
  y = 7,
  width = 4,
  height = 1
}

-- Track last press time for double tap detection
LaneRegion.last_press = {
  time = 0,
  lane = nil
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
    if lane.playing then
      -- Pulse when playing (similar to rec button)
      local pulse = math.sin(clock.get_beats() * 4) * 3
      brightness = is_focused and
        math.floor(GridConstants.BRIGHTNESS.UI.FOCUSED + pulse) or
        math.floor(GridConstants.BRIGHTNESS.UI.UNFOCUSED + pulse)
    else
      -- Static brightness when not playing
      brightness = is_focused and 
        GridConstants.BRIGHTNESS.UI.FOCUSED or 
        GridConstants.BRIGHTNESS.UI.NORMAL
    end
    
    layers.ui[LaneRegion.layout.x + i][LaneRegion.layout.y] = brightness
  end
end

function LaneRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local new_lane_idx = (x - LaneRegion.layout.x) + 1
    local current_time = util.time()
    
    -- Always focus the lane
    _seeker.ui_state.set_focused_lane(new_lane_idx)
    _seeker.ui_state.set_current_section("LANE")
    
    -- Check for double tap (within 0.3 seconds)
    if new_lane_idx == LaneRegion.last_press.lane and 
       (current_time - LaneRegion.last_press.time) < 0.3 then
      -- Double tap detected - toggle playback
      local lane = _seeker.lanes[new_lane_idx]
      if lane.playing then
        lane:stop()
      else
        lane:play()
      end
      -- Reset last press to prevent triple-tap
      LaneRegion.last_press.time = 0
      LaneRegion.last_press.lane = nil
    else
      -- Update last press info
      LaneRegion.last_press.time = current_time
      LaneRegion.last_press.lane = new_lane_idx
    end
  end
end

return LaneRegion 
-- stage_region.lua
local GridConstants = include("lib/grid_constants")

local StageRegion = {}

StageRegion.layout = {
  x = 13,
  y = 2,
  width = 4,
  height = 1
}

function StageRegion.contains(x, y)
  return x >= StageRegion.layout.x and 
         x < StageRegion.layout.x + StageRegion.layout.width and 
         y == StageRegion.layout.y
end

function StageRegion.draw(layers)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local is_stage_section = _seeker.ui_state.get_current_section() == "STAGE"
  
  for i = 0, StageRegion.layout.width - 1 do
    local stage_idx = i + 1
    local is_active = focused_lane.playing and stage_idx == focused_lane.current_stage_index
    local is_focused = stage_idx == _seeker.ui_state.get_focused_stage()
    
    local brightness
    -- First handle focused stage in stage section
    if is_stage_section and is_focused then
      brightness = GridConstants.BRIGHTNESS.FULL
    -- Then handle active stage pulsing (unless it's the focused stage in stage section)
    elseif is_active then
      brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
    -- Show MEDIUM brightness for non-active stages only in stage section
    elseif is_stage_section then
      brightness = GridConstants.BRIGHTNESS.MEDIUM
    -- Otherwise show LOW brightness
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    
    layers.ui[StageRegion.layout.x + i][StageRegion.layout.y] = brightness
  end
end

function StageRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local new_stage_idx = (x - StageRegion.layout.x) + 1
    _seeker.ui_state.set_current_section("STAGE")
    _seeker.ui_state.set_focused_stage(new_stage_idx)
  end
end

return StageRegion 
-- octave_region.lua
local GridConstants = include("lib/grid_constants")

local TuningRegion = {}

TuningRegion.layout = {
  octave = {
    decrease = {x = 1, y = 2},
    increase = {x = 2, y = 2}
  },
  offset = {
    decrease = {x = 3, y = 2},
    increase = {x = 4, y = 2}
  }
}

function TuningRegion.contains(x, y)
  return (x >= 1 and x <= 4 and y == 2)
end

function TuningRegion.draw(layers)
  -- Determine brightness based on whether tuning section is selected
  local brightness = (_seeker.ui_state.get_current_section() == "TUNING") and 
    GridConstants.BRIGHTNESS.HIGH or 
    GridConstants.BRIGHTNESS.LOW
  
  -- Draw octave buttons
  layers.ui[TuningRegion.layout.octave.decrease.x][TuningRegion.layout.octave.decrease.y] = brightness - 2
  layers.ui[TuningRegion.layout.octave.increase.x][TuningRegion.layout.octave.increase.y] = brightness + 2
  
  -- Draw offset buttons
  layers.ui[TuningRegion.layout.offset.decrease.x][TuningRegion.layout.offset.decrease.y] = brightness - 2
  layers.ui[TuningRegion.layout.offset.increase.x][TuningRegion.layout.offset.increase.y] = brightness + 2
end

function TuningRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local focused_lane = _seeker.ui_state.get_focused_lane()
    
    -- Switch to tuning section
    _seeker.ui_state.set_current_section("TUNING")
    
    -- Handle octave controls
    if x == TuningRegion.layout.octave.decrease.x then
      local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.max(1, current - 1))
    elseif x == TuningRegion.layout.octave.increase.x then
      local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.min(7, current + 1))
    
    -- Handle offset controls
    elseif x == TuningRegion.layout.offset.decrease.x then
      local current = params:get("lane_" .. focused_lane .. "_grid_offset")
      params:set("lane_" .. focused_lane .. "_grid_offset", math.max(-8, current - 1))
    elseif x == TuningRegion.layout.offset.increase.x then
      local current = params:get("lane_" .. focused_lane .. "_grid_offset")
      params:set("lane_" .. focused_lane .. "_grid_offset", math.min(8, current + 1))
    end
    
    -- Trigger UI updates
    _seeker.screen_ui.set_needs_redraw()
    _seeker.grid_ui.redraw()
  end
end

return TuningRegion 
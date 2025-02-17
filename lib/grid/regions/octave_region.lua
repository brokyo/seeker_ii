-- octave_region.lua
local GridConstants = include("lib/grid_constants")

local OctaveRegion = {}

OctaveRegion.layout = {
  octave = {
    decrease = {x = 1, y = 5},
    increase = {x = 2, y = 5}
  },
  offset = {
    decrease = {x = 3, y = 5},
    increase = {x = 4, y = 5}
  }
}

function OctaveRegion.contains(x, y)
  return (x >= 1 and x <= 4 and y == 5)  -- All controls are on row 5
end

function OctaveRegion.draw(layers)
  -- Determine brightness based on whether octave section is selected
  local brightness = (_seeker.ui_state.get_current_section() == "OCTAVE") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  
  -- Draw octave buttons
  layers.ui[OctaveRegion.layout.octave.decrease.x][OctaveRegion.layout.octave.decrease.y] = brightness
  layers.ui[OctaveRegion.layout.octave.increase.x][OctaveRegion.layout.octave.increase.y] = brightness
  
  -- Draw offset buttons
  layers.ui[OctaveRegion.layout.offset.decrease.x][OctaveRegion.layout.offset.decrease.y] = brightness
  layers.ui[OctaveRegion.layout.offset.increase.x][OctaveRegion.layout.offset.increase.y] = brightness
end

function OctaveRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local focused_lane = _seeker.ui_state.get_focused_lane()
    
    -- Switch to octave section
    _seeker.ui_state.set_current_section("OCTAVE")
    
    -- Handle octave controls
    if x == OctaveRegion.layout.octave.decrease.x then
      local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.max(1, current - 1))
    elseif x == OctaveRegion.layout.octave.increase.x then
      local current = params:get("lane_" .. focused_lane .. "_keyboard_octave")
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.min(7, current + 1))
    
    -- Handle offset controls
    elseif x == OctaveRegion.layout.offset.decrease.x then
      local current = params:get("lane_" .. focused_lane .. "_grid_offset")
      params:set("lane_" .. focused_lane .. "_grid_offset", math.max(-8, current - 1))
    elseif x == OctaveRegion.layout.offset.increase.x then
      local current = params:get("lane_" .. focused_lane .. "_grid_offset")
      params:set("lane_" .. focused_lane .. "_grid_offset", math.min(8, current + 1))
    end
    
    -- Trigger UI updates
    _seeker.screen_ui.set_needs_redraw()
    _seeker.grid_ui.redraw()
  end
end

return OctaveRegion 
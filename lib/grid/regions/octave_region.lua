-- octave_region.lua
local GridConstants = include("lib/grid_constants")

local OctaveRegion = {}

OctaveRegion.layout = {
  decrease = {x = 1, y = 5},
  increase = {x = 2, y = 5}
}

function OctaveRegion.contains(x, y)
  return (x == OctaveRegion.layout.decrease.x and y == OctaveRegion.layout.decrease.y) or
         (x == OctaveRegion.layout.increase.x and y == OctaveRegion.layout.increase.y)
end

function OctaveRegion.draw(layers)
  -- Determine brightness based on whether octave section is selected
  local brightness = (_seeker.ui_state.get_current_section() == "OCTAVE") and 
    GridConstants.BRIGHTNESS.UI.FOCUSED or 
    GridConstants.BRIGHTNESS.UI.NORMAL
  
  -- Draw decrease button
  layers.ui[OctaveRegion.layout.decrease.x][OctaveRegion.layout.decrease.y] = brightness
  
  -- Draw increase button
  layers.ui[OctaveRegion.layout.increase.x][OctaveRegion.layout.increase.y] = brightness
end

function OctaveRegion.handle_key(x, y, z)
  if z == 1 then -- Only handle key down
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local current_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
    
    -- Switch to octave section
    _seeker.ui_state.set_current_section("OCTAVE")
    
    if x == OctaveRegion.layout.decrease.x then
      -- Decrease octave (minimum is 1)
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.max(1, current_octave - 1))
      -- Trigger UI updates
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    elseif x == OctaveRegion.layout.increase.x then
      -- Increase octave (maximum is 7)
      params:set("lane_" .. focused_lane .. "_keyboard_octave", math.min(7, current_octave + 1))
      -- Trigger UI updates
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end
end

return OctaveRegion 
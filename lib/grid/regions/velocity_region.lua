-- velocity_region.lua
-- Four velocity levels (pp, mp, f, ff) in bottom row

local GridConstants = include("lib/grid_constants")

local VelocityRegion = {}

VelocityRegion.layout = {
  x = 1,
  y = 3,
  width = 4,
  height = 1
}

-- Velocity mapping for each button (pp, mp, f, ff)
VelocityRegion.velocity_levels = {40, 70, 100, 127}

function VelocityRegion.contains(x, y)
  return x >= VelocityRegion.layout.x and 
         x < VelocityRegion.layout.x + VelocityRegion.layout.width and 
         y == VelocityRegion.layout.y
end

function VelocityRegion.draw(layers)
  local is_velocity_section = (_seeker.ui_state.get_current_section() == "VELOCITY")
  
  for i = 0, VelocityRegion.layout.width - 1 do
    local x = VelocityRegion.layout.x + i
    local is_selected_value = (i == _seeker.velocity - 1)
    local brightness = GridConstants.BRIGHTNESS.UI.NORMAL
    
    if is_velocity_section then
      if is_selected_value then
        brightness = GridConstants.BRIGHTNESS.FULL
      else
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      end
    else
      if is_selected_value then
        brightness = GridConstants.BRIGHTNESS.HIGH
      else
        brightness = GridConstants.BRIGHTNESS.LOW
      end
    end
    
    layers.ui[x][VelocityRegion.layout.y] = brightness
  end
end

function VelocityRegion.handle_key(x, y, z)
  if z == 1 then
    -- Switch to velocity section
    _seeker.ui_state.set_current_section("VELOCITY")
    
    _seeker.velocity = (x - VelocityRegion.layout.x) + 1
    
    -- Trigger UI updates
    _seeker.screen_ui.set_needs_redraw()
    _seeker.grid_ui.redraw()
  end
end

function VelocityRegion.get_current_velocity()
  return VelocityRegion.velocity_levels[_seeker.velocity]
end

return VelocityRegion 
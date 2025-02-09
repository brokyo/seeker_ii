-- velocity_region.lua
-- Four velocity levels (pp, mp, f, ff) in bottom row

local GridConstants = include("lib/grid_constants")

local VelocityRegion = {}

VelocityRegion.layout = {
  x = 1,
  y = 7,
  width = 4,
  height = 1
}

-- Velocity mapping for each button (pp, mp, f, ff)
VelocityRegion.velocity_levels = {40, 70, 100, 127}

-- State
local current_idx = 3  -- Default to f

function VelocityRegion.contains(x, y)
  return x >= VelocityRegion.layout.x and 
         x < VelocityRegion.layout.x + VelocityRegion.layout.width and 
         y == VelocityRegion.layout.y
end

function VelocityRegion.draw(layers)
  for i = 0, VelocityRegion.layout.width - 1 do
    local x = VelocityRegion.layout.x + i
    local brightness = (i == current_idx - 1) and 
      GridConstants.BRIGHTNESS.UI.FOCUSED or 
      GridConstants.BRIGHTNESS.UI.NORMAL
    layers.ui[x][VelocityRegion.layout.y] = brightness
  end
end

function VelocityRegion.handle_key(x, y, z)
  if z == 1 then
    current_idx = (x - VelocityRegion.layout.x) + 1
  end
end

function VelocityRegion.get_current_velocity()
  return VelocityRegion.velocity_levels[current_idx]
end

return VelocityRegion 
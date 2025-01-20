-- grid_animations.lua
-- Handles visual animations for the grid
--------------------------------------------------

local GridAnimations = {}

local BRIGHTNESS = {
  high = 2,  -- Reduced overall brightness
  low = 0
}

--------------------------------------------------
-- Animation State
--------------------------------------------------

local state = {
  grid = nil,
  points = {}  -- Store state for each LED
}

-- Initialize a point with random timing
local function init_point()
  return {
    phase = math.random() * 2 * math.pi,
    speed = 0.002 + (math.random() * 0.002),  -- Slightly different speeds
    brightness = 0
  }
end

-- Get point key
local function point_key(x, y)
  return string.format("%d,%d", x, y)
end

-- Update the animation
local function update_points()
  if not state.grid then return end
  
  -- Draw all points with individual movement
  for x = 1, 16 do
    for y = 1, 8 do
      local key = point_key(x, y)
      
      -- Initialize point if needed
      if not state.points[key] then
        state.points[key] = init_point()
      end
      
      local point = state.points[key]
      
      -- Update phase
      point.phase = (point.phase + point.speed) % (2 * math.pi)
      
      -- Calculate brightness with gentle sine wave
      local base = (math.sin(point.phase) + 1) / 2
      local brightness = base * BRIGHTNESS.high
      
      -- Apply gradient from edges to center
      local center_distance = math.abs(x - 8.5) / 7.5
      local dimming = 0.2 + (center_distance * 0.8)
      brightness = brightness * dimming
      
      -- Randomly reset some points
      if math.random() < 0.0001 then  -- Very occasional reset
        state.points[key] = init_point()
      end
      
      -- Draw LED
      state.grid:led(x, y, math.floor(brightness))
    end
  end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function GridAnimations.init(grid_device)
  state.grid = grid_device
  state.points = {}  -- Clear any existing points
end

function GridAnimations.update()
  if state.grid then
    update_points()
  end
end

function GridAnimations.cleanup()
  state.points = {}
end

return GridAnimations 
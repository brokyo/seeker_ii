-- grid_animations.lua
-- Handles visual animations for the grid
--------------------------------------------------

local GridAnimations = {}

local BRIGHTNESS = {
  high = 8,  -- Full brightness range
  low = 0
}

--------------------------------------------------
-- Animation State
--------------------------------------------------

local state = {
  grid = nil,
  points = {},  -- Store state for each LED
  trails = {},  -- Store fading note trails
}

-- Initialize a point with random timing
local function init_point()
  return {
    phase = math.random() * 2 * math.pi,
    speed = 0.01 + (math.random() * 0.02),  -- Faster, more varied speeds
    brightness = 0
  }
end

-- Get point key
local function point_key(x, y)
  return string.format("%d,%d", x, y)
end

-- Add a note trail
function GridAnimations.add_trail(x, y)
  local key = point_key(x, y)
  state.trails[key] = {
    brightness = BRIGHTNESS.high,
    decay = 0.8  -- Decay factor per frame
  }
end

-- Remove a note trail
function GridAnimations.remove_trail(x, y)
  local key = point_key(x, y)
  state.trails[key] = nil
end

-- Update the animation
local function update_points()
  -- Update trails first
  for key, trail in pairs(state.trails) do
    trail.brightness = trail.brightness * trail.decay
    if trail.brightness < 0.5 then
      state.trails[key] = nil
    end
  end

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
      
      -- Calculate brightness with full range
      local base = (math.sin(point.phase) + 1) / 2
      local brightness = base * BRIGHTNESS.high
      
      -- Apply gradient from edges to center
      local center_distance = math.abs(x - 6.5) / 7.5
      local dimming = 0.15 + (center_distance * 0.85)  -- More contrast
      brightness = brightness * dimming

      -- Add trail brightness if exists
      if state.trails[key] then
        brightness = math.max(brightness, state.trails[key].brightness)
      end
      
      -- Draw LED with more granular brightness
      state.grid:led(x, y, math.floor(brightness))
    end
  end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function GridAnimations.init(grid_device)
  state.grid = grid_device
  state.points = {} 
  state.trails = {}
end

function GridAnimations.update()
  if state.grid then
    update_points()
  end
end

function GridAnimations.cleanup()
  state.points = {}
  state.trails = {}
end

return GridAnimations 
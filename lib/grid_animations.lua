-- grid_animations.lua
-- Handles visual animations for the grid
--------------------------------------------------

local GridConstants = include('lib/grid_constants')
local GridLayers = include("lib/grid_layers")
local GridAnimations = {}

-- Use GridConstants brightness values as our range
-- but keep as local for quick access in tight animation loops
local BRIGHTNESS = {
  high = GridConstants.BRIGHTNESS.MEDIUM,  -- Using MEDIUM for background animations to leave headroom for UI/response
  low = GridConstants.BRIGHTNESS.OFF
}

--------------------------------------------------
-- Animation State
--------------------------------------------------

local state = {
  points = {}  -- Store state for each LED
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

-- Update the background animation layer
function GridAnimations.update_background(background_layer)
  -- Draw all points with individual movement
  for x = 1, GridConstants.GRID_WIDTH do
    for y = 1, GridConstants.GRID_HEIGHT do
      local key = point_key(x, y)
      
      -- Initialize point if needed
      if not state.points[key] then
        state.points[key] = init_point()
      end
      
      local point = state.points[key]
      
      -- Update phase
      point.phase = (point.phase + point.speed) % (2 * math.pi)
      
      -- Calculate brightness with full range (keeping floating point for smooth animation)
      local base = (math.sin(point.phase) + 1) / 2
      local brightness = base * BRIGHTNESS.high
      
      -- Apply gradient from edges to center
      local center_distance = math.abs(x - 6.5) / 7.5
      local dimming = 0.15 + (center_distance * 0.85)  -- More contrast
      brightness = brightness * dimming
  
      -- Set LED brightness in background layer (floor only at final output)
      GridLayers.set(background_layer, x, y, math.floor(brightness))
    end
  end
end

-- Update trail animations in the response layer
function GridAnimations.update_trails(response_layer, trails)
  -- Update and draw provided trails
  for key, trail in pairs(trails) do
    -- Get target brightness (LOW) and current difference from it
    local target = GridConstants.BRIGHTNESS.LOW
    local diff = trail.brightness - target
    
    -- Update brightness, moving towards LOW
    trail.brightness = target + (diff * trail.decay)
    
    -- Calculate new difference after decay
    local new_diff = trail.brightness - target
    
    -- Remove trail if we're very close to LOW brightness
    if math.abs(new_diff) < 0.5 then
      trails[key] = nil
    else
      -- Parse x,y from key
      local x, y = string.match(key, "(%d+),(%d+)")
      x, y = tonumber(x), tonumber(y)
      -- Add trail brightness to response layer
      GridLayers.set(response_layer, x, y, math.floor(trail.brightness))
    end
  end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function GridAnimations.init()
  state.points = {}
end

function GridAnimations.cleanup()
  state.points = {}
end

return GridAnimations 
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
  points = {},  -- Store state for each LED
  keyboard_outline = {
    phase = 0,
    active = false
  }
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

-- Draw keyboard outline during recording or count-in
function GridAnimations.update_keyboard_outline(response_layer, layout, motif_recorder)
  if not (motif_recorder.is_recording or motif_recorder.is_counting_in) then
    state.keyboard_outline.active = false
    return
  end
  
  -- Activate outline animation if not already active
  state.keyboard_outline.active = true
  
  local max_brightness = GridConstants.BRIGHTNESS.LOW
  local current_beat = clock.get_beats()
  local beat_in_bar = current_beat % 4
  local beat_phase = current_beat % 1  -- Phase within current quarter note
  
  -- Base brightness calculation - flash on quarter notes
  local brightness = 0
  if beat_phase < 0.1 then
    -- Flash on quarter note
    brightness = math.floor(max_brightness * 0.8)
    -- Extra bright on downbeat (start of bar)
    if beat_in_bar < 0.1 then
      brightness = math.floor(max_brightness)
    end
  else
    -- Gentler decay between beats
    brightness = math.floor(max_brightness * 0.6 * math.sqrt(1 - beat_phase))
  end

  -- Boost brightness during count-in
  if motif_recorder.is_counting_in then
    brightness = math.floor(brightness * 1.2)  -- 20% brighter during count-in
  end
  
  -- Draw outline rectangle
  local x1 = layout.keyboard.upper_left_x - 1
  local y1 = layout.keyboard.upper_left_y - 1
  local x2 = x1 + layout.keyboard.width + 1
  local y2 = y1 + layout.keyboard.height + 1
  
  -- Draw horizontal lines
  for x = x1, x2 do
    GridLayers.set(response_layer, x, y1, brightness)
    GridLayers.set(response_layer, x, y2, brightness)
  end
  
  -- Draw vertical lines
  for y = y1, y2 do
    GridLayers.set(response_layer, x1, y, brightness)
    GridLayers.set(response_layer, x2, y, brightness)
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
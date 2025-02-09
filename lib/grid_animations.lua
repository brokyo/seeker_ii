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
    active = false,
    -- Animation configuration
    config = {
      attack_time = 0.1,        -- How long the initial flash lasts (in beats)
      inactive_brightness = 0.15, -- Brightness of inactive edges (0-1)
      rotation = 1,             -- 1 for clockwise, -1 for counter-clockwise
      edge_order = {0, 1, 2, 3},-- Order of edge activation (0=top, 1=right, 2=bottom, 3=left)
      decay_curve = 1,          -- Power of decay curve (1=linear, 2=quadratic, etc)
    }
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

-- Draw keyboard outline during recording
function GridAnimations.update_keyboard_outline(response_layer, layout, motif_recorder)
  if not motif_recorder.is_recording then
    state.keyboard_outline.active = false
    return
  end
  
  -- Activate outline animation if not already active
  state.keyboard_outline.active = true
  
  local max_brightness = GridConstants.BRIGHTNESS.LOW
  local current_beat = clock.get_beats()
  local config = state.keyboard_outline.config
  
  -- Calculate beat position based on rotation direction
  local beat_position = config.rotation > 0 
    and (current_beat % 4)     -- Clockwise
    or (3 - (current_beat % 4)) -- Counter-clockwise
  local beat_phase = current_beat % 1
  
  -- Draw outline rectangle
  local x1 = layout.keyboard.upper_left_x - 1
  local y1 = layout.keyboard.upper_left_y - 1
  local x2 = x1 + layout.keyboard.width + 1
  local y2 = y1 + layout.keyboard.height + 1
  
  -- Function to get brightness for current edge
  local function get_edge_brightness(edge_num, phase)
    -- Map edge number through edge_order configuration
    local mapped_edge = config.edge_order[edge_num + 1] -- +1 for Lua 1-based indexing
    local is_active_edge = math.floor(beat_position) == mapped_edge
    
    if is_active_edge then
      -- Active edge: fade in/out during its beat
      if phase < config.attack_time then
        -- Quick attack
        return max_brightness
      else
        -- Configurable decay curve
        local decay_progress = (phase - config.attack_time) / (1 - config.attack_time)
        return math.floor(max_brightness * (1 - math.pow(decay_progress, config.decay_curve)))
      end
    else
      -- Inactive edge: configurable dim brightness
      return math.floor(max_brightness * config.inactive_brightness)
    end
  end
  
  -- Draw horizontal lines
  for x = x1, x2 do
    -- Top edge (beat 0)
    GridLayers.set(response_layer, x, y1, get_edge_brightness(0, beat_phase))
    -- Bottom edge (beat 2)
    GridLayers.set(response_layer, x, y2, get_edge_brightness(2, beat_phase))
  end
  
  -- Draw vertical lines
  for y = y1, y2 do
    -- Right edge (beat 1)
    GridLayers.set(response_layer, x2, y, get_edge_brightness(1, beat_phase))
    -- Left edge (beat 3)
    GridLayers.set(response_layer, x1, y, get_edge_brightness(3, beat_phase))
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

-- Configuration methods
function GridAnimations.set_outline_config(config)
  for k, v in pairs(config) do
    state.keyboard_outline.config[k] = v
  end
end

function GridAnimations.get_outline_config()
  return state.keyboard_outline.config
end

return GridAnimations 
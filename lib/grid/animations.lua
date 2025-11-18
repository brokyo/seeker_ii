-- grid_animations.lua
-- Handles visual animations for the grid
--------------------------------------------------

local GridConstants = include('lib/grid/constants')
local GridLayers = include("lib/grid/layers")
local GridAnimations = {}

-- Use GridConstants brightness values as our range
-- but keep as local for quick access in tight animation loops
local BRIGHTNESS = {
  high = function() return params:get("background_brightness") end,  -- Use param value
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
  },
  generate_flash = {
    active = false,
    start_time = 0,
    duration = 0.2  -- Duration of flash in seconds
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
      local brightness = base * BRIGHTNESS.high()
      
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
    
    -- Only decay if this isn't a newly activated trail
    if not trail.is_new then
      -- Update brightness, moving towards LOW
      trail.brightness = target + (diff * trail.decay)
    end
    trail.is_new = false
    
    -- Calculate new difference after decay
    local new_diff = trail.brightness - target
    
    -- Remove trail if we're very close to LOW brightness
    if math.abs(new_diff) < 0.5 then
      trails[key] = nil
    else
      -- Parse x,y from key
      local x, y = string.match(key, "(%d+),(%d+)")
      x, y = tonumber(x), tonumber(y)
      
      -- Get current brightness in response layer
      local current = GridLayers.get(response_layer, x, y) or 0
      
      -- Use maximum of current and trail brightness
      local new_brightness = math.max(current, math.floor(trail.brightness))
      GridLayers.set(response_layer, x, y, new_brightness)
    end
  end
end

-- Draw keyboard outline during recording
function GridAnimations.update_keyboard_outline(response_layer, layout, motif_recorder)
  -- Handle generate flash animation first
  if state.generate_flash.active then
    local elapsed = util.time() - state.generate_flash.start_time
    if elapsed > state.generate_flash.duration then
      state.generate_flash.active = false
    else
      -- Calculate flash brightness (starts bright, fades out)
      local progress = elapsed / state.generate_flash.duration
      local brightness = math.floor(GridConstants.BRIGHTNESS.HIGH * (1 - progress))
      
      -- Draw outline
      local x1 = layout.keyboard.upper_left_x - 1
      local x2 = x1 + layout.keyboard.width + 1
      local y1 = layout.keyboard.upper_left_y - 1
      local y2 = y1 + layout.keyboard.height + 1
      
      -- Draw top and bottom
      for x = x1, x2 do
        GridLayers.set(response_layer, x, y1, brightness)
        GridLayers.set(response_layer, x, y2, brightness)
      end
      -- Draw sides
      for y = y1, y2 do
        GridLayers.set(response_layer, x1, y, brightness)
        GridLayers.set(response_layer, x2, y, brightness)
      end
      return
    end
  end

  -- Don't show recording animation - we're handling this in RecRegion now
  if motif_recorder.is_recording then
    state.keyboard_outline.active = false
    return
  end

  -- Continue with normal recording outline if not flashing
  if not motif_recorder.is_recording then
    state.keyboard_outline.active = false
    return
  end
end

-- Trigger a keyboard flash animation
function GridAnimations.flash_keyboard()
  state.generate_flash.active = true
  state.generate_flash.start_time = util.time()
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
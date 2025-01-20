-- grid_animations.lua
-- Handles visual animations for the grid
--------------------------------------------------

local GridAnimations = {}

local BRIGHTNESS = {
  high = 4,  -- Full brightness range
  low = 0
}

--------------------------------------------------
-- Animation State
--------------------------------------------------

local state = {
  grid = nil,
  points = {},  -- Store state for each LED
  -- FPS tracking
  frame_count = 0,
  last_time = 0,
  current_fps = 0,
  -- Record pulse state
  record_pulse = false,
  last_pulse_time = 0
}

-- Track FPS
local function update_fps()
  state.frame_count = state.frame_count + 1
  local current_time = util.time()
  local elapsed = current_time - state.last_time
  
  -- Update FPS every second
  if elapsed >= 1 then
    state.current_fps = state.frame_count / elapsed
    state.frame_count = 0
    state.last_time = current_time
  end
end

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

-- Update the animation
local function update_points()
  if not state.grid then return end
  
  update_fps()  -- Track frame rate
  
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
      local center_distance = math.abs(x - 8.5) / 7.5
      local dimming = 0.15 + (center_distance * 0.85)  -- More contrast
      brightness = brightness * dimming
      
      -- Randomly reset some points
      if math.random() < 0.002 then
        state.points[key] = init_point()
      end
      
      -- Draw LED with more granular brightness
      state.grid:led(x, y, math.floor(brightness))
    end
  end
end

-- Update record pulse based on BPM
local function update_record_pulse()
  if not _seeker or not _seeker.clock then return end
  
  local current_time = util.time()
  local bpm = params:get("clock_tempo")
  local pulse_interval = 60 / bpm  -- Convert BPM to seconds
  
  if current_time - state.last_pulse_time >= pulse_interval then
    state.record_pulse = not state.record_pulse
    state.last_pulse_time = current_time
  end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function GridAnimations.init(grid_device)
  state.grid = grid_device
  state.points = {}  -- Clear any existing points
  state.last_time = util.time()  -- Initialize FPS timer
end

function GridAnimations.update()
  if state.grid then
    update_points()
    update_record_pulse()
  end
end

function GridAnimations.cleanup()
  state.points = {}
end

function GridAnimations.get_record_pulse()
  return state.record_pulse
end

return GridAnimations 
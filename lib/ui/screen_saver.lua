-- screen_saver.lua
local ScreenSaver = {}

ScreenSaver.state = {
  is_active = false,
  timeout_seconds = 90,
  lines = {},
  -- Scan line configuration
  config = {
    num_lines = 4,
    min_speed = 0.3,
    max_speed = 0.8,
    line_width = 1,
    max_brightness = 12,
    fade_length = 6,
    wave_amplitude = 4,
    wave_frequency = 0.5,
    line_resolution = 4,
    fps = 30
  }
}

-- Initialize a scan line
local function init_line(force_direction)
  local config = ScreenSaver.state.config
  local going_up = force_direction or (math.random() > 0.5)
  
  return {
    y = going_up and 64 or 0,  -- Start at top or bottom
    going_up = going_up,
    speed = config.min_speed + (math.random() * (config.max_speed - config.min_speed)),
    phase = math.random() * 2 * math.pi,  -- Random starting phase for wave
    wave_freq = config.wave_frequency * (0.8 + math.random() * 0.4)  -- Slightly varied frequencies
  }
end

function ScreenSaver.init()
  ScreenSaver.state.lines = {}
  
  -- Initialize lines, alternating directions
  for i = 1, ScreenSaver.state.config.num_lines do
    table.insert(ScreenSaver.state.lines, init_line(i % 2 == 0))
  end
  
  return ScreenSaver
end

function ScreenSaver.check_timeout()
  local time_since_last_action = util.time() - _seeker.ui_state.state.last_action_time
  local should_be_active = time_since_last_action > ScreenSaver.state.timeout_seconds
  
  -- Update active state if it changed
  if should_be_active ~= ScreenSaver.state.is_active then
    ScreenSaver.state.is_active = should_be_active
  end
  
  return ScreenSaver.state.is_active
end

function ScreenSaver.draw()
  screen.clear()
  
  -- Draw scan lines
  for _, line in ipairs(ScreenSaver.state.lines) do
    -- Update position
    local delta = line.going_up and -line.speed or line.speed
    line.y = line.y + delta
    line.phase = (line.phase + line.wave_freq) % (2 * math.pi)
    
    -- Reset if off screen
    if (line.going_up and line.y < -ScreenSaver.state.config.fade_length) or 
       (not line.going_up and line.y > 64 + ScreenSaver.state.config.fade_length) then
      local new_line = init_line(line.going_up)  -- Keep same direction
      for k,v in pairs(new_line) do line[k] = v end
    end
    
    -- Draw main line and fade trail
    for i = 0, ScreenSaver.state.config.fade_length do
      local fade_y = line.going_up and line.y + i or line.y - i
      
      -- Only draw if the line is visible on screen
      if fade_y >= 0 and fade_y <= 64 then
        local wave_offset = math.sin(line.phase + (i * 0.2)) * ScreenSaver.state.config.wave_amplitude
        
        -- Calculate brightness based on fade
        local brightness = math.floor(ScreenSaver.state.config.max_brightness * 
          (1 - (i / ScreenSaver.state.config.fade_length)))
        
        screen.level(brightness)
        screen.move(0, fade_y)
        
        for x = 0, 128, ScreenSaver.state.config.line_resolution do
          local y_offset = wave_offset * math.sin(x * 0.05 + line.phase)
          screen.line(x, fade_y + y_offset)
        end
        screen.stroke()
      end
    end
  end
  
  -- Draw black background rectangle for blinken lights
  local SCREEN_WIDTH = 128
  local SCREEN_HEIGHT = 64
  local CENTER_Y = SCREEN_HEIGHT / 2
  local CENTER_X = SCREEN_WIDTH / 2
  local LIGHT_SPACING_Y = 6
  local LIGHT_SPACING_X = 8
  local TOTAL_HEIGHT = (8 * LIGHT_SPACING_Y)
  local START_Y = CENTER_Y - (TOTAL_HEIGHT / 2) + 2
  local LANE_LIGHT_X = CENTER_X - 23
  local STAGE_START_X = CENTER_X - 12
  
  screen.level(0)
  local PADDING = 4
  -- Calculate total width needed for all lights
  local total_width = (STAGE_START_X - LANE_LIGHT_X) +  -- Space between lane and first stage
                     (4 * LIGHT_SPACING_X)              -- Width for all 4 stage lights
  
  screen.rect(
    LANE_LIGHT_X - PADDING,
    START_Y - PADDING,
    total_width + (2 * PADDING),
    TOTAL_HEIGHT + (2 * PADDING)
  )
  screen.fill()
  
  local lights = {}
  -- Reuse the same constants for light positioning
  local START_Y = CENTER_Y - (TOTAL_HEIGHT / 2) - 1  -- Keep consistent with rectangle
  local LANE_LIGHT_X = CENTER_X - 20  -- Keep consistent with rectangle
  local STAGE_START_X = CENTER_X - 8  -- Keep consistent with rectangle
  
  -- Lane status lights (centered)
  for lane_idx = 1, 8 do  -- Changed from 4 to 8
    local lane = _seeker.lanes[lane_idx]
    
    -- Lane activity light
    table.insert(lights, {
      x = LANE_LIGHT_X,
      y = START_Y + (lane_idx * LIGHT_SPACING_Y),
      is_active = lane.playing,
      speed = 0,
      base_level = 4,
      size = 2,
      type = "lane",
      lane_idx = lane_idx
    })
    
    -- Stage status lights for this lane
    for stage_idx = 1, 4 do
      local stage = lane.stages[stage_idx]
      local is_stage_active = lane.playing and stage_idx == lane.current_stage_index
      local has_active_notes = stage and stage.active_notes and #stage.active_notes > 0
      
      table.insert(lights, {
        x = STAGE_START_X + ((stage_idx - 1) * LIGHT_SPACING_X),
        y = START_Y + (lane_idx * LIGHT_SPACING_Y),
        is_active = is_stage_active or has_active_notes,
        speed = has_active_notes and 8 or 0,
        base_level = is_stage_active and 4 or 2,  -- Simplified base levels
        size = 1.75,
        type = "stage",
        lane_idx = lane_idx,
        stage_idx = stage_idx
      })
    end
  end
  
  -- Draw all lights
  for _, light in ipairs(lights) do
    local brightness = light.base_level
    
    if light.is_active then
      if light.speed > 0 then
        local activity = (util.time() * light.speed) % 1
        if activity < 0.1 then
          brightness = 15
        elseif activity < 0.2 then
          brightness = math.floor((0.2 - activity) * 150)
        end
      else
        brightness = 12
      end
    end

    -- Check if this stage has any active notes
    if light.type == "stage" then
      local lane = _seeker.lanes[light.lane_idx]
      if lane and lane.active_notes and next(lane.active_notes) and 
         lane.current_stage_index == light.stage_idx then
        -- Create breathing animation using sine wave
        local breath = math.sin(util.time() * 3) * 0.5 + 0.5  -- Oscillate between 0 and 1
        brightness = math.floor(util.linlin(0, 1, light.base_level + 2, 15, breath))  -- Map to brightness range and ensure integer
      end
    end
    
    screen.level(brightness)
    screen.circle(light.x, light.y, light.size)
    screen.fill()
  end
  
  screen.update()
end

return ScreenSaver 
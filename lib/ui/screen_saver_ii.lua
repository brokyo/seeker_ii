local ScreenSaver = {}

ScreenSaver.state = {
  is_active = false,
  timeout_seconds = 4
}

function ScreenSaver.init()
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

-- Draw a single lane's visualization
local function draw_lane(lane_index, lane, x, y, width, height)
    -- Draw continuous stage line if the lane has a motif
  local center_y = y + height/2
  
  if not lane.motif or #lane.motif.events == 0 then    
    screen.level(1)
    screen.move(x, center_y)
    screen.line(x + width, center_y)
    screen.stroke()
  end
    
  -- Highlight active stage line
  if lane.playing then
    -- Draw stage blocks (4 equal sections) - as a centered line
    local block_width = width / 4
    local active_stage = lane.current_stage_index or 1
    local active_x = x + ((active_stage - 1) * block_width)
    
    screen.level(2)
    screen.move(active_x, center_y)
    screen.line(active_x + block_width, center_y)
    screen.stroke()
  end
  
  -- Draw note events
  local duration = lane.motif:get_duration()
  
  -- First pass: Draw all note positions dimly
  screen.level(1)
  for _, event in ipairs(lane.motif.events) do
    if event.type == "note_on" then
      if event.time and duration and duration > 0 then
        local event_x = x + (event.time / duration * width)
        -- Draw small circle for each note
        screen.circle(event_x, y + height/2, 1)
        screen.fill()
      end
    end
  end
  
  if lane.playing then
    -- Calculate pulse for animation - slower, more organic pulse
    local pulse = math.sin(clock.get_beats() * 4) * 0.5 + 0.5  -- Smooth pulse between 0 and 1
    
    -- Second pass: Highlight all instances of currently playing notes
    for note, active_info in pairs(lane.active_notes) do
      for _, event in ipairs(lane.motif.events) do
        if event.type == "note_on" and event.note == active_info.original_note then
          local event_x = x + (event.time / duration * width)
          -- Illuminate other instances of this note
          screen.level(4)
          screen.circle(event_x, y + height/2, 1.5)
          screen.fill()
        end
      end
    end
    
    -- Third pass: Draw larger circle for currently playing note
    for note, active_info in pairs(lane.active_notes) do
      if active_info.event_index and active_info.event_index <= #lane.motif.events then
        local event = lane.motif.events[active_info.event_index]
        if event and event.type == "note_on" then
          local event_x = x + (event.time / duration * width)
          
          -- Draw expanded circle for the active note
          local base_brightness = math.floor(active_info.velocity / 127 * 12)
          local pulse_brightness = math.floor(pulse * 3)
          screen.level(base_brightness + pulse_brightness)
          
          local radius = 2 + (active_info.velocity / 127 * 2)
          screen.circle(event_x, y + height/2, radius)
          screen.fill()
        end
      end
    end
  end
end

function ScreenSaver.draw()
  screen.clear()
  
  -- Constants for layout - now showing fewer lanes with more space
  local MARGIN = 1
  local TOTAL_HEIGHT = 64 - (MARGIN * 2)
  local LANES_PER_PAGE = 8  -- Show fewer lanes
  local LANE_HEIGHT = TOTAL_HEIGHT / LANES_PER_PAGE
  local LANE_WIDTH = 120  -- Slightly more horizontal margin
  local START_X = (128 - LANE_WIDTH) / 2
  
  -- Draw visible lanes
  for i = 1, LANES_PER_PAGE do
    local y = MARGIN + (i - 1) * LANE_HEIGHT
    local lane = _seeker.lanes[i]
    draw_lane(i, lane, START_X, y, LANE_WIDTH, LANE_HEIGHT - 2)
  end
  
  screen.update()
end

return ScreenSaver
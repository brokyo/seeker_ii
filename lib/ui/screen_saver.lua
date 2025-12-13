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
    fade_length = 4,
    wave_amplitude = 4,
    wave_frequency = 0.5,
    line_resolution = 8,
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
  -- Check if screensaver is enabled
  if params:get("screensaver_enabled") == 0 then
    ScreenSaver.state.is_active = false
    return false
  end

  local time_since_last_action = util.time() - _seeker.ui_state.state.last_action_time
  local should_be_active = time_since_last_action > ScreenSaver.state.timeout_seconds

  -- Update active state if it changed
  if should_be_active ~= ScreenSaver.state.is_active then
    ScreenSaver.state.is_active = should_be_active

    -- Dismiss any active modal when screensaver activates
    if should_be_active and _seeker.modal and _seeker.modal.is_active() then
      _seeker.modal.dismiss()
    end
  end

  return ScreenSaver.state.is_active
end

-- Draw the screensaver background (scan lines and timelines) without screen.update()
function ScreenSaver._draw_background()
  -- Draw scan lines background
  for _, line in ipairs(ScreenSaver.state.lines) do
    -- Update position
    local delta = line.going_up and -line.speed or line.speed
    line.y = line.y + delta
    line.phase = (line.phase + line.wave_freq) % (2 * math.pi)

    -- Reset if off screen
    if (line.going_up and line.y < -ScreenSaver.state.config.fade_length) or
       (not line.going_up and line.y > 64 + ScreenSaver.state.config.fade_length) then
      local new_line = init_line(line.going_up)
      for k,v in pairs(new_line) do line[k] = v end
    end

    -- Draw main line and fade trail
    for i = 0, ScreenSaver.state.config.fade_length do
      local fade_y = line.going_up and line.y + i or line.y - i

      if fade_y >= 0 and fade_y <= 64 then
        local wave_offset = math.sin(line.phase + (i * 0.2)) * ScreenSaver.state.config.wave_amplitude
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

  -- Collect active lanes
  local active_lanes = {}
  for lane_idx = 1, _seeker.num_lanes do
    local lane = _seeker.lanes[lane_idx]
    if lane.motif and #lane.motif.events > 0 then
      table.insert(active_lanes, {idx = lane_idx, lane = lane})
    end
  end

  -- Only draw timelines if we have active lanes
  if #active_lanes > 0 then
    -- Layout constants
    local MARGIN_TOP = 8
    local MARGIN_BOTTOM = 8
    local MARGIN_LEFT = 12
    local MARGIN_RIGHT = 12
    local GAP = 4

    local available_height = 64 - MARGIN_TOP - MARGIN_BOTTOM
    local lane_height = math.floor((available_height - (GAP * (#active_lanes - 1))) / #active_lanes)
    local timeline_width = 128 - MARGIN_LEFT - MARGIN_RIGHT
    local use_piano_roll = #active_lanes < 5

    -- Draw each lane's timeline
    for i, active_lane in ipairs(active_lanes) do
      local lane = active_lane.lane
      local motif = lane.motif
      local y_pos = MARGIN_TOP + ((i - 1) * (lane_height + GAP))

      -- Get loop duration
      local loop_duration = motif:get_duration()

      -- Draw grey background for timeline
      screen.level(2)
      screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
      screen.fill()

      -- Draw timeline border
      screen.level(3)
      screen.rect(MARGIN_LEFT, y_pos, timeline_width, lane_height)
      screen.stroke()

      -- Draw stage indicator dots
      local num_stages = 4
      local dot_x = MARGIN_LEFT + 3
      local dot_spacing = (lane_height - 4) / (num_stages - 1)
      local current_stage = lane.current_stage_index or 1

      for stage = 1, num_stages do
        local dot_y = y_pos + 2 + ((stage - 1) * dot_spacing)
        local is_active = (stage == current_stage)
        screen.level(is_active and 15 or 3)
        screen.circle(dot_x, dot_y, 1)
        screen.fill()
      end

      -- Find max generation and note range for brightness scaling and piano roll
      local max_gen = 1
      local min_note = 127
      local max_note = 0
      for _, event in ipairs(motif.events) do
        if event.generation and event.generation > max_gen then
          max_gen = event.generation
        end
        if event.type == "note_on" then
          if event.note < min_note then min_note = event.note end
          if event.note > max_note then max_note = event.note end
        end
      end

      -- Match note_on with note_off events to show duration
      local note_pairs = {}
      for _, event in ipairs(motif.events) do
        if event.type == "note_on" then
          -- Find matching note_off
          local note_off_time = nil
          for _, off_event in ipairs(motif.events) do
            if off_event.type == "note_off" and
               off_event.note == event.note and
               off_event.time > event.time then
              note_off_time = off_event.time
              break
            end
          end

          table.insert(note_pairs, {
            note = event.note,
            start_time = event.time,
            end_time = note_off_time or event.time,
            generation = event.generation or 1
          })
        end
      end

      -- Draw note events as horizontal bars
      for _, note_pair in ipairs(note_pairs) do
        local gen = note_pair.generation
        local brightness = 2 + math.floor((gen / max_gen) * 10)
        screen.level(brightness)

        local x_start = MARGIN_LEFT + (note_pair.start_time / loop_duration * timeline_width)
        local x_end = MARGIN_LEFT + (note_pair.end_time / loop_duration * timeline_width)

        if use_piano_roll and max_note > min_note then
          -- Map note pitch to Y position within lane
          local note_range = max_note - min_note
          local note_y_offset = ((note_pair.note - min_note) / note_range) * (lane_height - 2)
          local note_y = y_pos + lane_height - 1 - note_y_offset
          screen.move(x_start, note_y)
          screen.line(x_end, note_y)
          screen.stroke()
        else
          -- Simple vertical line at note start
          screen.move(x_start, y_pos)
          screen.line(x_start, y_pos + lane_height)
          screen.stroke()
        end
      end

      -- Draw playhead
      if lane.playing then
        local current_beat = clock.get_beats()
        local position = current_beat % loop_duration

        -- Use stage timing if available
        local current_stage = lane.stages[lane.current_stage_index]
        if current_stage and current_stage.last_start_time then
          local elapsed_time = current_beat - current_stage.last_start_time
          position = (elapsed_time * lane.speed) % loop_duration
        end

        local x_playhead = MARGIN_LEFT + (position / loop_duration * timeline_width)
        screen.level(15)
        screen.move(x_playhead, y_pos)
        screen.line(x_playhead, y_pos + lane_height)
        screen.stroke()
      end
    end
  end
end

-- Draw the complete screensaver (background + screen.update)
function ScreenSaver.draw()
  screen.clear()
  ScreenSaver._draw_background()
  screen.update()
end

return ScreenSaver 
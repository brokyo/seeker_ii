-- screen_saver.lua
-- Screensaver with idle timeout. Draws scan line animation as backdrop,
-- then dispatches to the current mode's screensaver (lane timelines,
-- CV monitor, etc).

local MusicScreensaver = include('lib/ui/music_screensaver')

local ScreenSaver = {}

ScreenSaver.state = {
  is_active = false,
  timeout_seconds = 90,
  lines = {},
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

local function init_line(force_direction)
  local config = ScreenSaver.state.config
  local going_up = force_direction or (math.random() > 0.5)

  return {
    y = going_up and 64 or 0,
    going_up = going_up,
    speed = config.min_speed + (math.random() * (config.max_speed - config.min_speed)),
    phase = math.random() * 2 * math.pi,
    wave_freq = config.wave_frequency * (0.8 + math.random() * 0.4)
  }
end

function ScreenSaver.init()
  ScreenSaver.state.lines = {}
  for i = 1, ScreenSaver.state.config.num_lines do
    table.insert(ScreenSaver.state.lines, init_line(i % 2 == 0))
  end
  return ScreenSaver
end

local function get_timeout_seconds()
  local timeout_values = {0, 5, 15, 30, 45, 60, 75, 90, 105, 120}
  local option = params:get("screensaver_timeout")
  return timeout_values[option] or 0
end

function ScreenSaver.check_timeout()
  local timeout_seconds = get_timeout_seconds()
  if timeout_seconds == 0 then
    ScreenSaver.state.is_active = false
    return false
  end

  if _seeker.modal and _seeker.modal.is_active() then
    ScreenSaver.state.is_active = false
    return false
  end

  if _seeker.hold_confirm and _seeker.hold_confirm.is_active() then
    ScreenSaver.state.is_active = false
    return false
  end

  -- Composer mode has its own live view and grid animations; screensaver would interrupt
  local current_section = _seeker.ui_state.get_current_section()
  if current_section and current_section:sub(1, 9) == "COMPOSER_" then
    ScreenSaver.state.is_active = false
    return false
  end

  -- Suppress screensaver when current section is in live view
  if _seeker.screen_ui then
    local section = _seeker.screen_ui.sections[current_section]
    if section and section.state and section.state.live_view then
      ScreenSaver.state.is_active = false
      return false
    end
  end

  local time_since_last_action = util.time() - _seeker.ui_state.state.last_action_time
  local should_be_active = time_since_last_action > timeout_seconds

  if should_be_active ~= ScreenSaver.state.is_active then
    ScreenSaver.state.is_active = should_be_active

    if should_be_active and _seeker.modal and _seeker.modal.is_active() then
      _seeker.modal.dismiss()
    end
  end

  return ScreenSaver.state.is_active
end

---------------------------------------------------------------
-- Scan line animation (backdrop for all screensaver modes)
---------------------------------------------------------------
function ScreenSaver._draw_scan_lines()
  for _, line in ipairs(ScreenSaver.state.lines) do
    local delta = line.going_up and -line.speed or line.speed
    line.y = line.y + delta
    line.phase = (line.phase + line.wave_freq) % (2 * math.pi)

    if (line.going_up and line.y < -ScreenSaver.state.config.fade_length) or
       (not line.going_up and line.y > 64 + ScreenSaver.state.config.fade_length) then
      local new_line = init_line(line.going_up)
      for k,v in pairs(new_line) do line[k] = v end
    end

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
end

---------------------------------------------------------------
-- Mode dispatch: _seeker object key for each non-music mode
---------------------------------------------------------------
local MODE_SEEKER_KEYS = {
  EURORACK_OUTPUT = "eurorack",
  WTAPE = "wtape",
  OSC_CONFIG = "osc",
  CONFIG = "config",
}

function ScreenSaver.draw()
  ScreenSaver._draw_scan_lines()

  local mode = _seeker.current_mode
  if mode == "music" then
    MusicScreensaver.draw()
  else
    local obj_key = MODE_SEEKER_KEYS[mode]
    local mode_obj = obj_key and _seeker[obj_key]
    if mode_obj and mode_obj.draw_screensaver then
      mode_obj.draw_screensaver()
    end
  end
end

return ScreenSaver

-- rec_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local RecRegion = setmetatable({}, Section)
RecRegion.__index = RecRegion

RecRegion.layout = {
  x = 3,
  y = 7,
  width = 1,
  height = 1
}

-- Add count display coordinates
RecRegion.count_display = {
  x_start = 7,
  x_end = 10,
  y = 1,
  pulse_duration = 0.2  -- Duration of pulse in seconds
}

-- Shared press state
RecRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function RecRegion.contains(x, y)
  return x == RecRegion.layout.x and y == RecRegion.layout.y
end

function RecRegion.draw(layers)
  -- Draw keyboard outline during long press
  if RecRegion:is_holding_long_press() then
    -- Top and bottom rows
    for x = 0, 5 do
      layers.response[6 + x][2] = GridConstants.BRIGHTNESS.HIGH
      layers.response[6 + x][7] = GridConstants.BRIGHTNESS.HIGH
    end
    -- Left and right columns
    for y = 0, 5 do
      layers.response[6][2 + y] = GridConstants.BRIGHTNESS.HIGH
      layers.response[11][2 + y] = GridConstants.BRIGHTNESS.HIGH
    end
  end

  -- Draw count display when recording
  if _seeker.motif_recorder.is_recording then
    local current_beat = math.floor(clock.get_beats()) % 4
    local beat_phase = clock.get_beats() % 1  -- How far we are into current beat (0-1)
    
    -- Set all count LEDs to medium brightness initially
    for x = RecRegion.count_display.x_start, RecRegion.count_display.x_end do
      layers.ui[x][RecRegion.count_display.y] = GridConstants.BRIGHTNESS.MEDIUM
    end
    
    -- Light up previous beats at medium brightness
    for x = RecRegion.count_display.x_start, RecRegion.count_display.x_start + current_beat - 1 do
      layers.ui[x][RecRegion.count_display.y] = GridConstants.BRIGHTNESS.MEDIUM
    end
    
    -- Make current beat pulse
    if current_beat >= 0 then
      local current_x = RecRegion.count_display.x_start + current_beat
      -- Pulse brightness starts at FULL and decays to HIGH over pulse_duration
      local pulse_progress = beat_phase / RecRegion.count_display.pulse_duration
      if pulse_progress < 1 then
        local pulse_brightness = util.linlin(0, 1, GridConstants.BRIGHTNESS.FULL, GridConstants.BRIGHTNESS.HIGH, pulse_progress)
        layers.ui[current_x][RecRegion.count_display.y] = math.floor(pulse_brightness)
      else
        layers.ui[current_x][RecRegion.count_display.y] = GridConstants.BRIGHTNESS.FULL
      end
    end
  end

  -- Draw region button
  local brightness
  if _seeker.ui_state.get_current_section() == "RECORDING" then
    if _seeker.motif_recorder.is_recording then
      brightness = GridConstants.BRIGHTNESS.FULL
    else
      brightness = GridConstants.BRIGHTNESS.FULL
    end
  elseif _seeker.ui_state.get_current_section() == "GENERATE" or
         _seeker.ui_state.get_current_section() == "MOTIF" or
         _seeker.ui_state.get_current_section() == "OVERDUB" then
    brightness = GridConstants.BRIGHTNESS.MEDIUM
  else
    brightness = GridConstants.BRIGHTNESS.LOW
  end
  
  layers.ui[RecRegion.layout.x][RecRegion.layout.y] = brightness
end

function RecRegion:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

function RecRegion:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

function RecRegion:is_holding_long_press()
  for key_id, press in pairs(self.press_state.pressed_keys) do
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD then
      return true
    end
  end
  return false
end

function RecRegion:is_long_press(key_id)
  local press = self.press_state.pressed_keys[key_id]
  if press then
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD and not press.long_press_triggered then
      press.long_press_triggered = true
      return true
    end
  end
  return false
end

function RecRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    RecRegion:start_press(key_id)
    _seeker.ui_state.set_current_section("RECORDING")
    _seeker.ui_state.set_long_press_state(true, "RECORDING")
    _seeker.screen_ui.set_needs_redraw()
  else -- Key released
    -- If already recording, stop on any release (short or long)
    if _seeker.motif_recorder.is_recording then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif = _seeker.motif_recorder:stop_recording()
      local lane = _seeker.lanes[focused_lane]
      lane:set_motif(motif)
      lane:play()  -- Start playing immediately after recording
      _seeker.screen_ui.set_needs_redraw()
    -- If not recording and it was a long press, start recording
    elseif RecRegion:is_long_press(key_id) then
      _seeker.motif_recorder:set_recording_mode(1)
      -- Clear the current motif from the focused lane
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]
      lane:clear()  -- Assuming there's a clear_motif() method
      -- Start new recording
      _seeker.motif_recorder:start_recording(nil)
      _seeker.screen_ui.set_needs_redraw()
    end
    
    -- Always clear long press state on release
    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    
    RecRegion:end_press(key_id)
  end
end

return RecRegion 
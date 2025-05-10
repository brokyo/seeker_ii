-- motif_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local MotifRegion = setmetatable({}, Section)
MotifRegion.__index = MotifRegion

MotifRegion.layout = {
  x = 1,
  y = 7,
  width = 1,
  height = 1
}

-- Shared press state
MotifRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function MotifRegion.contains(x, y)
  return x == MotifRegion.layout.x and y == MotifRegion.layout.y
end

function MotifRegion.draw(layers)
  -- Draw keyboard outline during long press
  if MotifRegion:is_holding_long_press() then
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

  -- Draw region button with brightness logic
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local brightness
  
  if lane and lane.playing then
    -- Pulsing bright when playing, regardless of section
    brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
  elseif _seeker.ui_state.get_current_section() == "MOTIF" then
    brightness = GridConstants.BRIGHTNESS.FULL
  elseif _seeker.ui_state.get_current_section() == "GENERATE" or
         _seeker.ui_state.get_current_section() == "RECORDING" or
         _seeker.ui_state.get_current_section() == "OVERDUB" then
    brightness = GridConstants.BRIGHTNESS.MEDIUM
  else
    brightness = GridConstants.BRIGHTNESS.LOW
  end
  
  layers.ui[MotifRegion.layout.x][MotifRegion.layout.y] = brightness
end

function MotifRegion:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

function MotifRegion:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

function MotifRegion:is_holding_long_press()
  for key_id, press in pairs(self.press_state.pressed_keys) do
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD then
      return true
    end
  end
  return false
end

function MotifRegion:is_long_press(key_id)
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

function MotifRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    MotifRegion:start_press(key_id)
    _seeker.ui_state.set_current_section("MOTIF")
    _seeker.ui_state.set_long_press_state(true, "MOTIF")
    _seeker.screen_ui.set_needs_redraw()
  else -- Key released
    -- If it was a long press, toggle play state
    if MotifRegion:is_long_press(key_id) then
      local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
      if lane and lane.motif then
        if lane.playing then
          lane:stop()
        else
          lane:play()
        end
        _seeker.screen_ui.set_needs_redraw()
      end
    end
    
    -- Always clear long press state on release
    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    
    MotifRegion:end_press(key_id)
  end
end

return MotifRegion 
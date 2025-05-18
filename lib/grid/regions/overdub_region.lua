-- overdub_region.lua
local GridConstants = include("lib/grid_constants")
local Section = include("lib/ui/section")

local OverdubRegion = setmetatable({}, Section)
OverdubRegion.__index = OverdubRegion

OverdubRegion.layout = {
  x = 4,  -- Taking over play region's position
  y = 8,
  width = 1,
  height = 1
}

-- Shared press state
OverdubRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function OverdubRegion.contains(x, y)
  return x == OverdubRegion.layout.x and y == OverdubRegion.layout.y
end

function OverdubRegion.draw(layers)
  -- Draw keyboard outline during long press
  if OverdubRegion:is_holding_long_press() then
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
  local brightness
  if _seeker.ui_state.get_current_section() == "OVERDUB" then
    brightness = GridConstants.BRIGHTNESS.FULL
  elseif _seeker.ui_state.get_current_section() == "GENERATE" or
         _seeker.ui_state.get_current_section() == "RECORDING" or
         _seeker.ui_state.get_current_section() == "MOTIF" then
    brightness = GridConstants.BRIGHTNESS.MEDIUM
  else
    brightness = GridConstants.BRIGHTNESS.LOW
  end

  layers.ui[OverdubRegion.layout.x][OverdubRegion.layout.y] = brightness
end

function OverdubRegion:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

function OverdubRegion:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

function OverdubRegion:is_holding_long_press()
  for key_id, press in pairs(self.press_state.pressed_keys) do
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD then
      return true
    end
  end
  return false
end

function OverdubRegion:is_long_press(key_id)
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

function OverdubRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    OverdubRegion:start_press(key_id)
    _seeker.ui_state.set_current_section("OVERDUB")
    _seeker.ui_state.set_long_press_state(true, "OVERDUB")
    _seeker.screen_ui.set_needs_redraw()
  else -- Key released
    -- If already recording, stop on any release (short or long)
    if _seeker.motif_recorder.is_recording then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif = _seeker.motif_recorder:stop_recording()
      _seeker.lanes[focused_lane]:set_motif(motif)
      _seeker.screen_ui.set_needs_redraw()
    -- If not recording and it was a long press, start overdubbing
    elseif OverdubRegion:is_long_press(key_id) then
      -- Check if lane has a motif to overdub
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local existing_motif = _seeker.lanes[focused_lane].motif
      
      -- Don't allow overdub if no existing motif
      if #existing_motif.events == 0 then
        print("⚠ Cannot overdub: No existing motif")
      else
        params:set("recording_mode", 2)
        _seeker.motif_recorder:start_recording(existing_motif)
        _seeker.screen_ui.set_needs_redraw()
      end
    end
    
    -- Always clear long press state on release
    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    
    OverdubRegion:end_press(key_id)
  end
end

return OverdubRegion 
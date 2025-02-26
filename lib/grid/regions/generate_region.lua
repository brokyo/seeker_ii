-- generate_region.lua
local GridConstants = include("lib/grid_constants")
local GridAnimations = include("lib/grid_animations")
local Section = include("lib/ui/section")

local GenerateRegion = setmetatable({}, Section)
GenerateRegion.__index = GenerateRegion

GenerateRegion.layout = {
  x = 2,
  y = 7,
  width = 1,
  height = 1
}

-- Shared press state
GenerateRegion.press_state = {
  start_time = nil,
  pressed_keys = {}
}

function GenerateRegion.contains(x, y)
  return x == GenerateRegion.layout.x and y == GenerateRegion.layout.y
end

function GenerateRegion.draw(layers)
  -- Draw keyboard outline during long press
  if GenerateRegion:is_holding_long_press() then
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

  -- Draw region button with normal brightness logic
  local brightness
  if _seeker.ui_state.get_current_section() == "GENERATE" then
    brightness = GridConstants.BRIGHTNESS.FULL
  elseif _seeker.ui_state.get_current_section() == "RECORDING" or
         _seeker.ui_state.get_current_section() == "MOTIF" or
         _seeker.ui_state.get_current_section() == "OVERDUB" then
    brightness = GridConstants.BRIGHTNESS.MEDIUM
  else
    brightness = GridConstants.BRIGHTNESS.LOW
  end
  layers.ui[GenerateRegion.layout.x][GenerateRegion.layout.y] = brightness
end

function GenerateRegion:start_press(key_id)
  self.press_state.pressed_keys[key_id] = {
    start_time = util.time(),
    long_press_triggered = false
  }
end

function GenerateRegion:end_press(key_id)
  self.press_state.pressed_keys[key_id] = nil
end

function GenerateRegion:is_holding_long_press()
  for key_id, press in pairs(self.press_state.pressed_keys) do
    local elapsed = util.time() - press.start_time
    if elapsed >= Section.LONG_PRESS_THRESHOLD then
      return true
    end
  end
  return false
end

function GenerateRegion:is_long_press(key_id)
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

function GenerateRegion.handle_key(x, y, z)
  local key_id = string.format("%d,%d", x, y)
  
  if z == 1 then -- Key pressed
    GenerateRegion:start_press(key_id)
    _seeker.ui_state.set_current_section("GENERATE")
    _seeker.ui_state.set_long_press_state(true, "GENERATE")
    _seeker.screen_ui.set_needs_redraw()
  else -- Key released
    -- If it was a long press, generate new motif
    if GenerateRegion:is_long_press(key_id) then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]
      
      -- Clear the lane first
      lane:clear()
      
      -- Generate and set new motif
      local section = _seeker.screen_ui.sections.GENERATE
      local motif_data = section:generate_motif()
      lane:set_motif(motif_data)
      lane:play()  -- Start playing immediately after generating
      
      -- Flash keyboard to confirm generation
      GridAnimations.flash_keyboard()
    end
    
    -- Always clear long press state on release
    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    
    GenerateRegion:end_press(key_id)
  end
end

return GenerateRegion 
-- Tape mode type definition: routes between single and dual keyboard layouts
-- Declares components and handles grid draw/input routing

local DualTapeKeyboard = include("lib/modes/motif/types/tape/dual_keyboard")

local TapeType = {}

-- Stores dual keyboard component after first initialization
local dual_keyboard_instance = nil

-- Returns true when dual keyboard is active and wants the full grid
function TapeType.is_fullscreen()
  return DualTapeKeyboard.is_active()
end

-- Returns keyboard grid for current layout (single or dual)
local function get_current_keyboard()
  if DualTapeKeyboard.is_active() then
    if not dual_keyboard_instance then
      dual_keyboard_instance = DualTapeKeyboard.init()
    end
    return dual_keyboard_instance.grid
  end
  return _seeker.tape.keyboard.grid
end

-- Returns the active keyboard component (single or dual layout)
function TapeType.get_keyboard()
  return get_current_keyboard()
end

function TapeType.draw(layers)
  local keyboard = get_current_keyboard()

  -- Dual keyboard takes over the entire grid
  if DualTapeKeyboard.is_active() then
    keyboard:draw(layers)
    keyboard:draw_motif_events(layers)
    return
  end

  -- Single keyboard mode shows all components
  _seeker.tape.velocity.grid:draw(layers)
  _seeker.tape.stage_nav.grid:draw(layers)
  _seeker.tape.playback.grid:draw(layers)
  _seeker.tape.clear.grid:draw(layers)
  _seeker.tape.create.grid:draw(layers)
  _seeker.tape.perform.grid:draw(layers)
  keyboard:draw(layers)
  keyboard:draw_motif_events(layers)
end

function TapeType.handle_key(x, y, z)
  local keyboard = get_current_keyboard()

  -- Dual keyboard handles all keys itself
  if DualTapeKeyboard.is_active() then
    if keyboard:contains(x, y) then
      keyboard:handle_key(x, y, z)
      return true
    end
    return false
  end

  -- Single keyboard mode routes to individual components
  if keyboard:contains(x, y) then
    keyboard:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.velocity.grid:contains(x, y) then
    _seeker.tape.velocity.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.stage_nav.grid:contains(x, y) then
    _seeker.tape.stage_nav.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.playback.grid:contains(x, y) then
    _seeker.tape.playback.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.clear.grid:contains(x, y) then
    _seeker.tape.clear.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.create.grid:contains(x, y) then
    _seeker.tape.create.grid:handle_key(x, y, z)
    return true
  end

  if _seeker.tape.perform.grid:contains(x, y) then
    _seeker.tape.perform.grid:handle_key(x, y, z)
    return true
  end

  return false
end

return TapeType

-- keyboard_region.lua
-- Modal keyboard coordinator that delegates to mode-specific keyboards
-- Each keyboard mode defines its own layout within the keyboard area

local TapeKeyboard = include("lib/grid/regions/keyboards/tape_keyboard")

local KeyboardRegion = {}

-- Get current active keyboard based on create_motif_type
function KeyboardRegion.get_active_keyboard()
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")

  -- Initialize global keyboard cache if needed
  if not _seeker.keyboards[1] then
    _seeker.keyboards[1] = TapeKeyboard  -- Tape mode - default/immediate
  end

  -- Lazy-load non-default keyboards using global cache
  if not _seeker.keyboards[motif_type] then
    local keyboard_files = {
      [2] = "lib/grid/regions/keyboards/arpeggio_keyboard"
    }
    _seeker.keyboards[motif_type] = include(keyboard_files[motif_type])
  end

  return _seeker.keyboards[motif_type]
end

-- Get the layout for the current keyboard mode
function KeyboardRegion.get_layout()
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  return active_keyboard.layout
end

-- Check if coordinates are within the active keyboard area
function KeyboardRegion.contains(x, y)
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  return active_keyboard.contains(x, y)
end

-- Draw the current keyboard mode
function KeyboardRegion.draw(layers)
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  active_keyboard.draw(layers)
end

-- Handle key presses for the current keyboard mode
function KeyboardRegion.handle_key(x, y, z)
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  active_keyboard.handle_key(x, y, z)
end

-- Draw motif events for the current keyboard mode
function KeyboardRegion.draw_motif_events(layers)
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  active_keyboard.draw_motif_events(layers)
end

return KeyboardRegion
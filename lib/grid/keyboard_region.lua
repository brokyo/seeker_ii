-- keyboard_region.lua
-- Modal keyboard coordinator that delegates to mode-specific keyboards
-- Each keyboard mode defines its own layout within the keyboard area
--
-- NOTE: This is NOT a component - it's infrastructure/routing layer
-- It has no params, no screen UI - just dispatches to keyboard implementations
-- based on motif_type. Keep as pure region rather than componentizing.

local TapeKeyboard = include("lib/grid/keyboards/tape_keyboard")
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local KeyboardRegion = {}

-- Get current active keyboard based on motif_type
function KeyboardRegion.get_active_keyboard()
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")
  local current_section = _seeker.ui_state.get_current_section()

  -- Initialize global keyboard cache if needed
  if not _seeker.keyboards[1] then
    _seeker.keyboards[1] = TapeKeyboard  -- Tape mode - default/immediate
  end

  -- Check for dual keyboard in tape mode when in CREATE_MOTIF view
  if motif_type == 1 and current_section == "CREATE_MOTIF" then
    -- Lazy-load dual keyboard
    if not _seeker.keyboards.dual_tape then
      _seeker.keyboards.dual_tape = include("lib/grid/keyboards/dual_tape_keyboard")
    end

    -- Return dual keyboard if active
    if _seeker.keyboards.dual_tape.is_active then
      return _seeker.keyboards.dual_tape
    end
  end

  -- Lazy-load non-default keyboards using global cache
  if not _seeker.keyboards[motif_type] then
    local keyboard_files = {
      [2] = "lib/grid/keyboards/arpeggio_keyboard",
      [3] = "lib/modes/motif/types/sampler/keyboard"
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

-- Find all grid positions for a given MIDI note (delegates to active keyboard)
function KeyboardRegion.note_to_positions(note)
  local active_keyboard = KeyboardRegion.get_active_keyboard()
  return active_keyboard.note_to_positions(note)
end

return KeyboardRegion
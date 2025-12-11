-- keyboard.lua
-- Tape type keyboard: wrapper around tape_keyboard module
-- Part of lib/modes/motif/tape/

local GridUI = include("lib/ui/base/grid_ui")
local TapeKeyboardModule = include("lib/grid/keyboards/tape_keyboard")

local TapeKeyboard = {}

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_KEYBOARD",
    layout = {
      x = TapeKeyboardModule.layout.upper_left_x,
      y = TapeKeyboardModule.layout.upper_left_y,
      width = TapeKeyboardModule.layout.width,
      height = TapeKeyboardModule.layout.height
    }
  })

  grid_ui.draw = function(self, layers)
    TapeKeyboardModule.draw(layers)
  end

  grid_ui.draw_motif_events = function(self, layers)
    TapeKeyboardModule.draw_motif_events(layers)
  end

  grid_ui.handle_key = function(self, x, y, z)
    TapeKeyboardModule.handle_key(x, y, z)
  end

  -- Expose helper functions for external use (keyboard interface)
  grid_ui.note_to_positions = TapeKeyboardModule.note_to_positions
  grid_ui.create_note_event = TapeKeyboardModule.create_note_event

  return grid_ui
end

function TapeKeyboard.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return TapeKeyboard

-- keyboard.lua
-- Tape type keyboard: Tonnetz-style keyboard for tape recording mode
-- Part of lib/modes/motif/types/tape/

local GridUI = include("lib/ui/base/grid_ui")
local theory = include("lib/modes/motif/core/theory")
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local TapeKeyboard = {}

-- Layout definition - full 6x6 keyboard area
local layout = {
  x = 6,
  y = 2,
  width = 6,
  height = 6
}

-- Find all grid positions for a given MIDI note
local function note_to_positions(note)
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local keyboard_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  local positions = {}

  -- Search keyboard area
  for y = layout.y, layout.y + layout.height - 1 do
    for x = layout.x, layout.x + layout.width - 1 do
      if theory.grid_to_note(x, y, keyboard_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  return #positions > 0 and positions or nil
end

-- Create a standardized note event
local function create_note_event(x, y, note, velocity)
  local all_positions = note_to_positions(note)

  return {
    note = note,
    velocity = velocity or 0,
    x = x,
    y = y,
    positions = all_positions or {{x = x, y = y}},
    is_playback = false,
    source = "grid"
  }
end

-- Handle note on event
local function note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)
  local velocity = _seeker.tape.velocity.get_current_velocity()
  local event = create_note_event(x, y, note, velocity)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

-- Handle note off event
local function note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)

  local event = create_note_event(x, y, note, 0)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_off(event)
  end

  focused_lane:on_note_off(event)
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "TAPE_KEYBOARD",
    layout = layout
  })

  grid_ui.draw = function(self, layers)
    local root = params:get("root_note")
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")

    for x = 0, layout.width - 1 do
      for y = 0, layout.height - 1 do
        local grid_x = layout.x + x
        local grid_y = layout.y + y
        local note = theory.grid_to_note(grid_x, grid_y, octave)

        -- Check if this note is a root note by comparing with the actual root pitch class
        local brightness = GridConstants.BRIGHTNESS.LOW
        if note then
          local root_pitch_class = (root - 1) % 12
          if note % 12 == root_pitch_class then
            brightness = GridConstants.BRIGHTNESS.MEDIUM
          end
        end

        GridLayers.set(layers.ui, grid_x, grid_y, brightness)
      end
    end
  end

  grid_ui.draw_motif_events = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]

    -- Get active positions from focused lane
    local active_positions = focused_lane:get_active_positions()

    -- Illuminate active positions at full brightness
    for _, pos in ipairs(active_positions) do
      if pos.x >= layout.x and pos.x < layout.x + layout.width and
         pos.y >= layout.y and pos.y < layout.y + layout.height then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
      end
    end

    -- Draw MIDI input notes if available
    if _seeker.midi_input then
      local midi_positions = _seeker.midi_input.get_active_positions()
      for _, pos in ipairs(midi_positions) do
        if pos.x >= layout.x and pos.x < layout.x + layout.width and
           pos.y >= layout.y and pos.y < layout.y + layout.height then
          GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
        end
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      note_on(x, y)
    else
      note_off(x, y)
    end
  end

  -- Expose helper functions for external use (keyboard interface)
  grid_ui.note_to_positions = note_to_positions
  grid_ui.create_note_event = create_note_event

  return grid_ui
end

function TapeKeyboard.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return TapeKeyboard

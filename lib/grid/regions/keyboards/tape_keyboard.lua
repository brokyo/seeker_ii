-- tape_keyboard.lua
-- Tonnetz-style keyboard for tape recording mode
-- Extracted from grid.lua to support modal keyboards

local theory = include("lib/theory_utils")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")

local TapeKeyboard = {}

-- Module state
TapeKeyboard.velocity = 100  -- Default to forte (0-127)

-- Layout definition - full 6x6 keyboard area
TapeKeyboard.layout = {
  upper_left_x = 6,
  upper_left_y = 2,
  width = 6,
  height = 6
}

-- Check if coordinates are within tape keyboard area
function TapeKeyboard.contains(x, y)
  return x >= TapeKeyboard.layout.upper_left_x and
         x < TapeKeyboard.layout.upper_left_x + TapeKeyboard.layout.width and
         y >= TapeKeyboard.layout.upper_left_y and
         y < TapeKeyboard.layout.upper_left_y + TapeKeyboard.layout.height
end

-- Find all grid positions for a given MIDI note
function TapeKeyboard.note_to_positions(note)
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local keyboard_octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  local positions = {}

  -- Search keyboard area
  for y = TapeKeyboard.layout.upper_left_y, TapeKeyboard.layout.upper_left_y + TapeKeyboard.layout.height - 1 do
    for x = TapeKeyboard.layout.upper_left_x, TapeKeyboard.layout.upper_left_x + TapeKeyboard.layout.width - 1 do
      if theory.grid_to_note(x, y, keyboard_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  return #positions > 0 and positions or nil
end

-- Create a standardized note event (extracted from grid.lua)
function TapeKeyboard.create_note_event(x, y, note, velocity)
  local all_positions = TapeKeyboard.note_to_positions(note)

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

-- Handle note on event (extracted from grid.lua)
function TapeKeyboard.note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)

  -- Print the note being played for debugging
  if note then
    local note_name = musicutil.note_num_to_name(note, true)
    local actual_octave = tonumber(string.match(note_name, "%d+"))
    print(string.format("Note played: %s (MIDI %d) at grid position (%d,%d), Octave param: %d, Actual octave: %d, Velocity: %d",
          note_name, note, x, y, keyboard_octave, actual_octave, TapeKeyboard.velocity))
  end

  local event = TapeKeyboard.create_note_event(x, y, note, TapeKeyboard.velocity)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

-- Handle note off event (extracted from grid.lua)
function TapeKeyboard.note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local keyboard_octave = params:get("lane_" .. _seeker.ui_state.get_focused_lane() .. "_keyboard_octave")
  local note = theory.grid_to_note(x, y, keyboard_octave)
  
  local event = TapeKeyboard.create_note_event(x, y, note, 0)
  
  if _seeker.motif_recorder.is_recording then  
    _seeker.motif_recorder:on_note_off(event)
  end
  
  focused_lane:on_note_off(event)
end

-- Handle key presses
function TapeKeyboard.handle_key(x, y, z)
  if z == 1 then
    TapeKeyboard.note_on(x, y)
  else
    TapeKeyboard.note_off(x, y)
  end
end

-- Draw the tonnetz keyboard layout (extracted from grid.lua)
function TapeKeyboard.draw(layers)
  local root = params:get("root_note")
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")

  for x = 0, TapeKeyboard.layout.width - 1 do
    for y = 0, TapeKeyboard.layout.height - 1 do
      local grid_x = TapeKeyboard.layout.upper_left_x + x
      local grid_y = TapeKeyboard.layout.upper_left_y + y
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

  -- Draw count display when recording
  if _seeker.motif_recorder.is_recording then
    local current_quarter = math.floor(clock.get_beats()) % 4
    local count_x_start = 7
    local count_x_end = 10
    local count_y = 1

    -- Set all count LEDs to low brightness
    for x_count = count_x_start, count_x_end do
      GridLayers.set(layers.ui, x_count, count_y, GridConstants.BRIGHTNESS.LOW)
    end

    -- Highlight current beat with sharp attack and quick decay
    local highlight_x = count_x_start + current_quarter
    local beat_phase = clock.get_beats() % 1
    local brightness
    if beat_phase < 0.25 then
      local decay = math.exp(-beat_phase * 12)
      local range = GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW
      brightness = math.floor(GridConstants.BRIGHTNESS.LOW + range * decay)
    else
      brightness = GridConstants.BRIGHTNESS.LOW
    end
    GridLayers.set(layers.ui, highlight_x, count_y, brightness)
  end
end

-- Draw motif events for active positions (extracted from grid.lua)
function TapeKeyboard.draw_motif_events(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  -- Get active positions from focused lane
  local active_positions = focused_lane:get_active_positions()
  
  -- Illuminate active positions at full brightness
  for _, pos in ipairs(active_positions) do
    if TapeKeyboard.contains(pos.x, pos.y) then
      GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
    end
  end
  
  -- Draw MIDI input notes if available
  if _seeker.midi_input then
    local midi_positions = _seeker.midi_input.get_active_positions()
    for _, pos in ipairs(midi_positions) do
      if TapeKeyboard.contains(pos.x, pos.y) then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
      end
    end
  end
end

return TapeKeyboard
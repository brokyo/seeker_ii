-- dual_tape_keyboard.lua
-- Dual Tonnetz keyboard for tape recording mode
-- Left keyboard (bass) and right keyboard (treble) with independent octave controls
-- Only visible when in CREATE_MOTIF view

local theory = include("lib/theory_utils")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")

local DualTapeKeyboard = {}

-- Module state (no parameters - all controlled via grid buttons)
DualTapeKeyboard.is_active = false
DualTapeKeyboard.left_octave = 2  -- Bass octave
DualTapeKeyboard.right_octave = 4 -- Treble octave

-- Layout definitions
DualTapeKeyboard.layout = {
  left_keyboard = {
    upper_left_x = 1,
    upper_left_y = 2,
    width = 6,
    height = 6
  },
  right_keyboard = {
    upper_left_x = 11,
    upper_left_y = 2,
    width = 6,
    height = 6
  },
  left_octave_up = { x = 7, y = 6 },
  left_octave_down = { x = 7, y = 7 },
  right_octave_up = { x = 10, y = 6 },
  right_octave_down = { x = 10, y = 7 },
  record_button = { x = 9, y = 8 },
  toggle_button = { x = 16, y = 8 }
}

-- Check if coordinates are within either keyboard area or control buttons
function DualTapeKeyboard.contains(x, y)
  local left = DualTapeKeyboard.layout.left_keyboard
  local right = DualTapeKeyboard.layout.right_keyboard
  local layout = DualTapeKeyboard.layout

  -- Check keyboard areas
  local in_keyboard = (x >= left.upper_left_x and x < left.upper_left_x + left.width and
                       y >= left.upper_left_y and y < left.upper_left_y + left.height) or
                      (x >= right.upper_left_x and x < right.upper_left_x + right.width and
                       y >= right.upper_left_y and y < right.upper_left_y + right.height)

  -- Check octave buttons
  local is_octave_button = (x == layout.left_octave_up.x and y == layout.left_octave_up.y) or
                           (x == layout.left_octave_down.x and y == layout.left_octave_down.y) or
                           (x == layout.right_octave_up.x and y == layout.right_octave_up.y) or
                           (x == layout.right_octave_down.x and y == layout.right_octave_down.y)

  -- Check record button
  local is_record_button = (x == layout.record_button.x and y == layout.record_button.y)

  return in_keyboard or is_octave_button or is_record_button
end

-- Find all grid positions for a given MIDI note (searches both keyboards)
function DualTapeKeyboard.note_to_positions(note)
  local positions = {}

  -- Search left keyboard with left octave
  local left = DualTapeKeyboard.layout.left_keyboard
  for y = left.upper_left_y, left.upper_left_y + left.height - 1 do
    for x = left.upper_left_x, left.upper_left_x + left.width - 1 do
      if theory.grid_to_note(x, y, DualTapeKeyboard.left_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  -- Search right keyboard with right octave
  local right = DualTapeKeyboard.layout.right_keyboard
  for y = right.upper_left_y, right.upper_left_y + right.height - 1 do
    for x = right.upper_left_x, right.upper_left_x + right.width - 1 do
      if theory.grid_to_note(x, y, DualTapeKeyboard.right_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  return #positions > 0 and positions or nil
end

-- Determine which keyboard a coordinate is in
local function get_keyboard_side(x, y)
  local left = DualTapeKeyboard.layout.left_keyboard
  if x >= left.upper_left_x and x < left.upper_left_x + left.width and
     y >= left.upper_left_y and y < left.upper_left_y + left.height then
    return "left"
  end

  local right = DualTapeKeyboard.layout.right_keyboard
  if x >= right.upper_left_x and x < right.upper_left_x + right.width and
     y >= right.upper_left_y and y < right.upper_left_y + right.height then
    return "right"
  end

  return nil
end

-- Create a standardized note event
function DualTapeKeyboard.create_note_event(x, y, note, velocity)
  local all_positions = DualTapeKeyboard.note_to_positions(note)

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
function DualTapeKeyboard.note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]

  -- Determine which keyboard and get appropriate octave
  local side = get_keyboard_side(x, y)
  if not side then return end

  local keyboard_octave = (side == "left") and DualTapeKeyboard.left_octave or DualTapeKeyboard.right_octave
  local note = theory.grid_to_note(x, y, keyboard_octave)

  -- Print the note being played for debugging
  if note then
    local note_name = musicutil.note_num_to_name(note, true)
    local actual_octave = tonumber(string.match(note_name, "%d+"))
    print(string.format("Note played [%s]: %s (MIDI %d) at grid position (%d,%d), Octave param: %d, Actual octave: %d",
          side, note_name, note, x, y, keyboard_octave, actual_octave))
  end

  -- Get velocity from velocity region
  local velocity_region = include("lib/grid/regions/velocity_region")
  local event = DualTapeKeyboard.create_note_event(x, y, note, velocity_region.get_current_velocity())

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

-- Handle note off event
function DualTapeKeyboard.note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]

  -- Determine which keyboard and get appropriate octave
  local side = get_keyboard_side(x, y)
  if not side then return end

  local keyboard_octave = (side == "left") and DualTapeKeyboard.left_octave or DualTapeKeyboard.right_octave
  local note = theory.grid_to_note(x, y, keyboard_octave)

  local event = DualTapeKeyboard.create_note_event(x, y, note, 0)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_off(event)
  end

  focused_lane:on_note_off(event)
end

-- Handle octave button presses
local function handle_octave_button(x, y, z)
  if z ~= 1 then return end -- Only on key down

  local layout = DualTapeKeyboard.layout

  -- Determine which octave button was pressed and adjust
  if x == layout.left_octave_up.x and y == layout.left_octave_up.y then
    DualTapeKeyboard.left_octave = util.clamp(DualTapeKeyboard.left_octave + 1, 1, 7)
    print(string.format("Left octave: %d", DualTapeKeyboard.left_octave))
  elseif x == layout.left_octave_down.x and y == layout.left_octave_down.y then
    DualTapeKeyboard.left_octave = util.clamp(DualTapeKeyboard.left_octave - 1, 1, 7)
    print(string.format("Left octave: %d", DualTapeKeyboard.left_octave))
  elseif x == layout.right_octave_up.x and y == layout.right_octave_up.y then
    DualTapeKeyboard.right_octave = util.clamp(DualTapeKeyboard.right_octave + 1, 1, 7)
    print(string.format("Right octave: %d", DualTapeKeyboard.right_octave))
  elseif x == layout.right_octave_down.x and y == layout.right_octave_down.y then
    DualTapeKeyboard.right_octave = util.clamp(DualTapeKeyboard.right_octave - 1, 1, 7)
    print(string.format("Right octave: %d", DualTapeKeyboard.right_octave))
  end
end

-- Handle record button (long press detection)
local record_key_state = {
  is_pressed = false,
  press_time = nil,
  key_id = nil
}

local LONG_PRESS_TIME = 0.5

local function handle_record_button(x, y, z)
  local layout = DualTapeKeyboard.layout
  if x ~= layout.record_button.x or y ~= layout.record_button.y then
    return
  end

  if z == 1 then -- Key pressed
    record_key_state.is_pressed = true
    record_key_state.press_time = util.time()
    record_key_state.key_id = string.format("%d,%d", x, y)

    _seeker.ui_state.set_current_section("CREATE_MOTIF")
    _seeker.ui_state.set_long_press_state(true, "CREATE_MOTIF")
    _seeker.screen_ui.set_needs_redraw()
  else -- Key released
    local is_long_press = false
    if record_key_state.is_pressed and record_key_state.press_time then
      local press_duration = util.time() - record_key_state.press_time
      is_long_press = press_duration >= LONG_PRESS_TIME
    end

    -- Handle recording based on press type (mirrors create_motif logic)
    local focused_lane_idx = _seeker.ui_state.get_focused_lane()
    local current_lane = _seeker.lanes[focused_lane_idx]

    if _seeker.motif_recorder.is_recording then
      -- Stop recording
      local was_overdubbing = (_seeker.motif_recorder.original_motif ~= nil)
      local recorded_motif = _seeker.motif_recorder:stop_recording()
      current_lane:set_motif(recorded_motif)

      if not was_overdubbing then
        current_lane:play()
      end

      if _seeker.create_motif and _seeker.create_motif.screen then
        _seeker.create_motif.screen:rebuild_params()
      end
      _seeker.screen_ui.set_needs_redraw()
    elseif is_long_press then
      -- Start recording or overdubbing
      local existing_motif = current_lane.motif

      if existing_motif and #existing_motif.events > 0 and current_lane.playing then
        -- Overdub
        _seeker.motif_recorder:set_recording_mode(2)
        _seeker.motif_recorder:start_recording(existing_motif)
      else
        -- New recording
        current_lane:clear()

        if _seeker.create_motif and _seeker.create_motif.screen then
          _seeker.create_motif.screen:rebuild_params()
        end

        _seeker.motif_recorder:set_recording_mode(1)
        _seeker.motif_recorder:start_recording(nil)
      end

      _seeker.screen_ui.set_needs_redraw()
    end

    -- Cleanup
    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    record_key_state.is_pressed = false
    record_key_state.press_time = nil
    record_key_state.key_id = nil
  end
end

-- Handle key presses
function DualTapeKeyboard.handle_key(x, y, z)
  local layout = DualTapeKeyboard.layout

  -- Check for octave buttons
  if (x == layout.left_octave_up.x or x == layout.left_octave_down.x or
      x == layout.right_octave_up.x or x == layout.right_octave_down.x) and
     (y == 6 or y == 7) then
    handle_octave_button(x, y, z)
    return
  end

  -- Check for record button
  if x == layout.record_button.x and y == layout.record_button.y then
    handle_record_button(x, y, z)
    return
  end

  -- Handle keyboard notes
  if DualTapeKeyboard.contains(x, y) then
    if z == 1 then
      DualTapeKeyboard.note_on(x, y)
    else
      DualTapeKeyboard.note_off(x, y)
    end
  end
end

-- Draw the dual tonnetz keyboard layout
function DualTapeKeyboard.draw(layers)
  local root = params:get("root_note")

  -- Draw left keyboard (bass)
  local left = DualTapeKeyboard.layout.left_keyboard

  for x = 0, left.width - 1 do
    for y = 0, left.height - 1 do
      local grid_x = left.upper_left_x + x
      local grid_y = left.upper_left_y + y
      local note = theory.grid_to_note(grid_x, grid_y, DualTapeKeyboard.left_octave)

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

  -- Draw right keyboard (treble)
  local right = DualTapeKeyboard.layout.right_keyboard

  for x = 0, right.width - 1 do
    for y = 0, right.height - 1 do
      local grid_x = right.upper_left_x + x
      local grid_y = right.upper_left_y + y
      local note = theory.grid_to_note(grid_x, grid_y, DualTapeKeyboard.right_octave)

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

  -- Draw octave buttons
  local layout = DualTapeKeyboard.layout
  GridLayers.set(layers.ui, layout.left_octave_up.x, layout.left_octave_up.y, GridConstants.BRIGHTNESS.LOW)
  GridLayers.set(layers.ui, layout.left_octave_down.x, layout.left_octave_down.y, GridConstants.BRIGHTNESS.LOW)
  GridLayers.set(layers.ui, layout.right_octave_up.x, layout.right_octave_up.y, GridConstants.BRIGHTNESS.LOW)
  GridLayers.set(layers.ui, layout.right_octave_down.x, layout.right_octave_down.y, GridConstants.BRIGHTNESS.LOW)

  -- Draw record button
  local record_brightness = GridConstants.BRIGHTNESS.UI.NORMAL
  if _seeker.motif_recorder.is_recording then
    -- Pulsate while recording
    local pulse_rate = 2
    local phase = (clock.get_beats() * pulse_rate) % 1
    local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
    record_brightness = math.floor(GridConstants.BRIGHTNESS.LOW + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
  elseif record_key_state.is_pressed then
    record_brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
  end
  GridLayers.set(layers.ui, layout.record_button.x, layout.record_button.y, record_brightness)
end

-- Draw motif events for active positions
function DualTapeKeyboard.draw_motif_events(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  -- Get active positions from focused lane
  local active_positions = focused_lane:get_active_positions()

  -- Illuminate active positions at full brightness
  for _, pos in ipairs(active_positions) do
    if DualTapeKeyboard.contains(pos.x, pos.y) then
      GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
    end
  end

  -- Draw MIDI input notes if available
  if _seeker.midi_input then
    local midi_positions = _seeker.midi_input.get_active_positions()
    for _, pos in ipairs(midi_positions) do
      if DualTapeKeyboard.contains(pos.x, pos.y) then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
      end
    end
  end
end

-- Toggle activation state
function DualTapeKeyboard.toggle()
  DualTapeKeyboard.is_active = not DualTapeKeyboard.is_active
  print(string.format("Dual keyboard: %s", DualTapeKeyboard.is_active and "ACTIVE" or "INACTIVE"))
end

return DualTapeKeyboard

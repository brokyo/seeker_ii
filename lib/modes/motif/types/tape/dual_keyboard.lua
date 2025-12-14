-- dual_keyboard.lua
-- Two independent tonnetz keyboards with separate octave controls
-- Includes record/clear buttons and beat counter display
-- Part of lib/modes/motif/types/tape/

local GridUI = include("lib/ui/base/grid_ui")
local theory = include("lib/modes/motif/core/theory")
local GridConstants = include("lib/grid/constants")
local GridLayers = include("lib/grid/layers")

local DualTapeKeyboard = {}

-- Keyboard state stored in _seeker for cross-module access
local function get_state()
  if not _seeker.dual_keyboard_state then
    _seeker.dual_keyboard_state = {
      is_active = false,
      left_octave = 2,
      right_octave = 4,
      left_velocity = 100,
      right_velocity = 100
    }
  end
  return _seeker.dual_keyboard_state
end

-- Renders Arc rings: layout indicator (ring 2) and left/right velocity (rings 3/4)
local function draw_arc_display()
  local arc = _seeker.arc
  if not arc then return end

  local dual_state = get_state()

  -- Ring 1: Dim base to show it's available for param navigation
  for i = 1, 64 do
    arc:led(1, i, 3)
  end

  -- Ring 2: Shows layout toggle (left half = single, right half = dual)
  for i = 1, 64 do
    arc:led(2, i, 1)
  end
  -- Illuminate right half to indicate dual mode is active
  for i = 33, 64 do
    arc:led(2, i, 8)
  end

  -- Ring 3: Left keyboard velocity (0-127)
  for i = 1, 64 do
    arc:led(3, i, 1)
  end
  local left_leds = math.floor((dual_state.left_velocity / 127) * 64)
  for i = 1, left_leds do
    arc:led(3, i, 10)
  end

  -- Ring 4: Right keyboard velocity (0-127)
  for i = 1, 64 do
    arc:led(4, i, 1)
  end
  local right_leds = math.floor((dual_state.right_velocity / 127) * 64)
  for i = 1, right_leds do
    arc:led(4, i, 10)
  end

  arc:refresh()
end

function DualTapeKeyboard.set_active(active)
  get_state().is_active = active

  -- Set arc to display velocity controls when active, restore default when inactive
  if _seeker.arc then
    if active then
      _seeker.arc.display_override = draw_arc_display
      draw_arc_display()
    else
      _seeker.arc.display_override = nil
    end
  end
end

function DualTapeKeyboard.is_active()
  return get_state().is_active
end

-- Layout covering full grid with specific regions for keyboards and controls
local layout = {
  x = 1,
  y = 1,
  width = 16,
  height = 8,
  left_keyboard = {
    x = 1,
    y = 2,
    width = 6,
    height = 6
  },
  right_keyboard = {
    x = 11,
    y = 2,
    width = 6,
    height = 6
  },
  left_octave_up = { x = 7, y = 6 },
  left_octave_down = { x = 7, y = 7 },
  right_octave_up = { x = 10, y = 6 },
  right_octave_down = { x = 10, y = 7 },
  record_button = { x = 8, y = 8 },
  clear_button = { x = 9, y = 8 }
}

-- Track button press timing for long-press detection
local record_key_state = {
  is_pressed = false,
  press_time = nil
}

local clear_key_state = {
  is_pressed = false,
  press_time = nil
}

local LONG_PRESS_TIME = 0.5
local CLEAR_LONG_PRESS_TIME = 1.5

-- Check if position is in a keyboard area
local function in_keyboard_area(x, y)
  local left = layout.left_keyboard
  local right = layout.right_keyboard

  return (x >= left.x and x < left.x + left.width and
          y >= left.y and y < left.y + left.height) or
         (x >= right.x and x < right.x + right.width and
          y >= right.y and y < right.y + right.height)
end

-- Check if position is an octave button
local function is_octave_button(x, y)
  return (x == layout.left_octave_up.x and y == layout.left_octave_up.y) or
         (x == layout.left_octave_down.x and y == layout.left_octave_down.y) or
         (x == layout.right_octave_up.x and y == layout.right_octave_up.y) or
         (x == layout.right_octave_down.x and y == layout.right_octave_down.y)
end

-- Determine which keyboard side a position is in
local function get_keyboard_side(x, y)
  local left = layout.left_keyboard
  if x >= left.x and x < left.x + left.width and
     y >= left.y and y < left.y + left.height then
    return "left"
  end

  local right = layout.right_keyboard
  if x >= right.x and x < right.x + right.width and
     y >= right.y and y < right.y + right.height then
    return "right"
  end

  return nil
end

-- Translate dual keyboard position to single keyboard coordinate space
-- theory.grid_to_note expects keyboard at x=6, so we shift accordingly
local function to_theory_coords(x, y, side)
  if side == "left" then
    -- Left keyboard (x=1-6) shifts right by 5 to align with theory's x=6 origin
    return x + 5, y
  else
    -- Right keyboard (x=11-16) shifts left by 5 to align with theory's x=6 origin
    return x - 5, y
  end
end

-- Find all grid positions for a given MIDI note
local function note_to_positions(note)
  local positions = {}

  local left = layout.left_keyboard
  for y = left.y, left.y + left.height - 1 do
    for x = left.x, left.x + left.width - 1 do
      local tx, ty = to_theory_coords(x, y, "left")
      if theory.grid_to_note(tx, ty, get_state().left_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  local right = layout.right_keyboard
  for y = right.y, right.y + right.height - 1 do
    for x = right.x, right.x + right.width - 1 do
      local tx, ty = to_theory_coords(x, y, "right")
      if theory.grid_to_note(tx, ty, get_state().right_octave) == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end

  return #positions > 0 and positions or nil
end

-- Create note event
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

-- Trigger note on for recorder (if recording) and focused lane
local function note_on(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local side = get_keyboard_side(x, y)
  if not side then return end

  local state = get_state()
  local keyboard_octave = (side == "left") and state.left_octave or state.right_octave
  local velocity = (side == "left") and state.left_velocity or state.right_velocity
  local tx, ty = to_theory_coords(x, y, side)
  local note = theory.grid_to_note(tx, ty, keyboard_octave)
  local event = create_note_event(x, y, note, velocity)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_on(event)
  end

  focused_lane:on_note_on(event)
end

-- Trigger note off for recorder (if recording) and focused lane
local function note_off(x, y)
  local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local side = get_keyboard_side(x, y)
  if not side then return end

  local state = get_state()
  local keyboard_octave = (side == "left") and state.left_octave or state.right_octave
  local tx, ty = to_theory_coords(x, y, side)
  local note = theory.grid_to_note(tx, ty, keyboard_octave)
  local event = create_note_event(x, y, note, 0)

  if _seeker.motif_recorder.is_recording then
    _seeker.motif_recorder:on_note_off(event)
  end

  focused_lane:on_note_off(event)
end

-- Adjust left/right keyboard octave within 1-7 range
local function handle_octave_button(x, y, z)
  if z ~= 1 then return end

  local state = get_state()
  if x == layout.left_octave_up.x and y == layout.left_octave_up.y then
    state.left_octave = util.clamp(state.left_octave + 1, 1, 7)
  elseif x == layout.left_octave_down.x and y == layout.left_octave_down.y then
    state.left_octave = util.clamp(state.left_octave - 1, 1, 7)
  elseif x == layout.right_octave_up.x and y == layout.right_octave_up.y then
    state.right_octave = util.clamp(state.right_octave + 1, 1, 7)
  elseif x == layout.right_octave_down.x and y == layout.right_octave_down.y then
    state.right_octave = util.clamp(state.right_octave - 1, 1, 7)
  end
end

-- Record button: tap to stop recording, hold to start recording or overdub
local function handle_record_button(x, y, z)
  if z == 1 then
    record_key_state.is_pressed = true
    record_key_state.press_time = util.time()

    _seeker.ui_state.set_current_section("TAPE_CREATE")
    _seeker.ui_state.set_long_press_state(true, "TAPE_CREATE")
    _seeker.screen_ui.set_needs_redraw()
  else
    local is_long_press = false
    if record_key_state.is_pressed and record_key_state.press_time then
      is_long_press = (util.time() - record_key_state.press_time) >= LONG_PRESS_TIME
    end

    local focused_lane_idx = _seeker.ui_state.get_focused_lane()
    local current_lane = _seeker.lanes[focused_lane_idx]

    if _seeker.motif_recorder.is_recording then
      local was_overdubbing = (_seeker.motif_recorder.original_motif ~= nil)
      local recorded_motif = _seeker.motif_recorder:stop_recording()
      current_lane:set_motif(recorded_motif)

      -- Sync duration param to recorded motif's actual duration
      params:set("tape_create_duration", recorded_motif.duration, true)

      if not was_overdubbing then
        current_lane:play()
      end

      if _seeker.tape.create and _seeker.tape.create.screen then
        _seeker.tape.create.screen:rebuild_params()
      end
      _seeker.screen_ui.set_needs_redraw()
    elseif is_long_press then
      local existing_motif = current_lane.motif

      if existing_motif and #existing_motif.events > 0 and current_lane.playing then
        _seeker.motif_recorder:set_recording_mode(2)
        _seeker.motif_recorder:start_recording(existing_motif)
      else
        current_lane:clear()

        if _seeker.tape.create and _seeker.tape.create.screen then
          _seeker.tape.create.screen:rebuild_params()
        end

        _seeker.motif_recorder:set_recording_mode(1)
        _seeker.motif_recorder:start_recording(nil)
      end

      _seeker.screen_ui.set_needs_redraw()
    end

    _seeker.ui_state.set_long_press_state(false, nil)
    _seeker.screen_ui.set_needs_redraw()
    record_key_state.is_pressed = false
    record_key_state.press_time = nil
  end
end

-- Clear button: requires 1.5s hold to clear focused lane's motif
local function handle_clear_button(x, y, z)
  if z == 1 then
    clear_key_state.is_pressed = true
    clear_key_state.press_time = util.time()
  else
    local is_long_press = false
    if clear_key_state.is_pressed and clear_key_state.press_time then
      is_long_press = (util.time() - clear_key_state.press_time) >= CLEAR_LONG_PRESS_TIME
    end

    if is_long_press then
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local lane = _seeker.lanes[focused_lane]

      if lane and lane.motif and #lane.motif.events > 0 then
        lane:clear()

        if _seeker.tape.create and _seeker.tape.create.screen then
          _seeker.tape.create.screen:rebuild_params()
        end

        _seeker.screen_ui.set_needs_redraw()
      end
    end

    clear_key_state.is_pressed = false
    clear_key_state.press_time = nil
  end
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "DUAL_TAPE_KEYBOARD",
    layout = layout
  })

  -- Override contains to check specific areas
  grid_ui.contains = function(self, x, y)
    return in_keyboard_area(x, y) or
           is_octave_button(x, y) or
           (x == layout.record_button.x and y == layout.record_button.y) or
           (x == layout.clear_button.x and y == layout.clear_button.y)
  end

  grid_ui.draw = function(self, layers)
    local root = params:get("root_note")

    -- Draw left keyboard
    local left = layout.left_keyboard
    for lx = 0, left.width - 1 do
      for ly = 0, left.height - 1 do
        local grid_x = left.x + lx
        local grid_y = left.y + ly
        local tx, ty = to_theory_coords(grid_x, grid_y, "left")
        local note = theory.grid_to_note(tx, ty, get_state().left_octave)

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

    -- Draw right keyboard
    local right = layout.right_keyboard
    for rx = 0, right.width - 1 do
      for ry = 0, right.height - 1 do
        local grid_x = right.x + rx
        local grid_y = right.y + ry
        local tx, ty = to_theory_coords(grid_x, grid_y, "right")
        local note = theory.grid_to_note(tx, ty, get_state().right_octave)

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
    GridLayers.set(layers.ui, layout.left_octave_up.x, layout.left_octave_up.y, GridConstants.BRIGHTNESS.LOW)
    GridLayers.set(layers.ui, layout.left_octave_down.x, layout.left_octave_down.y, GridConstants.BRIGHTNESS.LOW)
    GridLayers.set(layers.ui, layout.right_octave_up.x, layout.right_octave_up.y, GridConstants.BRIGHTNESS.LOW)
    GridLayers.set(layers.ui, layout.right_octave_down.x, layout.right_octave_down.y, GridConstants.BRIGHTNESS.LOW)

    -- Draw beat counter when recording
    if _seeker.motif_recorder.is_recording then
      local current_quarter = math.floor(clock.get_beats()) % 4
      local count_x_start = 7
      local count_y = 1

      for i = 0, 3 do
        GridLayers.set(layers.ui, count_x_start + i, count_y, GridConstants.BRIGHTNESS.LOW)
      end

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

    -- Draw record button
    local record_brightness = GridConstants.BRIGHTNESS.UI.NORMAL
    if _seeker.motif_recorder.is_recording then
      local base = GridConstants.BRIGHTNESS.UI.NORMAL
      local range = 3
      local speed = 4
      record_brightness = math.floor(math.sin(clock.get_beats() * speed) * range + base + range)
    elseif record_key_state.is_pressed then
      record_brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
    end
    GridLayers.set(layers.ui, layout.record_button.x, layout.record_button.y, record_brightness)

    -- Draw hold indicator when record button is held (ready to record on release)
    if record_key_state.is_pressed and not _seeker.motif_recorder.is_recording then
      local press_duration = util.time() - record_key_state.press_time
      local progress = math.min(press_duration / LONG_PRESS_TIME, 1)
      local indicator_brightness = math.floor(GridConstants.BRIGHTNESS.LOW + progress * (GridConstants.BRIGHTNESS.MEDIUM - GridConstants.BRIGHTNESS.LOW))

      -- Draw 2x2 square in center gap (between keyboards)
      GridLayers.set(layers.ui, 8, 4, indicator_brightness)
      GridLayers.set(layers.ui, 9, 4, indicator_brightness)
      GridLayers.set(layers.ui, 8, 5, indicator_brightness)
      GridLayers.set(layers.ui, 9, 5, indicator_brightness)
    end

    -- Draw clear button with hold feedback
    local clear_brightness = GridConstants.BRIGHTNESS.UI.NORMAL
    if clear_key_state.is_pressed then
      clear_brightness = GridConstants.BRIGHTNESS.UI.FOCUSED

      local press_duration = util.time() - clear_key_state.press_time
      local threshold_reached = press_duration >= CLEAR_LONG_PRESS_TIME

      local keyboard_brightness
      if threshold_reached then
        local time_since_threshold = press_duration - CLEAR_LONG_PRESS_TIME
        local pulse_rate = 4
        local pulse_duration = 1 / pulse_rate
        local pulses_completed = time_since_threshold / pulse_duration

        if pulses_completed < 3 then
          local phase = (clock.get_beats() * pulse_rate) % 1
          local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
          keyboard_brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
        else
          keyboard_brightness = GridConstants.BRIGHTNESS.FULL
        end
      else
        keyboard_brightness = GridConstants.BRIGHTNESS.MEDIUM
      end

      -- Illuminate both keyboards
      for kx = left.x, left.x + left.width - 1 do
        for ky = left.y, left.y + left.height - 1 do
          GridLayers.set(layers.response, kx, ky, keyboard_brightness)
        end
      end
      for kx = right.x, right.x + right.width - 1 do
        for ky = right.y, right.y + right.height - 1 do
          GridLayers.set(layers.response, kx, ky, keyboard_brightness)
        end
      end
    end
    GridLayers.set(layers.ui, layout.clear_button.x, layout.clear_button.y, clear_brightness)
  end

  grid_ui.draw_motif_events = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]

    local active_positions = focused_lane:get_active_positions()

    for _, pos in ipairs(active_positions) do
      if self:contains(pos.x, pos.y) then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.UI.ACTIVE)
      end
    end

    if _seeker.midi_input then
      local midi_positions = _seeker.midi_input.get_active_positions()
      for _, pos in ipairs(midi_positions) do
        if self:contains(pos.x, pos.y) then
          GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.FULL)
        end
      end
    end
  end

  grid_ui.handle_key = function(self, x, y, z)
    -- Octave buttons
    if is_octave_button(x, y) then
      handle_octave_button(x, y, z)
      return
    end

    -- Record button
    if x == layout.record_button.x and y == layout.record_button.y then
      handle_record_button(x, y, z)
      return
    end

    -- Clear button
    if x == layout.clear_button.x and y == layout.clear_button.y then
      handle_clear_button(x, y, z)
      return
    end

    -- Keyboard notes
    if in_keyboard_area(x, y) then
      if z == 1 then
        note_on(x, y)
      else
        note_off(x, y)
      end
    end
  end

  -- Expose helper for external use
  grid_ui.note_to_positions = note_to_positions

  return grid_ui
end

function DualTapeKeyboard.init()
  local component = {
    grid = create_grid_ui()
  }

  return component
end

return DualTapeKeyboard

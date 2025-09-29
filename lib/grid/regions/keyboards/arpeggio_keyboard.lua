-- arpeggio_keyboard.lua
-- Step sequencer keyboard for arpeggio sequencer mode
-- Grid layout adapts to the number of steps parameter

local theory = include("lib/theory_utils")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")

local ArpeggioKeyboard = {}

-- Step state tracking - organized by lane
ArpeggioKeyboard.step_states = {}

-- Initialize step states for a lane
function ArpeggioKeyboard.init_lane_steps(lane_id)
  if not ArpeggioKeyboard.step_states[lane_id] then
    ArpeggioKeyboard.step_states[lane_id] = {}
  end
end

-- Get step state for a specific lane and step
-- Returns: 0 = off, 1 = on, 2 = accent
function ArpeggioKeyboard.get_step_state(lane_id, step)
  ArpeggioKeyboard.init_lane_steps(lane_id)
  return ArpeggioKeyboard.step_states[lane_id][step] or 0
end

-- Check if step is active (on or accent)
function ArpeggioKeyboard.is_step_active(lane_id, step)
  return ArpeggioKeyboard.get_step_state(lane_id, step) > 0
end

-- Toggle step state through three states: off -> on -> accent -> off
function ArpeggioKeyboard.toggle_step(lane_id, step)
  ArpeggioKeyboard.init_lane_steps(lane_id)
  local current_state = ArpeggioKeyboard.step_states[lane_id][step] or 0
  local new_state = (current_state + 1) % 3
  ArpeggioKeyboard.step_states[lane_id][step] = new_state
  return new_state
end

-- Get velocity for a step based on its state
function ArpeggioKeyboard.get_step_velocity(lane_id, step)
  local state = ArpeggioKeyboard.get_step_state(lane_id, step)
  if state == 1 then -- Normal
    return params:get("lane_" .. lane_id .. "_arpeggio_normal_velocity")
  elseif state == 2 then -- Accent
    return params:get("lane_" .. lane_id .. "_arpeggio_accent_velocity")
  else -- Off
    return 0
  end
end

-- Clear all steps for a lane
function ArpeggioKeyboard.clear_lane_steps(lane_id)
  ArpeggioKeyboard.step_states[lane_id] = {}
end

-- Dynamic layout based on step count parameter
function ArpeggioKeyboard.get_layout()
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local num_steps = params:get("lane_" .. focused_lane .. "_arpeggio_num_steps")

  -- Fixed width of 6 columns, variable height based on steps
  local width = 6
  local height = math.ceil(num_steps / width)

  -- Fixed horizontal position, vertically centered
  local start_x = 6
  local start_y = 2 + math.floor((6 - height) / 2)

  return {
    upper_left_x = start_x,
    upper_left_y = start_y,
    width = width,
    height = height,
    num_steps = num_steps
  }
end

-- Static layout property for compatibility
ArpeggioKeyboard.layout = ArpeggioKeyboard.get_layout()

-- Check if coordinates are within trigger keyboard area
function ArpeggioKeyboard.contains(x, y)
  local layout = ArpeggioKeyboard.get_layout()
  return x >= layout.upper_left_x and 
         x < layout.upper_left_x + layout.width and
         y >= layout.upper_left_y and 
         y < layout.upper_left_y + layout.height
end

-- Convert grid coordinates to step number
function ArpeggioKeyboard.grid_to_step(x, y)
  local layout = ArpeggioKeyboard.get_layout()
  local rel_x = x - layout.upper_left_x
  local rel_y = y - layout.upper_left_y
  local step = rel_y * layout.width + rel_x + 1
  
  if step <= layout.num_steps then
    return step
  end
  return nil
end

-- Convert step number back to grid coordinates
function ArpeggioKeyboard.step_to_grid(step)
  local layout = ArpeggioKeyboard.get_layout()
  if step < 1 or step > layout.num_steps then
    return nil
  end
  
  local zero_based_step = step - 1
  local rel_y = math.floor(zero_based_step / layout.width)
  local rel_x = zero_based_step % layout.width
  
  return {
    x = layout.upper_left_x + rel_x,
    y = layout.upper_left_y + rel_y
  }
end

-- Get the MIDI note for a step (uses chord parameters)
function ArpeggioKeyboard.step_to_note(step)
  -- This function is maintained for compatibility, but actual chord generation
  -- happens during motif regeneration. For preview purposes, return root note.
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local chord_root = params:get("lane_" .. focused_lane .. "_arpeggio_chord_root")
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")

  -- Return root note for preview (actual chord arpeggiation happens in motif regeneration)
  return (octave + 1) * 12 + (chord_root - 1)
end

-- Create a standardized note event
function ArpeggioKeyboard.create_note_event(x, y, step, velocity)
  local note = ArpeggioKeyboard.step_to_note(step)
  local positions = {{x = x, y = y}} -- Only one position per step
  
  return {
    note = note,
    velocity = velocity or 0,
    x = x,
    y = y,
    step = step, -- Add step info for trigger sequencer
    positions = positions,
    is_playback = false,
    source = "grid"
  }
end

-- Handle step trigger (note on)
function ArpeggioKeyboard.note_on(x, y)
  local step = ArpeggioKeyboard.grid_to_step(x, y)
  if step then
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local focused_lane = _seeker.lanes[focused_lane_id]


    -- When not recording, toggle step state for programming
    if not _seeker.motif_recorder.is_recording then
      local new_state = ArpeggioKeyboard.toggle_step(focused_lane_id, step)
      local state_names = {"OFF", "ON", "ACCENT"}
      print(string.format("Step %d %s at (%d,%d)", step, state_names[new_state + 1], x, y))
      return
    end

    -- When recording, send note events (for recording conversion)
    print(string.format("Recording trigger step %d at (%d,%d)", step, x, y))

    -- Get velocity from velocity region
    local velocity_region = include("lib/grid/regions/velocity_region")
    local event = ArpeggioKeyboard.create_note_event(x, y, step, velocity_region.get_current_velocity())

    _seeker.motif_recorder:on_note_on(event)
    focused_lane:on_note_on(event)
  end
end

-- Handle step release (note off)
function ArpeggioKeyboard.note_off(x, y)
  local step = ArpeggioKeyboard.grid_to_step(x, y)
  if step then
    -- When not recording, do nothing (steps are toggled on press)
    if not _seeker.motif_recorder.is_recording then
      return
    end

    -- When recording, send note_off events
    local focused_lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local event = ArpeggioKeyboard.create_note_event(x, y, step, 0)

    _seeker.motif_recorder:on_note_off(event)
    focused_lane:on_note_off(event)
  end
end

-- Handle key presses
function ArpeggioKeyboard.handle_key(x, y, z)
  if z == 1 then
    ArpeggioKeyboard.note_on(x, y)
  else
    ArpeggioKeyboard.note_off(x, y)
  end
end

-- Draw the step sequencer grid
function ArpeggioKeyboard.draw(layers)
  local layout = ArpeggioKeyboard.get_layout()
  local focused_lane_id = _seeker.ui_state.get_focused_lane()

  for step = 1, layout.num_steps do
    local pos = ArpeggioKeyboard.step_to_grid(step)
    if pos then
      -- Show different brightness levels for each state
      local state = ArpeggioKeyboard.get_step_state(focused_lane_id, step)
      local brightness
      if state == 0 then -- Off
        brightness = GridConstants.BRIGHTNESS.LOW
      elseif state == 1 then -- On
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      else -- Accent (state == 2)
        brightness = GridConstants.BRIGHTNESS.HIGH
      end
      GridLayers.set(layers.ui, pos.x, pos.y, brightness)
    end
  end
end

-- Draw motif events for active steps
function ArpeggioKeyboard.draw_motif_events(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  -- Get active positions from focused lane
  local active_positions = focused_lane:get_active_positions()

  -- Illuminate active positions at playback brightness
  for _, pos in ipairs(active_positions) do
    if ArpeggioKeyboard.contains(pos.x, pos.y) then
      GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.CONTROLS.PLAY_ACTIVE)
    end
  end
  
  -- Draw MIDI input notes if available
  if _seeker.midi_input then
    local midi_positions = _seeker.midi_input.get_active_positions()
    for _, pos in ipairs(midi_positions) do
      if ArpeggioKeyboard.contains(pos.x, pos.y) then
        GridLayers.set(layers.response, pos.x, pos.y, GridConstants.BRIGHTNESS.CONTROLS.PLAY_ACTIVE)
      end
    end
  end
end

return ArpeggioKeyboard
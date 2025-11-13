-- arpeggio_keyboard.lua
-- Piano roll visualization for arpeggio sequencer mode
-- Shows windowed view of pattern with relative pitch mapping

local theory = include("lib/theory_utils")
local musicutil = require('musicutil')
local GridConstants = include("lib/grid_constants")
local GridLayers = include("lib/grid_layers")
local arpeggio_utils = include("lib/arpeggio_utils")

local ArpeggioKeyboard = {}

-- Get step state - all steps are active by default
-- Returns: 1 = on
function ArpeggioKeyboard.get_step_state(lane_id, step)
  return 1 -- All steps are always on
end

-- Check if step is active
function ArpeggioKeyboard.is_step_active(lane_id, step)
  return true -- All steps are always active
end

-- Get velocity for a step
function ArpeggioKeyboard.get_step_velocity(lane_id, step)
  return params:get("lane_" .. lane_id .. "_arpeggio_normal_velocity")
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

-- Find all grid positions for a given MIDI note
-- Arpeggio keyboard doesn't illuminate by note, so return nil
function ArpeggioKeyboard.note_to_positions(note)
  return nil
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

-- Grid is read-only for arpeggio mode - all programming via params
function ArpeggioKeyboard.handle_key(x, y, z)
  -- No interaction - visualization only
end

-- Draw the piano roll visualization
function ArpeggioKeyboard.draw(layers)
  local layout = ArpeggioKeyboard.get_layout()
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  -- Get motif to calculate note mapping
  local motif = focused_lane and focused_lane.motif
  if not motif or not motif.events or #motif.events == 0 then
    -- No motif yet, show blank grid
    return
  end

  -- Get current playback position (which step)
  local current_step = ArpeggioKeyboard._get_current_playback_step(focused_lane)

  -- Get number of steps from params
  local num_steps = params:get("lane_" .. focused_lane_id .. "_arpeggio_num_steps")

  -- Calculate windowed step indices
  local window_steps = arpeggio_utils.calculate_step_window(current_step, num_steps, layout.width)

  -- Collect notes from motif events for pitch range calculation
  local step_notes = {}  -- step_notes[step] = MIDI note
  for _, event in ipairs(motif.events) do
    if event.type == "note_on" and event.step then
      step_notes[event.step] = event.note
    end
  end

  -- Find min/max notes in window
  local min_note, max_note = nil, nil
  for _, step in ipairs(window_steps) do
    local note = step_notes[step]
    if note then
      if not min_note or note < min_note then
        min_note = note
      end
      if not max_note or note > max_note then
        max_note = note
      end
    end
  end

  -- Draw each step in the window
  for col_index, step in ipairs(window_steps) do
    local note = step_notes[step]
    if note and min_note and max_note then
      -- Map note to row (1-6)
      local row = arpeggio_utils.map_note_to_row(note, min_note, max_note)

      -- Calculate grid position
      local grid_x = layout.upper_left_x + (col_index - 1)
      local grid_y = layout.upper_left_y + (layout.height - row)  -- Invert Y (row 1 = bottom)

      -- Get step state for brightness
      local state = ArpeggioKeyboard.get_step_state(focused_lane_id, step)
      local brightness
      if state == 0 then -- Off (shouldn't happen if note exists, but safety)
        brightness = GridConstants.BRIGHTNESS.LOW
      elseif state == 1 then -- On
        brightness = GridConstants.BRIGHTNESS.MEDIUM
      else -- Accent (state == 2)
        brightness = GridConstants.BRIGHTNESS.HIGH
      end

      GridLayers.set(layers.ui, grid_x, grid_y, brightness)
    end
  end
end

-- Helper to get current playback step
function ArpeggioKeyboard._get_current_playback_step(lane)
  if not lane or not lane.playing or not lane.motif then
    return 1  -- Default to step 1 if not playing
  end

  -- Get current stage timing
  local current_stage = lane.stages[lane.current_stage_index]
  if not current_stage or not current_stage.last_start_time then
    return 1
  end

  -- Calculate elapsed time
  local now = clock.get_beats()
  local elapsed_time = (now - current_stage.last_start_time) * lane.speed

  -- Calculate position within motif
  local motif_duration = lane.motif.duration
  if motif_duration <= 0 then
    return 1
  end

  local position_in_motif = elapsed_time % motif_duration

  -- Get step length
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local step_length_str = params:string("lane_" .. focused_lane_id .. "_arpeggio_step_length")
  local step_length = ArpeggioKeyboard._interval_to_beats(step_length_str)

  if step_length <= 0 then
    return 1
  end

  -- Calculate current step (1-based)
  local current_step = math.floor(position_in_motif / step_length) + 1

  -- Get num_steps and wrap
  local num_steps = params:get("lane_" .. focused_lane_id .. "_arpeggio_num_steps")
  current_step = ((current_step - 1) % num_steps) + 1

  return current_step
end

-- Helper to convert interval string to beats
function ArpeggioKeyboard._interval_to_beats(interval_str)
  if tonumber(interval_str) then
    return tonumber(interval_str)
  end
  local num, den = interval_str:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num) / tonumber(den)
  end
  return 1/8
end

-- Draw motif events for active steps (piano roll playback visualization)
function ArpeggioKeyboard.draw_motif_events(layers)
  local layout = ArpeggioKeyboard.get_layout()
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local focused_lane = _seeker.lanes[focused_lane_id]

  if not focused_lane or not focused_lane.motif or #focused_lane.motif.events == 0 then
    return
  end

  -- Get current playback position
  local current_step = ArpeggioKeyboard._get_current_playback_step(focused_lane)
  local num_steps = params:get("lane_" .. focused_lane_id .. "_arpeggio_num_steps")

  -- Calculate windowed step indices
  local window_steps = arpeggio_utils.calculate_step_window(current_step, num_steps, layout.width)

  -- Collect notes from motif events
  local step_notes = {}
  for _, event in ipairs(focused_lane.motif.events) do
    if event.type == "note_on" and event.step then
      step_notes[event.step] = event.note
    end
  end

  -- Find min/max notes in window
  local min_note, max_note = nil, nil
  for _, step in ipairs(window_steps) do
    local note = step_notes[step]
    if note then
      if not min_note or note < min_note then
        min_note = note
      end
      if not max_note or note > max_note then
        max_note = note
      end
    end
  end

  -- Get active positions from lane (currently playing notes)
  local active_positions = focused_lane:get_active_positions()

  -- Create lookup table of active steps from positions
  local active_steps_lookup = {}
  for _, pos in ipairs(active_positions) do
    -- Find which step this position corresponds to in current motif
    for _, event in ipairs(focused_lane.motif.events) do
      if event.type == "note_on" and event.x == pos.x and event.y == pos.y and event.step then
        active_steps_lookup[event.step] = true
      end
    end
  end

  -- Draw currently active steps with full brightness
  for col_index, step in ipairs(window_steps) do
    if active_steps_lookup[step] then
      local note = step_notes[step]
      if note and min_note and max_note then
        -- Map note to row
        local row = arpeggio_utils.map_note_to_row(note, min_note, max_note)

        -- Calculate grid position
        local grid_x = layout.upper_left_x + (col_index - 1)
        local grid_y = layout.upper_left_y + (layout.height - row)

        -- Full brightness for active playback
        GridLayers.set(layers.response, grid_x, grid_y, GridConstants.BRIGHTNESS.FULL)
      end
    end
  end
end

return ArpeggioKeyboard
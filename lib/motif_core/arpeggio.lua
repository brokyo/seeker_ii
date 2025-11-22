-- arpeggio_utils.lua
-- Utility functions for arpeggio keyboard and transform

local musicutil = require('musicutil')

local ArpeggioUtils = {}

-- Convert scale degree (1-7) to semitone offset based on global scale
-- @param degree: Scale degree (1=I, 2=ii, 3=iii, 4=IV, 5=V, 6=vi, 7=vii°)
-- @param scale_type_index: Scale type index (from params:get("scale_type"))
-- @param root_note: Root note (1-12, where 1=C)
-- @return: Semitone offset from root
function ArpeggioUtils.scale_degree_to_semitones(degree, scale_type_index, root_note)
  -- Convert UI root note (1-12) to MIDI note (0-11)
  local root_midi = (root_note - 1) % 12

  -- Get scale from index
  local scale = musicutil.SCALES[scale_type_index]

  if not scale or not scale.intervals then
    print("ERROR: Invalid scale index: " .. scale_type_index)
    return 0
  end

  -- Clamp degree to valid range
  degree = math.max(1, math.min(7, degree))

  -- Get the interval for this scale degree (wrap if needed)
  local degree_index = ((degree - 1) % #scale.intervals) + 1
  local semitone_offset = scale.intervals[degree_index]

  return semitone_offset
end

-- Apply pattern preset filter to events
-- @param events: Table of note events with time, type, note, etc.
-- @param preset_name: Name of preset ("All", "Odds", "Evens", etc.)
-- @param num_steps: Total number of steps in the original pattern
-- @return: Filtered event list
function ArpeggioUtils.apply_pattern_preset(events, preset_name, num_steps)
  -- Build step filter based on preset
  local step_filter = {}

  if preset_name == "All" then
    -- No filtering
    for i = 1, num_steps do
      step_filter[i] = true
    end
  elseif preset_name == "Odds" then
    -- Steps 1, 3, 5, 7, 9, 11, ...
    for i = 1, num_steps, 2 do
      step_filter[i] = true
    end
  elseif preset_name == "Evens" then
    -- Steps 2, 4, 6, 8, 10, 12, ...
    for i = 2, num_steps, 2 do
      step_filter[i] = true
    end
  elseif preset_name == "Downbeats" then
    -- Steps 1, 5, 9, 13, ... (every 4th starting at 1)
    for i = 1, num_steps, 4 do
      step_filter[i] = true
    end
  elseif preset_name == "Upbeats" then
    -- Steps 3, 7, 11, 15, ... (every 4th starting at 3)
    for i = 3, num_steps, 4 do
      step_filter[i] = true
    end
  elseif preset_name == "Sparse" then
    -- Steps 1, 4, 7, 10, ... (every 3rd)
    for i = 1, num_steps, 3 do
      step_filter[i] = true
    end
  else
    -- Unknown preset, default to All
    print("WARNING: Unknown pattern preset: " .. preset_name .. ", using All")
    for i = 1, num_steps do
      step_filter[i] = true
    end
  end

  -- Filter events based on their step number
  -- Events have a 'step' field added during recording
  local filtered_events = {}
  for _, event in ipairs(events) do
    if event.step and step_filter[event.step] then
      table.insert(filtered_events, event)
    elseif not event.step then
      -- Events without step info (shouldn't happen for arpeggio) pass through
      table.insert(filtered_events, event)
    end
  end

  return filtered_events
end

-- Calculate relative pitch mapping for visualization
-- Maps MIDI note to grid row (1-6) based on min/max range
-- @param note: MIDI note number
-- @param min_note: Minimum note in range
-- @param max_note: Maximum note in range
-- @return: Grid row (1-6)
function ArpeggioUtils.map_note_to_row(note, min_note, max_note)
  -- Handle unison case
  if min_note == max_note then
    return 3  -- Center on row 3
  end

  -- Linear interpolation from min/max to rows 1-6
  local range = max_note - min_note
  local normalized = (note - min_note) / range

  -- Map to rows 1-6
  local row = math.floor(normalized * 5) + 1

  -- Clamp to valid range
  row = math.max(1, math.min(6, row))

  return row
end

-- Calculate windowed step indices centered on current step
-- @param current_step: Currently playing step number (1-based)
-- @param num_steps: Total number of steps in pattern
-- @param window_size: Size of window (default 6)
-- @return: Table of step numbers to display {step1, step2, ...}
function ArpeggioUtils.calculate_step_window(current_step, num_steps, window_size)
  window_size = window_size or 6

  -- If pattern is smaller than window, return all steps centered
  if num_steps <= window_size then
    local steps = {}
    for i = 1, num_steps do
      table.insert(steps, i)
    end
    return steps
  end

  -- Center window on current step (3 before, 3 after)
  local half_window = math.floor(window_size / 2)
  local start_step = current_step - half_window

  -- Build window with wrapping
  local steps = {}
  for i = 0, window_size - 1 do
    local step = start_step + i
    -- Wrap around pattern boundaries
    while step < 1 do
      step = step + num_steps
    end
    while step > num_steps do
      step = step - num_steps
    end
    table.insert(steps, step)
  end

  return steps
end

return ArpeggioUtils

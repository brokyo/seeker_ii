-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')

-- Create the theory utilities table
local theory = {}

-- Converts grid x,y coordinates to a MIDI note number using modal Tonnetz layout
-- The layout creates a grid where:
-- Root note is at bottom left (6,7)
-- All notes stay within the selected scale
function theory.grid_to_note(x, y, octave)
  local root = params:get("root_note")  -- Use 1-based root directly
  local scale_type = params:get("scale_type")
  
  -- Get tuning offset for current lane
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local grid_offset = params:get("lane_" .. focused_lane .. "_grid_offset")
  
  -- Calculate steps from root position
  local x_steps = (x - 6) * params:get("keyboard_column_steps")  -- Scale degrees per horizontal step
  local y_steps = (7 - y) * params:get("keyboard_row_steps")     -- Scale degrees per vertical step
  local total_steps = x_steps + y_steps + grid_offset
  
  -- Calculate the base MIDI note for the root in the specified octave
  local base_root_note = (octave + 1) * 12 + (root - 1)
  
  -- Generate scale starting from a low octave to ensure we have enough notes
  local root_midi = (root - 1)  -- Convert to 0-based for musicutil
  local scale = musicutil.generate_scale(root_midi, musicutil.SCALES[scale_type].name, 10)
  
  -- Find the base root note in our scale
  local root_index = nil
  for i, note in ipairs(scale) do
    if note >= base_root_note then
      root_index = i
      break
    end
  end
  
  -- If we couldn't find the root note, try the first occurrence that matches the pitch class
  if not root_index then
    print("Couldn't find root note in scale")
    -- local target_pitch_class = (root - 1) % 12
    -- for i, note in ipairs(scale) do
    --   if note % 12 == target_pitch_class and note >= base_root_note - 12 then
    --     root_index = i
    --     break
    --   end
    -- end
  end
  
  -- Get the note from our scale relative to the root position
  if root_index then
    local index = root_index + total_steps
    if index >= 1 and index <= #scale then
      return scale[index]
    end
  end
  
  return nil
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  
  -- Get root name directly from params option list
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root]
  
  -- Print header
  print(string.format("\n▓ Modal Tonnetz Layout (Lane %d) ▓", focused_lane))
  print(string.format("Root: %s | Scale: %s | Lane Octave: %d", 
    root_name,
    musicutil.SCALES[scale_type].name,
    octave))
  print(string.format("Column spacing: %d steps | Row spacing: %d steps", 
    params:get("keyboard_column_steps"), 
    params:get("keyboard_row_steps")))
  print("Root at bottom left (6,7)")
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Print note layout with actual MIDI note numbers and root highlighting
  for y = 2, 7 do  -- Print from top to bottom
    local row = string.format("y=%d: ", y)
    for x = 6, 11 do
      local note = theory.grid_to_note(x, y, octave)
      if note then
        local note_name = musicutil.note_num_to_name(note, true)
        local is_root = (note % 12) == ((root - 1) % 12)
        if is_root then
          row = row .. string.format("[%-4s]", note_name)  -- Brackets around root notes
        else
          row = row .. string.format("%-5s", note_name)
        end
      else
        row = row .. "---  "
      end
    end
    print(row)
  end
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
  print("Root notes shown in [brackets]")
end

-- Get an array of MIDI note numbers for the current scale
function theory.get_scale()
  local root = params:get("root_note")  -- Use 1-based root directly
  local scale_type = params:get("scale_type")
  -- musicutil.generate_scale expects MIDI note numbers (0-based)
  return musicutil.generate_scale(root - 1, musicutil.SCALES[scale_type].name, 10)
end

-- Find all valid grid positions for a given MIDI note within a specific octave context
-- The octave parameter is necessary because the grid layout changes based on the chosen octave
-- For example, the same MIDI note might appear in different grid positions depending on the octave context
-- 
-- Parameters:
--   note: MIDI note number (e.g., 60 for middle C)
--   octave: The octave number that defines the scale mapping for the grid
--
-- Returns: Array of {x, y} positions where this note appears
function theory.note_to_grid(note, octave)
  -- If octave not provided, get it from the params
  if not octave then
    octave = params:get("lane_" .. _seeker.ui_state.state.focused_lane .. "_keyboard_octave")
  end
  
  local positions = {}
  
  -- Search through the keyboard region
  for y = 7, 2, -1 do  -- Bottom to top (7 to 2)
    for x = 6, 11 do   -- Left to right (6 to 11)
      local grid_note = theory.grid_to_note(x, y, octave)
      if grid_note == note then
        table.insert(positions, {x = x, y = y})
      end
    end
  end
  
  return #positions > 0 and positions or nil
end

-- Generate scale-based chord root options
local function get_scale_chord_roots()
    local root_note = params:get("root_note") - 1  -- Convert to 0-based for musicutil
    local scale_type = params:get("scale_type")
    local scale_name = musicutil.SCALES[scale_type].name

    -- Generate scale notes for just 1 octave
    local scale_notes = musicutil.generate_scale(root_note, scale_name, 1)

    -- Convert to note names
    local note_names = {}
    for _, note_num in ipairs(scale_notes) do
        local note_name = musicutil.note_num_to_name(note_num, false) -- No octave
        table.insert(note_names, note_name)
    end

    return note_names
end

-- Update all composer chord root parameters with current scale
function theory.update_chord_root_options()
    local chord_roots = get_scale_chord_roots()

    for i = 1, 8 do
        local param_id = "lane_" .. i .. "_composer_chord_root"
        local param = params:lookup_param(param_id)
        if param then
            -- Update parameter options directly
            param.options = chord_roots
            param.count = #chord_roots
            -- Reset to first option
            params:set(param_id, 1)
        end
    end
end

-- Get scale-based chord root options (for initial parameter creation)
function theory.get_scale_chord_roots()
    return get_scale_chord_roots()
end

-- Get scale degrees as semitone offsets for two octaves (one below, one above root)
-- Returns array of semitone values like {-12, -10, -8, -7, -5, -3, -1, 0, 2, 4, 5, 7, 9, 11, 12}
function theory.get_pitch_offsets()
  local scale_type = params:get("scale_type")
  local scale_intervals = musicutil.SCALES[scale_type].intervals

  local offsets = {}

  -- One octave below (negative)
  for i = #scale_intervals, 1, -1 do
    if scale_intervals[i] > 0 then
      table.insert(offsets, scale_intervals[i] - 12)
    end
  end

  -- Root octave
  for _, interval in ipairs(scale_intervals) do
    table.insert(offsets, interval)
  end

  -- One octave above
  for _, interval in ipairs(scale_intervals) do
    if interval > 0 then
      table.insert(offsets, interval + 12)
    end
  end

  table.sort(offsets)
  return offsets
end

-- Convert semitone offset to display string (e.g., "0", "+7", "-12")
function theory.offset_to_display(semitones)
  if semitones == 0 then
    return "0"
  elseif semitones > 0 then
    return "+" .. semitones
  else
    return tostring(semitones)
  end
end

return theory
-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')

-- Create the theory utilities table
local theory = {}

-- Converts grid x,y coordinates to a MIDI note number using modal Tonnetz layout
-- The layout creates a grid where:
-- - Root note is at bottom left (6,7)
-- - Moving right: up a third in the current scale (2 scale degrees)
-- - Moving up (lower y): up a second in the current scale (1 scale degree)
-- - All notes stay within the selected scale
function theory.grid_to_note(x, y, octave)
  local root = params:get("root_note")  -- Use 1-based root directly
  local scale_type = params:get("scale_type")
  
  -- Generate a table of MIDI notes for the entire MIDI range
  -- Start at MIDI note 0 (C-1) and generate enough notes to cover the full range
  local scale = musicutil.generate_scale(0, musicutil.SCALES[scale_type].name, 128)
  
  -- Get grid offset for current lane
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local grid_offset = params:get("lane_" .. focused_lane .. "_grid_offset")
  
  -- Calculate steps from root position
  local x_steps = (x - 6) * 2  -- Two scale degrees per horizontal step
  local y_steps = (7 - y)      -- One scale degree per vertical step
  local total_steps = x_steps + y_steps + grid_offset
  
  -- Find the root note index in our scale table
  local root_index = 1
  for i, note in ipairs(scale) do
    if note >= (octave * 12 + (root - 1)) then
      root_index = i
      break
    end
  end
  
  -- Get the note from our table relative to the root position
  local index = root_index + total_steps
  if index >= 1 and index <= #scale then
    return scale[index]
  end
  return nil
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.state.focused_lane
  local octave = params:get("lane_" .. focused_lane .. "_keyboard_octave")
  
  -- Get root name directly from params option list
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root]
  
  -- Print header
  -- print(string.format("\n▓ Modal Tonnetz Layout (Lane %d) ▓", focused_lane))
  -- print(string.format("Root: %s | Scale: %s | Lane Octave: %d", 
  --   root_name,
  --   musicutil.SCALES[scale_type].name,
  --   octave))
  -- print("Moving right = up a third in scale")
  -- print("Moving up = up in pitch")
  -- print("Root at bottom left (6,7)")
  -- print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Print note layout with actual MIDI note numbers in parentheses
  -- for y = 2, 7 do  -- Print from top to bottom
  --   local row = string.format("y=%d: ", y)
  --   for x = 6, 11 do
  --     local note = theory.grid_to_note(x, y, octave)
  --     if note then
  --       local note_name = musicutil.note_num_to_name(note, true)
  --       row = row .. string.format("%-5s", note_name)
  --     else
  --       row = row .. "---  "
  --     end
  --   end
  --   print(row)
  -- end
  -- print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
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

return theory
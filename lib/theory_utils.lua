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
  local scale = musicutil.SCALES[scale_type].intervals
  local scale_length = #scale
  
  -- Get grid offset for current lane
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local grid_offset = params:get("lane_" .. focused_lane .. "_grid_offset")
  
  -- Calculate scale degree offsets
  -- Moving right: up by thirds (2 scale degrees)
  local x_scale_steps = (x - 6) * 2    -- Each step right moves up two scale degrees (a third)
  -- Moving up: up by seconds (1 scale degree)
  local y_scale_steps = (7 - y)        -- Each step up moves up one scale degree
  
  -- Add grid offset to total steps
  local total_scale_steps = x_scale_steps + y_scale_steps + grid_offset
  
  -- Calculate position in scale (1-based)
  local scale_position = ((total_scale_steps % scale_length) + scale_length) % scale_length + 1
  
  -- Calculate octave offset based on how many complete scales we've moved through
  local octave_offset = math.floor(total_scale_steps / scale_length)
  
  -- Calculate base MIDI note (applying octave after scale position is calculated)
  local base_midi = (octave * 12) + (root - 1)  -- Adjust for 0-based MIDI notes here
  
  -- Get the interval from our scale for this position
  local interval = scale[scale_position]
  
  -- Calculate final MIDI note
  return base_midi + interval + (octave_offset * 12)
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.state.focused_lane
  local octave = params:get("lane_" .. focused_lane .. "_octave")
  
  -- Get root name directly from params option list
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root]
  
  -- Print header
  print(string.format("\n▓ Modal Tonnetz Layout (Lane %d) ▓", focused_lane))
  print(string.format("Root: %s | Scale: %s | Lane Octave: %d", 
    root_name,
    musicutil.SCALES[scale_type].name,
    octave))
  print("Moving right = up a third in scale")
  print("Moving up = up in pitch")
  print("Root at bottom left (6,7)")
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Print note layout with actual MIDI note numbers in parentheses
  for y = 2, 7 do  -- Print from top to bottom
    local row = string.format("y=%d: ", y)
    for x = 6, 11 do
      local note = theory.grid_to_note(x, y, octave)
      if note then
        local note_name = musicutil.note_num_to_name(note, true)
        row = row .. string.format("%-5s", note_name)
      else
        row = row .. "---  "
      end
    end
    print(row)
  end
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
end

-- Get an array of MIDI note numbers for the current scale
function theory.get_scale()
  local root = params:get("root_note")  -- Use 1-based root directly
  local scale_type = params:get("scale_type")
  -- musicutil.generate_scale expects MIDI note numbers (0-based)
  return musicutil.generate_scale(root - 1, musicutil.SCALES[scale_type].name, 10)
end

-- Find the first valid grid position for a given MIDI note
-- Returns {x, y} if found, nil if not found
function theory.note_to_grid(note)
  -- Search through the keyboard region
  for y = 7, 2, -1 do  -- Bottom to top (7 to 2)
    for x = 6, 11 do   -- Left to right (6 to 11)
      local octave = params:get("lane_" .. _seeker.ui_state.state.focused_lane .. "_octave")
      local grid_note = theory.grid_to_note(x, y, octave)
      if grid_note == note then
        return {x = x, y = y}
      end
    end
  end
  return nil
end

return theory
-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')

-- Create the theory utilities table
local theory = {}

-- Converts grid x,y coordinates to a MIDI note number using modal Tonnetz layout
-- Moving right = up a third in the scale
-- Moving up (lower y) = up in pitch
function theory.grid_to_note(x, y, octave)
  
  local root = params:get("root_note") - 1  -- Convert 1-based index to 0-based
  local scale_type = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type].intervals
  local scale_length = #scale
  
  -- Calculate base MIDI note
  local base_midi = (octave * 12) + root
  
  -- Calculate scale degree offsets
  local x_scale_steps = (x - 6) * 2    -- Each step right from x=6 moves up two scale degrees
  local y_scale_steps = (7 - y)        -- Each step up from y=7 moves up one scale degree
  
  -- Combine steps and handle wrapping within scale
  local total_scale_steps = x_scale_steps + y_scale_steps
  
  -- Calculate position in scale (1-based)
  local scale_position = ((total_scale_steps % scale_length) + scale_length) % scale_length + 1
  
  -- Calculate octave offset based on how many complete scales we've moved through
  -- Divide by scale_length and round down to get complete octaves
  local octave_offset = math.floor(total_scale_steps / scale_length) + 2  -- +2 to compensate for scale degree math
  
  -- Get the interval from our scale for this position
  local interval = scale[scale_position]
  
  -- Calculate final MIDI note
  return base_midi + interval + (octave_offset * 12)
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local focused_lane = _seeker.ui_state.focused_lane
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

return theory
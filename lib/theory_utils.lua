-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')
local params_manager = include('/lib/params_manager')

-- Create the theory utilities table
local theory = {}

-- Interval definitions (semitones from root)
-- Maps grid position offsets (-4 to +4) to musical intervals
theory.INTERVALS = {
  [-4] = { semitones = 5, name = 'P4' },  -- Perfect 4th
  [-3] = { semitones = 3, name = 'm3' },  -- Minor 3rd
  [-2] = { semitones = 2, name = 'M2' },  -- Major 2nd
  [-1] = { semitones = 1, name = 'm2' },  -- Minor 2nd
  [0]  = { semitones = 0, name = 'Root' },
  [1]  = { semitones = 1, name = 'm2' },  -- Minor 2nd
  [2]  = { semitones = 2, name = 'M2' },  -- Major 2nd
  [3]  = { semitones = 4, name = 'M3' },  -- Major 3rd
  [4]  = { semitones = 7, name = 'P5' }   -- Perfect 5th
}

-- Converts grid x,y coordinates to a MIDI note number using modal Tonnetz layout
-- Moving right = up a third in the scale
-- Moving down = up a second in the scale
function theory.grid_to_note(x, y)
  local root = params:get("root_note") - 1  -- Convert 1-based index to 0-based
  local octave = theory.get_octave()
  local scale_type = params:get("scale_type")
  
  -- Calculate base MIDI note using the octave parameter
  local base_midi = (octave * 12) + root  -- octave * 12 gives us the octave offset
  
  -- Get scale intervals for the current scale
  local scale = musicutil.SCALES[scale_type].intervals
  local scale_length = #scale
  
  -- Calculate position in scale
  local thirds = (x - 1) * 2  -- Skip one scale degree each column
  local seconds = (6 - y)     -- Invert y coordinate and move up one scale degree each row
  
  -- Combined movement through scale (wrap around using modulo)
  local scale_position = ((thirds + seconds) % scale_length) + 1
  
  -- Calculate octave shifts based on how many times we've wrapped around the scale
  local octave_shift = math.floor((thirds + seconds) / scale_length)
  
  -- Get the actual interval from our scale
  local interval = scale[scale_position]
  
  -- Calculate final MIDI note
  local midi_note = base_midi + interval + (octave_shift * 12)
  
  return midi_note
end

-- Get the importance of a position in the current scale
-- Used for visual feedback on the grid
-- Highlights root note positions in the Tonnetz layout
function theory.get_interval_importance(x, y)
  -- Root notes appear in a diagonal pattern
  -- Check if this position is a root note in the Tonnetz
  if (x == 1 and y == 6) or    -- Bottom left
     (x == 5 and y == 6) or    -- Bottom right
     (x == 4 and y == 4) or    -- Middle right
     (x == 3 and y == 3) or    -- Upper middle
     (x == 3 and y == 2) or    -- Upper middle
     (x == 2 and y == 1) or    -- Top left
     (x == 6 and y == 1) then  -- Top right
    return 'primary'
  else
    return 'secondary'
  end
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local octave = theory.get_octave()
  
  -- Get root name directly from params option list
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root]
  
  -- Print header
  print(string.format("\n▓ Modal Tonnetz Layout ▓"))
  print(string.format("Root: %s | Scale: %s | Base Octave: %d", 
    root_name,
    musicutil.SCALES[scale_type].name,
    octave))
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Print note layout
  for y = 1, 6 do
    local row = ""
    for x = 1, 6 do
      local note = theory.grid_to_note(x, y)
      if note then
        row = row .. string.format("%-4s", musicutil.note_num_to_name(note, true))
      else
        row = row .. "--- "
      end
    end
    print(row)
    
    -- Add spacing between pairs of rows for better readability
    if y % 2 == 0 then print("") end
  end
  
  -- Print movement guide
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
  print("→ = Up a third in scale")
  print("↓ = Up a second in scale")
  print("")
end

-- Get the chord type for a given scale degree
-- Returns the appropriate chord type based on the current scale and degree
function theory.get_chord_type_for_degree(scale_type, degree)
  -- Get scale intervals
  local scale = musicutil.SCALES[scale_type].intervals
  
  -- For Mixolydian: I, ii, iii, IV, v, vi°, bVII
  -- For Major: I, ii, iii, IV, V, vi, vii°
  -- For Minor: i, ii°, III, iv, v, VI, VII
  local chord_qualities = {
    major = {"Major", "Minor", "Minor", "Major", "Major", "Minor", "Diminished"},
    minor = {"Minor", "Diminished", "Major", "Minor", "Minor", "Major", "Major"},
    mixolydian = {"Major", "Minor", "Minor", "Major", "Minor", "Diminished", "Major"},
    dorian = {"Minor", "Minor", "Major", "Major", "Minor", "Diminished", "Minor"},
    phrygian = {"Minor", "Major", "Major", "Minor", "Diminished", "Major", "Minor"},
    lydian = {"Major", "Major", "Minor", "Diminished", "Major", "Minor", "Minor"},
    locrian = {"Diminished", "Major", "Minor", "Minor", "Major", "Major", "Minor"}
  }
  
  -- Get scale name in lowercase
  local scale_name = musicutil.SCALES[scale_type].name:lower()
  local qualities = chord_qualities[scale_name]
  
  if qualities then
    return qualities[degree]
  end
  
  -- Default to major if we don't have specific qualities for this scale
  return "Major"
end

-- Maps importance levels to grid LED brightness values
function theory.importance_to_brightness(importance, brightness_levels)
  if importance == 'primary' then
    return brightness_levels.high
  elseif importance == 'secondary' then
    return brightness_levels.medium
  else
    return brightness_levels.low
  end
end

-- Converts a MIDI note number to a note name with octave
function theory.note_to_name(note)
  return musicutil.note_num_to_name(note, true)  -- true to include octave
end

-- Get the current octave setting for the focused lane
function theory.get_octave()
  local lane = _seeker.conductor.lanes[_seeker.focused_lane]
  return lane:get_param("octave")
end

return theory 
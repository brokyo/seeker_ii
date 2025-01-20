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

-- Debug utility to visualize the current keyboard layout
-- Prints MIDI note numbers and note names for each grid position
function theory.print_keyboard_layout()
  local root_note = params:get("root_note")
  local scale_type = params:get("scale_type")
  local octave = theory.get_octave()
  
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root_note]
  
  print(string.format("\nKeyboard Layout for %s in %s (base octave: %d):", 
    root_name,
    musicutil.SCALES[scale_type].name,
    octave))
    
  for y = 6, 8 do
    local row = ""
    local note_names = ""
    for x = 4, 12 do
      local note = theory.grid_to_note(x, y)
      if note then
        row = row .. string.format("%3d ", note)
        note_names = note_names .. string.format("%4s ", musicutil.note_num_to_name(note, true))
      else
        row = row .. "nil "
        note_names = note_names .. " nil "
      end
    end
    print("Row " .. y .. " MIDI: " .. row)
    print("Row " .. y .. " Note: " .. note_names)
  end
  print("")
end

-- Determines how important an interval is in the current scale
-- Used for visual feedback on the grid
-- Returns: 'primary' (root/fifth), 'secondary' (in scale), or 'tertiary' (chromatic)
function theory.get_interval_importance(interval, scale_index)
  local interval_def = theory.INTERVALS[interval]
  if not interval_def then return 'tertiary' end
  
  -- Root note and perfect intervals are primary
  if interval == 0 then return 'primary' end  
  if interval == 4 or interval == -4 then return 'primary' end  
  
  -- Check if interval exists in the current scale
  local scale = musicutil.SCALES[scale_index].intervals
  for _, scale_note in ipairs(scale) do
    if scale_note == interval_def.semitones then
      return 'secondary'
    end
  end
  
  return 'tertiary'
end

-- Converts grid x,y coordinates to a MIDI note number
-- Takes into account current root note, scale, and octave settings
function theory.grid_to_note(x, y)
  local root = (params:get("root_note") - 1)
  local octave = theory.get_octave()
  local root_midi = root + ((octave + 2) * 12)
  local scale_type = params:get("scale_type")
    
  -- Calculate octave offset based on grid row
  local octave_offset = 0
  if y == 6 then
    octave_offset = 12     -- Top row: +1 octave
  elseif y == 8 then
    octave_offset = -12    -- Bottom row: -1 octave
  end
  
  -- Generate two octaves of the scale starting from an octave below
  local scale_start = root_midi + octave_offset - 12
  local scale_notes = musicutil.generate_scale(scale_start, scale_type, 2)
    
  -- Map grid position to scale degree
  -- x=8 is the root note (middle of grid)
  local offset = x - 8
  local root_index = math.floor(#scale_notes/2) + 1
  local target_index = root_index + offset
  
  -- Ensure index stays within bounds
  if target_index < 1 then target_index = 1 end
  if target_index > #scale_notes then target_index = #scale_notes end
  
  return scale_notes[target_index]
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
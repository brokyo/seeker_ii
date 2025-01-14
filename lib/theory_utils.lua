-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')
local params_manager = include('/lib/params_manager')
local theory = {}

-- Interval definitions (semitones from root)
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

-- Debug function to print the entire keyboard layout
function theory.print_keyboard_layout()
  local root_note = params:get("root_note")
  local scale_type = params:get("scale_type")
  local base_octave = params:get("base_octave")
  
  -- Get root note name from the option value (1-12)
  local root_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_name = root_names[root_note]
  
  print(string.format("\nKeyboard Layout for %s in %s (base octave: %d):", 
    root_name,
    musicutil.SCALES[scale_type].name,
    base_octave))
    
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

-- Returns the importance level of an interval in the current scale
-- Returns: 'primary' (root/fifth), 'secondary' (in scale), or 'tertiary' (chromatic)
function theory.get_interval_importance(interval, scale_index)
  -- Get the interval definition
  local interval_def = theory.INTERVALS[interval]
  if not interval_def then return 'tertiary' end
  
  -- Special cases
  if interval == 0 then return 'primary' end  -- Root
  if interval == 4 or interval == -4 then return 'primary' end  -- Perfect 5th/4th
  
  -- Get the current scale's intervals
  local scale = musicutil.SCALES[scale_index].intervals
  
  -- Check if the interval's semitones are in the scale
  for _, scale_note in ipairs(scale) do
    if scale_note == interval_def.semitones then
      return 'secondary'
    end
  end
  
  return 'tertiary'
end

-- Converts grid coordinates to MIDI note number based on current musical parameters
function theory.grid_to_note(x, y)
  -- Get musical parameters from params
  local root_midi = params_manager.get_current_root_midi_note()
  local scale_type = params:get("scale_type")
  local base_octave = params:get("base_octave")
    
  -- Calculate octave offset based on row
  -- Row 6 is +1 octave, Row 8 is -1 octave from base
  local octave_offset = 0
  if y == 6 then
    octave_offset = 12
  elseif y == 8 then
    octave_offset = -12
  end
  
  -- Generate scale starting from an octave below
  local scale_start = root_midi + octave_offset - 12
  local scale_notes = musicutil.generate_scale(scale_start, scale_type, 2)
    
  -- x=8 is our root note, which should be in the middle of our scale
  -- Calculate offset from root (-4 to +4)
  local offset = x - 8
  
  -- The root note is at the start of the second octave
  local root_index = math.floor(#scale_notes/2) + 1
  local target_index = root_index + offset
  
  -- Ensure we stay within bounds
  if target_index < 1 then target_index = 1 end
  if target_index > #scale_notes then target_index = #scale_notes end
  
  local note = scale_notes[target_index]
  return note
end

-- Converts importance level to grid brightness
function theory.importance_to_brightness(importance, brightness_levels)
  if importance == 'primary' then
    return brightness_levels.high
  elseif importance == 'secondary' then
    return brightness_levels.medium
  else
    return brightness_levels.low
  end
end

return theory 
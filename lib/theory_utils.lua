-- theory_utils.lua
-- Handles musical theory calculations and relationships

local musicutil = require('musicutil')

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
  local octave = params:get("octave")

  -- TODO: There is an easier way to get a usable scale type.
  -- params:lookup_param("scale_type").options[params:get("scale_type")].
  local scale_type = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type].intervals
  local scale_length = #scale
  
  -- Calculate base MIDI note
  local base_midi = (octave * 12) + root
  
  -- Calculate scale degree offsets
  local x_scale_steps = (x - 1) * 2  -- Each step right moves up two scale degrees
  local y_scale_steps = (6 - y)      -- Each step down moves up one scale degree
  
  -- Combine steps and handle wrapping within scale
  local total_scale_steps = x_scale_steps + y_scale_steps
  local scale_position = (total_scale_steps % scale_length) + 1
  local octave_offset = math.floor(total_scale_steps / scale_length)
  
  -- Get the interval from our scale for this position
  local interval = scale[scale_position]
  
  -- Calculate final MIDI note
  return base_midi + interval + (octave_offset * 12)
end

-- Get the importance of a position in the current scale
-- Used for visual feedback on the grid
-- Highlights root note positions in the Tonnetz layout
function theory.get_interval_importance(x, y)
  -- Get root note and scale info
  local root = params:get("root_note") - 1  -- Convert to 0-based
  local scale_type = params:get("scale_type")
  local octave = theory.get_octave()
  
  -- Calculate the actual MIDI note at this position
  local midi_note = theory.grid_to_note(x, y)
  if not midi_note then return 'secondary' end
  
  -- Check if this note is a root note in any octave
  -- by comparing its pitch class (note within octave) to the root
  local pitch_class = midi_note % 12
  if pitch_class == root then
    return 'primary'
  else
    return 'secondary'
  end
end

-- Debug utility to visualize the current keyboard layout
function theory.print_keyboard_layout()
  local root = params:get("root_note")
  local scale_type = params:get("scale_type")
  local octave = params:get("octave")
  
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

--------------------------------------------------
-- Musical Suggestion System
--------------------------------------------------

-- Brightness levels for visual feedback
theory.BRIGHTNESS = {
  RESOLUTION = 15,    -- Strongest musical magnets (V->I)
  LEADING = 12,       -- Natural melodic flow
  COUNTERPOINT = 8,   -- Harmonic possibilities
  PLAYED = 4,         -- Currently played notes
  ROOT = 2,           -- Always visible root notes
  OFF = 0
}

-- Get all grid positions for a given MIDI note
-- Returns array of {x=x, y=y} positions
function theory.get_note_positions(midi_note)
  -- TODO: Implement reverse lookup from note to grid positions
  return {}
end

-- Get strongest resolution targets for a note
-- Returns {targets = [midi_notes], brightness = level}
function theory.get_resolution_targets(midi_note, scale_type)
  -- TODO: Implement based on scale degree and musical context
  return {targets = {}, brightness = theory.BRIGHTNESS.RESOLUTION}
end

-- Get natural voice leading options
-- Returns {targets = [midi_notes], brightness = level}
function theory.get_voice_leading_options(midi_note, grid_pos)
  -- TODO: Consider physical grid position for intuitive suggestions
  return {targets = {}, brightness = theory.BRIGHTNESS.LEADING}
end

-- Get counterpoint possibilities (thirds, sixths)
-- Returns {targets = [midi_notes], brightness = level}
function theory.get_counterpoint_options(midi_note)
  -- TODO: Implement based on musical intervals
  return {targets = {}, brightness = theory.BRIGHTNESS.COUNTERPOINT}
end

-- Get suggestion context from recent note history
-- Returns enhanced suggestion data
function theory.get_suggestion_context(recent_notes)
  -- TODO: Analyze recent notes for patterns
  return {}
end

-- Calculate illumination levels for entire grid
-- Returns array of brightness values for each position
function theory.calculate_grid_illumination(active_note, recent_notes)
  local illumination = {}
  -- TODO: Layer different suggestion types
  -- 1. Always-on root notes
  -- 2. Currently played notes
  -- 3. Resolution targets
  -- 4. Voice leading options
  -- 5. Counterpoint possibilities
  return illumination
end

--------------------------------------------------
-- Position and Transposition
--------------------------------------------------

-- Convert between grid and musical position
function theory.grid_to_musical_pos(x, y)
  -- TODO: Implement conversion to transposable musical space
  return {x = x, y = y}
end

function theory.musical_to_grid_pos(musical_x, musical_y)
  -- TODO: Implement conversion back to grid space
  return {x = musical_x, y = musical_y}
end

-- Apply transposition while maintaining musical relationships
function theory.transpose_position(pos, offset_x, offset_y)
  -- TODO: Implement position transposition that preserves paths
  return pos
end

-- Enhanced debug utilities for scale analysis
function theory.debug_scale_position(x, y)
  local root = params:get("root_note") - 1
  local scale_type = params:get("scale_type")
  local octave = theory.get_octave()
  
  -- Calculate components
  local thirds = (x - 1) * 2
  local seconds = (6 - y)
  local scale = musicutil.SCALES[scale_type].intervals
  local scale_length = #scale
  
  -- Calculate position and wrapping
  local raw_position = thirds + seconds
  local scale_position = (raw_position % scale_length) + 1
  local octave_shift = math.floor(raw_position / scale_length)
  
  -- Get the actual note
  local base_midi = (octave * 12) + root
  local interval = scale[scale_position]
  local midi_note = base_midi + interval + (octave_shift * 12)
  
  -- Format debug output
  local note_name = theory.note_to_name(midi_note)
  return string.format(
    "Grid(%d,%d) → " ..
    "Intervals(thirds=%d, seconds=%d) → " ..
    "Scale(pos=%d, wrap=%d, oct_shift=%d) → " ..
    "Note(%s)",
    x, y,
    thirds, seconds,
    scale_position, raw_position % scale_length, octave_shift,
    note_name
  )
end

-- Analyze a melodic path through the grid
-- path is array of {x=x, y=y} positions
function theory.debug_melodic_path(path)
  print("\n▓ Melodic Path Analysis ▓")
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  local intervals = {}
  local prev_midi = nil
  
  for i, pos in ipairs(path) do
    local note = theory.grid_to_note(pos.x, pos.y)
    print(string.format("%d. %s", i, theory.debug_scale_position(pos.x, pos.y)))
    
    -- Calculate interval from previous note
    if prev_midi then
      local interval = note - prev_midi
      table.insert(intervals, interval)
      print(string.format("   Interval: %+d semitones", interval))
    end
    prev_midi = note
  end
  
  -- Analyze pattern
  if #intervals > 0 then
    print("\nInterval Pattern:")
    print(table.concat(intervals, ", "))
  end
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
end

-- Visual analysis of scale wrapping
function theory.debug_scale_wrapping()
  local scale_type = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type]
  
  print(string.format("\n▓ Scale Wrapping Analysis: %s ▓", scale.name))
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Show how positions wrap
  for y = 1, 6 do
    local row = ""
    for x = 1, 6 do
      local thirds = (x - 1) * 2
      local seconds = (6 - y)
      local raw_position = thirds + seconds
      local scale_position = (raw_position % #scale.intervals) + 1
      row = row .. string.format("%2d→%d  ", raw_position, scale_position)
    end
    print(row)
  end
  
  print("\nLegend: raw_position→wrapped_position")
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
end

-- Print a simple keyboard visualization with offsets
function theory.print_keyboard_at_offset(offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0
  
  local root = params:get("root_note") - 1
  local scale_type = params:get("scale_type")
  local octave = theory.get_octave()
  
  print(string.format("\n▓ Keyboard Layout (offset: x=%d, y=%d) ▓", offset_x, offset_y))
  print("▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
  
  -- Print column headers
  local header = "    "  -- 4 spaces for row labels
  for x = 1, 6 do
    header = header .. string.format("%-5d", x)
  end
  print(header)
  
  -- Print each row
  for y = 1, 6 do
    local row = string.format("%2d |", y)
    for x = 1, 6 do
      -- Apply offsets to the position calculation
      local adj_x = x + offset_x
      local adj_y = y + offset_y
      
      -- Calculate note at this position
      local thirds = (adj_x - 1) * 2
      local seconds = (6 - adj_y)
      local scale = musicutil.SCALES[scale_type].intervals
      local scale_length = #scale
      
      local raw_position = thirds + seconds
      local scale_position = (raw_position % scale_length) + 1
      -- Prevent negative octaves by adding an offset before floor division
      local octave_shift = math.max(0, math.floor((raw_position + (scale_length * 2)) / scale_length) - 2)
      
      -- Adjust base MIDI calculation to start in a more appropriate range
      local base_midi = ((octave + 2) * 12) + root  -- Shift up two octaves
      local interval = scale[scale_position]
      local midi_note = base_midi + interval + (octave_shift * 12)
      
      -- Format note name to 4 characters
      local note_name = theory.note_to_name(midi_note)
      row = row .. string.format("%-5s", note_name)
    end
    print(row)
  end
  
  print("\nScale: " .. musicutil.SCALES[scale_type].name)
  print("Root: " .. theory.note_to_name(root + 60))  -- Show root in middle octave
  print("Base Octave: " .. octave)
  print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
end

return theory
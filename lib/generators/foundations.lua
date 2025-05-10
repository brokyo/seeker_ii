-- foundations.lua
-- Creates slow, cycling arpeggios that establish different emotional foundations
-- Each style creates a distinct mood through careful note selection and timing

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Foundations",
  description = "Slow, cycling arpeggios that establish different emotional spaces",
  
  params = {
    -- How many beats between notes
    tempo = {
      type = "number",
      min = 1,
      max = 8,
      default = 4,
      step = 1,
      formatter = function(value)
        if value == 1 then return "1 beat"
        else return string.format("%d beats", value) end
      end
    },
    
    -- Overall dynamic intensity
    intensity = {
      type = "control",
      min = 0,
      max = 100,
      default = 70,
      step = 1,
      formatter = function(value)
        if value < 33 then return "Gentle"
        elseif value < 66 then return "Moderate"
        else return "Strong" end
      end
    },
    
    -- Which octave range to use
    octave = {
      type = "integer",
      min = 2,
      max = 6,
      default = 4,
      step = 1,
      formatter = function(value)
        return string.format("Octave %d", value)
      end
    },
    
    -- The emotional quality of the pattern
    style = {
      type = "option",
      options = {"Contemplative", "Melancholic", "Ethereal", "Tension"},
      default = 1,
      step = 1
    }
  },
  
  generate = function(params, add_note_event)
    local events = {}
    local time = 0  -- Time in beats
    
    -- Get root note in the selected octave
    local root = (params.octave * 12) + 24  -- C in the chosen octave
    
    -- Define the patterns for each style with musical chord types
    local patterns = {
      -- Contemplative: Major with gentle rises
      [1] = {
        chords = {
          { root_offset = 0, type = "Major 7" },    -- I maj7
          { root_offset = 5, type = "Major 7" },    -- IV maj7
          { root_offset = -5, type = "Major 7" }    -- V maj7
        },
        pattern = {1, 2, 3, 4, 3, 2},
        velocities = {1.0, 0.8, 0.9, 0.7, 0.85, 0.75},
        timing_variation = 0.05,
        velocity_variation = 0.1
      },
      
      -- Melancholic: Minor with emotional drops
      [2] = {
        chords = {
          { root_offset = 0, type = "Minor 6" },     -- i min6
          { root_offset = 3, type = "Minor 6" },     -- iii min6
          { root_offset = -2, type = "Minor 6" }     -- vii min6
        },
        pattern = {1, 2, 3, 4, 3, 2},
        velocities = {0.9, 1.0, 0.7, 0.85, 0.8, 0.75},
        timing_variation = 0.08,
        velocity_variation = 0.15
      },
      
      -- Ethereal: Suspended and floating
      [3] = {
        chords = {
          { root_offset = 0, type = "Sus4" },       -- Isus4
          { root_offset = 7, type = "Sus2" },       -- Vsus2
          { root_offset = 2, type = "Sus4" }        -- IIsus4
        },
        pattern = {1, 2, 3, 2, 3, 1},
        velocities = {0.8, 0.9, 0.7, 0.85, 0.95, 0.75},
        timing_variation = 0.12,
        velocity_variation = 0.2
      },
      
      -- Tension: Mysterious and uncertain
      [4] = {
        chords = {
          { root_offset = 0, type = "Diminished 7" },    -- i dim7
          { root_offset = 3, type = "Half Diminished" }, -- iii half-dim
          { root_offset = 6, type = "Diminished 7" }     -- #iv dim7
        },
        pattern = {1, 2, 3, 4, 3, 2},
        velocities = {1.0, 0.85, 0.9, 0.8, 0.85, 0.75},
        timing_variation = 0.1,
        velocity_variation = 0.15
      }
    }
    
    -- Get the selected pattern
    local pattern = patterns[params.style]
    
    -- Get available notes from our scale for snapping
    local scale_notes = theory.get_scale()
    
    -- Pick a random chord from the style's available chords
    local chosen_chord = pattern.chords[math.random(#pattern.chords)]
    local chord_root = root + chosen_chord.root_offset
    
    -- Generate the chord notes for this pattern
    local chord_notes = musicutil.generate_chord(chord_root, chosen_chord.type)
    
    -- Helper function to add humanized variation
    local function humanize(value, amount)
      local variation = (math.random() * 2 - 1) * amount
      return value * (1 + variation)
    end
    
    -- Generate two full cycles of the pattern
    for cycle = 1, 2 do
      for i, chord_idx in ipairs(pattern.pattern) do
        -- Get the note from our chord and ensure it's in our scale
        local note = chord_notes[chord_idx]
        print(string.format("note: %s, scale_notes: %s", note, table.concat(scale_notes or {}, ",")))
        note = musicutil.snap_note_to_array(note, scale_notes)
        
        -- Add humanized variations
        local velocity = math.floor(40 + (params.intensity * 0.4) * 
          humanize(pattern.velocities[i], pattern.velocity_variation))
        velocity = util.clamp(velocity, 1, 127)  -- Ensure MIDI velocity stays in range
        
        local duration = humanize(params.tempo * 0.8, pattern.timing_variation)
        duration = util.clamp(duration, params.tempo * 0.4, params.tempo * 1.2)
        
        -- Add slight timing drift for more organic feel
        local drift = humanize(params.tempo, pattern.timing_variation)
        
        add_note_event(events, note, time, duration, velocity)
        time = time + drift
      end
    end
    
    return {
      events = events,
      duration = time  -- Duration in beats
    }
  end
} 
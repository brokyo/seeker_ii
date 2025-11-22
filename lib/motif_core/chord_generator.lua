-- chord_generator.lua
-- Shared utility for generating chord notes with octave cycling
-- Used by arpeggio mode and future algorithmic generators

local musicutil = require('musicutil')

local ChordGenerator = {}

--- Generate chord notes with octave cycling
-- @param chord_root_degree: Scale degree (1-7) for the chord root
-- @param chord_type: Chord quality (Major, Minor, Sus2, etc.) or "Diatonic"
-- @param chord_length: How many notes to generate (cycles through chord tones)
-- @param chord_inversion: Inversion number (0 = root position, 1 = first inversion, etc.)
-- @return: Table of MIDI note numbers representing the chord
function ChordGenerator.generate_chord(chord_root_degree, chord_type, chord_length, chord_inversion)
  -- Get global scale settings
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  -- Convert scale degree (1-7) to semitone offset from root
  local degree_index = ((chord_root_degree - 1) % #scale.intervals) + 1
  local semitone_offset = scale.intervals[degree_index]

  -- Calculate actual MIDI note for chord root
  local chord_root_midi = ((root_note - 1) + semitone_offset) % 12

  -- Map "Diatonic" to the appropriate chord quality based on scale degree
  if chord_type == "Diatonic" then
    -- Standard diatonic chord qualities (works for major and most modal scales)
    local diatonic_qualities = {"major", "minor", "minor", "major", "major", "minor", "diminished"}
    local quality_index = ((chord_root_degree - 1) % 7) + 1
    chord_type = diatonic_qualities[quality_index]
  end

  -- Normalize chord type names to lowercase for musicutil compatibility
  local chord_type_map = {
    ["Major"] = "major",
    ["Minor"] = "minor",
    ["Sus2"] = "sus2",
    ["Sus4"] = "sus4",
    ["Maj7"] = "major 7",
    ["Min7"] = "minor 7",
    ["Dom7"] = "dom 7",
    ["Dim"] = "diminished",
    ["Aug"] = "augmented"
  }
  chord_type = chord_type_map[chord_type] or chord_type

  -- Get base chord intervals from musicutil with inversion
  local base_chord = musicutil.generate_chord(chord_root_midi, chord_type, chord_inversion or 0, 3)

  -- Error handling if chord type not recognized
  if not base_chord or #base_chord == 0 then
    print("ERROR: Unknown chord type '" .. chord_type .. "', falling back to major")
    base_chord = musicutil.generate_chord(chord_root_midi, "major", 0, 3)
  end

  -- Convert to intervals relative to root
  local chord_intervals = {}
  for _, note in ipairs(base_chord) do
    table.insert(chord_intervals, note - chord_root_midi)
  end

  -- Generate extended chord using seeker-style cycling
  local chord_notes = {}
  local note_index = 1
  local octave_offset = 0

  for i = 1, chord_length do
    local interval = chord_intervals[note_index]
    local note = chord_root_midi + interval + (octave_offset * 12)
    table.insert(chord_notes, note)

    note_index = note_index + 1
    if note_index > #chord_intervals then
      note_index = 1
      octave_offset = octave_offset + 1
    end
  end

  return chord_notes
end

return ChordGenerator

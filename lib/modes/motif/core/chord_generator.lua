-- chord_generator.lua
-- Shared utility for generating chord notes with octave cycling
-- Used by composer mode and future algorithmic generators

local musicutil = require('musicutil')

local ChordGenerator = {}

--- Generate chord notes with octave cycling
-- @param chord_root_degree: Scale degree (1-7) for the chord root
-- @param chord_type: Chord quality (Major, Minor, Sus2, etc.) or "Diatonic"
-- @param chord_length: How many notes to generate (cycles through chord tones)
-- @param voice_rotation: Rotates chord voicing (-2 to +2). Negative drops top notes down, positive raises bottom notes up
-- @param octave_span: Octave range (0-3). How many octaves to span when cycling through chord tones
-- @return: Table of MIDI note numbers representing the chord
function ChordGenerator.generate_chord(chord_root_degree, chord_type, chord_length, voice_rotation, octave_span)
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
    local diatonic_qualities = {"Major", "Minor", "Minor", "Major", "Major", "Minor", "Diminished"}
    local quality_index = ((chord_root_degree - 1) % 7) + 1
    chord_type = diatonic_qualities[quality_index]
  end

  -- Map display names to musicutil chord type names
  local chord_type_map = {
    ["Major"] = "Major",
    ["Minor"] = "Minor",
    ["Sus4"] = "Sus4",
    ["Maj7"] = "Major 7",
    ["Min7"] = "Minor 7",
    ["Dom7"] = "Dominant 7",
    ["Dim"] = "Diminished",
    ["Aug"] = "Augmented"
  }
  chord_type = chord_type_map[chord_type] or chord_type

  -- Get base chord from musicutil (root position)
  local base_chord = musicutil.generate_chord(chord_root_midi, chord_type, 0, 3)

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

  -- Apply voice rotation to create inversions and drop voicings
  -- Positive: rotate bottom notes up an octave (inversions)
  -- Negative: rotate top notes down an octave (drop voicings)
  local rotation = voice_rotation or 0
  if rotation > 0 then
    for _ = 1, math.min(rotation, #chord_intervals - 1) do
      chord_intervals[1] = chord_intervals[1] + 12
      table.sort(chord_intervals)
    end
  elseif rotation < 0 then
    for _ = 1, math.min(-rotation, #chord_intervals - 1) do
      chord_intervals[#chord_intervals] = chord_intervals[#chord_intervals] - 12
      table.sort(chord_intervals)
    end
  end

  -- Generate extended chord by cycling through chord tones with octave jumps
  -- Span controls how many octaves to jump per cycle (0=tight, 1=normal, 2+=wide)
  local span_semitones = 12 * (octave_span or 1)
  local chord_notes = {}
  local note_index = 1
  local octave_offset = 0

  for i = 1, chord_length do
    local interval = chord_intervals[note_index]
    local note = chord_root_midi + interval + (octave_offset * span_semitones)
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

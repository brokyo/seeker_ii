-- chord_generator.lua
-- Generates chord notes from scale degrees with continuous voice spread.
-- Used by composer mode and future algorithmic generators.

local musicutil = require('musicutil')

local ChordGenerator = {}

--- Generate chord notes with continuous spread control.
-- @param chord_root_degree: Scale degree (1-7) for the chord root
-- @param chord_type: Chord quality (Major, Minor, etc.) or "Diatonic"
-- @param chord_length: How many notes to generate (cycles through chord tones)
-- @param spread: 0-100, how far apart voices are placed. 0=close position, 100=~1 octave per voice.
-- @return: Table of MIDI note numbers (relative to octave 0)
function ChordGenerator.generate_chord(chord_root_degree, chord_type, chord_length, spread)
  local root_note = params:get("root_note")
  local scale_type_index = params:get("scale_type")
  local scale = musicutil.SCALES[scale_type_index]

  local degree_index = ((chord_root_degree - 1) % #scale.intervals) + 1
  local semitone_offset = scale.intervals[degree_index]
  local chord_root_midi = ((root_note - 1) + semitone_offset) % 12

  if chord_type == "Diatonic" then
    local diatonic_qualities = {"Major", "Minor", "Minor", "Major", "Major", "Minor", "Diminished"}
    local quality_index = ((chord_root_degree - 1) % 7) + 1
    chord_type = diatonic_qualities[quality_index]
  end

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

  local base_chord = musicutil.generate_chord(chord_root_midi, chord_type, 0, 3)
  if not base_chord or #base_chord == 0 then
    print("ERROR: Unknown chord type '" .. chord_type .. "', falling back to major")
    base_chord = musicutil.generate_chord(chord_root_midi, "major", 0, 3)
  end

  local chord_intervals = {}
  for _, note in ipairs(base_chord) do
    table.insert(chord_intervals, note - chord_root_midi)
  end

  spread = spread or 0
  local spread_factor = spread / 100
  local num_base_tones = #chord_intervals
  local chord_notes = {}

  for i = 1, chord_length do
    local tone_index = ((i - 1) % num_base_tones) + 1
    local cycle = math.floor((i - 1) / num_base_tones)
    local interval = chord_intervals[tone_index]

    local base_offset = cycle
    local spread_offset = spread_factor * (i - 1)
    local octave_offset = base_offset + math.floor(spread_offset)

    local note = chord_root_midi + interval + (octave_offset * 12)
    table.insert(chord_notes, note)
  end

  return chord_notes
end

--- Find the octave of pitch_class nearest to target_note
local function nearest_octave(pitch_class, target_note)
  local base = target_note - ((target_note - pitch_class) % 12)
  if math.abs(base - target_note) <= math.abs(base + 12 - target_note) then
    return base
  else
    return base + 12
  end
end

--- Smooth voice leading: re-voice each chord to minimize movement from the previous.
-- @param stages_notes: array of absolute MIDI note arrays (one per stage)
-- @return: modified array with stages 2+ re-voiced for minimal movement
function ChordGenerator.smooth_voice_leading(stages_notes)
  if not stages_notes or #stages_notes < 2 then return stages_notes end

  local result = { stages_notes[1] }
  for i = 2, #stages_notes do
    local prev = result[i - 1]
    local new = stages_notes[i]
    local n = #new
    local p = #prev

    local new_pcs = {}
    for j, note in ipairs(new) do
      new_pcs[j] = note % 12
    end

    local voiced = {}
    for j = 1, n do
      local ref = prev[math.min(j, p)]
      voiced[j] = nearest_octave(new_pcs[j], ref)
    end
    table.sort(voiced)
    table.insert(result, voiced)
  end

  return result
end

--- Rotate a chord: fold bottom notes up (positive) or top notes down (negative).
-- @param notes: sorted array of MIDI note numbers
-- @param rotation: integer, positive = fold bottom up, negative = fold top down
-- @return: new sorted array with rotation applied
function ChordGenerator.rotate_chord(notes, rotation)
  if not notes or #notes == 0 or rotation == 0 then return notes end

  local result = {}
  for _, n in ipairs(notes) do table.insert(result, n) end
  table.sort(result)

  local steps = math.min(math.abs(rotation), #result - 1)
  if rotation > 0 then
    for _ = 1, steps do
      result[1] = result[1] + 12
      table.sort(result)
    end
  else
    for _ = 1, steps do
      result[#result] = result[#result] - 12
      table.sort(result)
    end
  end

  return result
end

return ChordGenerator

-- chord_generator.lua
-- Shared utility for generating chord notes with octave cycling
-- Used by composer mode and future algorithmic generators

local musicutil = require('musicutil')

local ChordGenerator = {}

--- Generate chord notes with voicing styles
-- @param chord_root_degree: Scale degree (1-7) for the chord root
-- @param chord_type: Chord quality (Major, Minor, Sus2, etc.) or "Diatonic"
-- @param chord_length: How many notes to generate (cycles through chord tones)
-- @param voice_rotation: Rotates chord voicing. Negative drops top notes down, positive raises bottom notes up
-- @param voicing_style: How to spread voices across octaves (Close, Open, Drop 2, etc.)
-- @return: Table of MIDI note numbers representing the chord
function ChordGenerator.generate_chord(chord_root_degree, chord_type, chord_length, voice_rotation, voicing_style)
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

  -- Generate chord notes with voicing style applied
  local style = voicing_style or "Close"
  local num_base_tones = #chord_intervals
  local chord_notes = {}

  for i = 1, chord_length do
    -- Cycle through base chord tones
    local tone_index = ((i - 1) % num_base_tones) + 1
    local cycle = math.floor((i - 1) / num_base_tones)
    local interval = chord_intervals[tone_index]
    local octave_offset = 0

    if style == "Close" then
      -- All voices tight, +1 octave per cycle
      octave_offset = cycle

    elseif style == "Open" then
      -- Alternate voices spread: even positions +1 octave
      octave_offset = cycle
      if i % 2 == 0 then
        octave_offset = octave_offset + 1
      end

    elseif style == "Drop 2" then
      -- 2nd voice from top in each cycle drops an octave
      octave_offset = cycle
      if tone_index == num_base_tones - 1 and num_base_tones > 2 then
        octave_offset = octave_offset - 1
      end

    elseif style == "Drop 3" then
      -- 3rd voice from top in each cycle drops an octave
      octave_offset = cycle
      if tone_index == num_base_tones - 2 and num_base_tones > 3 then
        octave_offset = octave_offset - 1
      end

    elseif style == "Spread" then
      -- Root stays low, upper voices go high
      octave_offset = cycle
      if tone_index > 1 then
        octave_offset = octave_offset + 1
      end

    elseif style == "Rising" then
      -- Each successive voice +1 octave
      octave_offset = i - 1

    elseif style == "Falling" then
      -- Each successive voice -1 octave (starts high)
      octave_offset = chord_length - i

    elseif style == "Scatter" then
      -- Random octave displacement within 3 octaves
      math.randomseed(chord_root_degree * 1000 + tone_index * 100 + i)
      octave_offset = cycle + math.random(0, 2)
    end

    local note = chord_root_midi + interval + (octave_offset * 12)
    table.insert(chord_notes, note)
  end

  return chord_notes
end

return ChordGenerator

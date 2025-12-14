-- component_descriptions.lua
-- Section descriptions shown on k2 hold
-- Transform descriptions are defined in their respective transform files

return {
  -- Global
  CONFIG = "Application-level settings. \n\nTry the scale presets, it's a very tonal instrument. \n\nShield Encoder Fix improves scrolling on my DIY Norns. \n\nMIDI controls Motif mode.",

  -- Motif mode
  LANE_CONFIG = "Select motif type and configure voices. Multiple voices can run simultaneously.",
  MOTIF_CONFIG = "Global tuning and keyboard layout.\n\nTuning applies to all motif types.\n\nLayout only applies to modal Tonnetz in Tape.",

  -- Tape mode
  TAPE_CREATE = "Record notes as a looping motif. Hold to record and again to overdub.\n\nOverdubs inherit envelope settings from Lane Config.\n\nDual keyboard splits the grid into two tonnetz with independent octaves. Arc rings 3/4 control velocity for each side.",
  TAPE_PLAYBACK = "Control playback timing and transposition.",
  TAPE_CLEAR = "Hold to clear the recorded motif and reset to a blank canvas.",
  TAPE_VELOCITY = "Control note loudness. Press grid keys to select level.",
  TAPE_STAGE_CONFIG = "Sequence changes to the loop. Structured and probabilistic options. Harmonize is a lot of fun.",
  TAPE_PERFORM = "Hold grid button to activate selected mode. Mute silences, Accent boosts, Soft reduces velocity.",

  -- Composer mode
  COMPOSER_CREATE = "Generate a motif from current parameters. Hold grid button to generate. Presets change rhythmic structure in realtime.",
  COMPOSER_PLAYBACK = "Control playback timing and pitch offset.",
  COMPOSER_CLEAR = "Hold to clear the currently stored motif.",
  COMPOSER_EXPRESSION_STAGES = "Configure pattern and timing for each stage. Phasing is very cool if you have more unequal step (create) and length (harmonic).",
  COMPOSER_HARMONIC_STAGES = "Configure pitch and harmonic content for each stage. Rotation moves voices up/down octaves (negative=drop voicing). Span controls octave range (0=tight, 3=wide).",
  COMPOSER_PERFORM = "Hold grid button to activate selected mode. Mute silences, Accent boosts volume, Soft reduces velocity.",

  -- Sampler mode
  SAMPLER_CREATE = "Record pad triggers as a looping motif. Load samples in Lane Config.",
  SAMPLER_PLAYBACK = "Control playback timing.",
  SAMPLER_CLEAR = "Hold to clear the recorded motif and reset to a blank canvas.",
  SAMPLER_VELOCITY = "Control chop playback volume. Press grid keys to select level. Tweak as needed. Performable.",
  SAMPLER_STAGE_CONFIG = "Transform chop parameters across stages. Primarily time and rate manipulation.",
  SAMPLER_CHOP_CONFIG = "Configure individual chop points and envelopes. Each pad controls one chop. Pitch and Speed combine.",
  SAMPLER_PERFORM = "Hold grid button to activate selected mode. Mute silences, Accent boosts, Soft reduces velocity.",

  -- WTape mode
  WTAPE = "WTape settings. Most documented features implemented via grid buttons.",
  WTAPE_PLAYBACK = "Tape playback. Press grid to toggle play/stop. Speed affects pitch.",
  WTAPE_RECORD = "Tape recording. Erase 0=overdub, 1=replace. Echo plays back before erasing.",

  -- Eurorack mode
  EURORACK_CONFIG = "Control Eurorack modules over i2c. Supports Crow and TXO.",
  CROW_OUTPUT = "Configure Crow voltage output. Gates, bursts, LFOs, etc.",
  TXO_CV_OUTPUT = "Configure TXO CV output. LFOs, random walks, etc.",
  TXO_TR_OUTPUT = "Configure TXO trigger output. Clocks, patterns, etc.",

  -- OSC mode
  OSC_CONFIG = "OSC connection and settings. Tuned for TouchDesigner.",
  OSC_FLOAT = "Send a float value over OSC. Use Seeker TD tox. Best with Arc controller.",
  OSC_TRIGGER = "Send a trigger value over OSC. Use Seeker TD tox. Best with Arc controller.",
  OSC_LFO = "Send an LFO value over OSC. Use Seeker TD tox. Best with Arc controller.",
}

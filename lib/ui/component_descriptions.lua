-- component_descriptions.lua
-- Section descriptions shown on k2 hold
-- Transform descriptions are defined in their respective transform files

return {
  -- Global
  CONFIG = "Application-level settings. \n\nTry the scale presets, it's a very tonal instrument. \n\nShield Encoder Fix improves scrolling on my DIY Norns. \n\nMIDI controls Motif mode.",

  -- Motif mode
  LANE_CONFIG = "Select motif type and configure voices. Multiple voices can run simultaneously.",
  MOTIF = "Global tuning and keyboard layout.\n\nTuning applies to all motif types.\n\nLayout controls how notes map to the grid.",

  -- Tape mode
  TAPE_CREATE = "Record notes as a looping motif. Hold to record and again to overdub.\n\nOverdubs inherit envelope settings from Lane Config.\n\nDual keyboard splits the grid into two scale keyboards with independent octaves. Arc rings 3/4 control velocity for each side.",
  TAPE_PLAYBACK = "Control playback timing and transposition.\n\nQuantize snaps notes to a rhythmic grid. Swing delays off-beat notes for groove.",
  TAPE_CLEAR = "Hold to clear the motif. With overdubs, select a generation to erase just that layer.",
  TAPE_VELOCITY = "Control note loudness. Press grid keys to select level.",
  TAPE_TUNING = "Transpose the keyboard by octave. Left button = octave down, right = octave up. Grid offset shifts the scale mapping.",
  TAPE_STAGE_CONFIG = "Sequence changes to the loop. Structured and probabilistic options. Harmonize is a lot of fun.",
  TAPE_PERFORM = "Hold grid button to activate selected mode. Mute silences, Accent boosts, Soft reduces velocity.",

  -- Composer mode
  COMPOSER_LIVE = "Composer chord progression generator.\n\nSet Start degree and Movement to define the harmonic cycle. Arc page 1 (harmony) adjusts degree, chord length, voicing, and rotation per stage. Arc page 2 (articulation) controls spread, strum, and loops.\n\nE2 selects param, E3 adjusts, K3 cycles page. Changes land at the next loop boundary via regen.",
  COMPOSER_PROGRESSION = "Global progression controls.\n\nArc controls beats, spread, and chord length for all stages at once. Tap a stage button to edit that stage in the per-stage view.",
  COMPOSER_PLAYBACK = "Lane playback controls: volume, speed, octave offset, swing.",
  COMPOSER_VOICE = "Voice routing: select output destination and configure voice parameters.",
  COMPOSER_PARAMS = "Chord progression shape, texture, and structure.",

  -- Sampler mode
  SAMPLER_CREATE = "Record pad triggers as a looping motif. Hold to record, tap to stop, hold again to overdub.\n\nLoad samples in Lane Config first. The 4x4 pad grid triggers chops from the loaded sample.\n\nDuration can be adjusted after recording to trim or extend the loop.",
  SAMPLER_PLAYBACK = "Control playback timing.\n\nQuantize snaps triggers to a rhythmic grid. Swing delays off-beat triggers for groove.",
  SAMPLER_CLEAR = "Hold to clear the motif. With overdubs, select a generation to erase just that layer.",
  SAMPLER_VELOCITY = "Control chop playback volume. Press grid keys to select level. Tweak as needed. Performable.",
  SAMPLER_STAGE_CONFIG = "Transform chop parameters across stages. Primarily time and rate manipulation.",
  SAMPLER_CHOP_CONFIG = "Configure individual chop points and envelopes. Each pad controls one chop. Pitch and Speed combine.",
  SAMPLER_PERFORM = "Hold grid button to activate selected mode. Mute silences, Accent boosts, Soft reduces velocity.",

  -- WTape mode
  WTAPE = "WTape configuration. Monitor level and navigation.\n\nGo To Start jumps to timestamp 0.\n\nInit W/Tape **clears** the tape buffer, resets all params to defaults, and syncs to hardware. Use when W/Tape gets into a weird state.",
  WTAPE_PLAYBACK = "Toggle tape playback. Speed affects pitch.\n\nLong press: Toggle play/stop.",
  WTAPE_RECORD = "Toggle recording. Rec Level sets input gain.\n\nLong press: Toggle recording.\n\nEcho Mode: can't actually figure this one out.",
  WTAPE_FF = "Skip forward on the tape.\n\nLong press: Seek forward.",
  WTAPE_REWIND = "Skip backward on the tape.\n\nLong press: Seek backward.",
  WTAPE_REVERSE = "Flip playback direction.\n\nLong press: Toggle direction.",
  WTAPE_LOOP_ACTIVE = "Toggle looping on/off.\n\nLong press: Toggle loop on/off.",
  WTAPE_FRIPPERTRONICS = "Frippertronics: tape delay with decay.\n\nHold: Start buffer creation.\nTap: End buffer setup and start looping.\n\nUse Decay param to control fade rate.",
  WTAPE_DECAY = "Control how fast layers fade.\n\n0 = full overdub (layers accumulate forever)\n0.2-0.4 = Frippertronics\n1 = full replace (old material erased)",

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

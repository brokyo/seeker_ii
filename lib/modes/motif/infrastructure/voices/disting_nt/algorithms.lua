-- disting_nt/algorithms.lua
-- Data-driven algorithm definitions for Disting NT

local algorithms = {}

------------------------------------------------------------
-- Shared Option Tables
------------------------------------------------------------

algorithms.SUSTAIN_MODES = {"Synth", "Piano"}

algorithms.OUTPUT_OPTIONS = {
  "None",
  "Input 1", "Input 2", "Input 3", "Input 4", "Input 5", "Input 6",
  "Input 7", "Input 8", "Input 9", "Input 10", "Input 11", "Input 12",
  "Output 1", "Output 2", "Output 3", "Output 4",
  "Output 5", "Output 6", "Output 7", "Output 8",
  "Aux 1", "Aux 2", "Aux 3", "Aux 4", "Aux 5", "Aux 6", "Aux 7", "Aux 8",
}

algorithms.OUTPUT_MODES = {"Add", "Replace"}

algorithms.PLAITS_MODELS = {
  "Virtual Analog", "Waveshaping", "FM", "Granular", "Harmonic", "Wavetable",
  "Chord", "Speech", "Swarm", "Noise", "Particle", "String", "Modal",
  "Bass Drum", "Snare Drum", "Hi-Hat", "VA VCF", "PD", "6-op FM (1)",
  "6-op FM (2)", "6-op FM (3)", "Wave Terrain", "String 2", "Chiptune",
}

algorithms.RESONATOR_MODES = {"Modal", "Sympathetic", "String", "FM", "Quantized"}

algorithms.FILTER_TYPES = {"Off", "Lowpass", "Bandpass", "Highpass"}

algorithms.LFO_RETRIGGER_MODES = {"Poly", "Mono", "Off"}

algorithms.SPREAD_MODES = {"By Voice", "By Pitch", "Random"}

algorithms.STRUM_TYPES = {"Flat", "Ramped"}

algorithms.INDIAN_NOTES = {"Sa", "Re b", "Re", "Ga b", "Ga", "Ma", "Ma #", "Pa", "Dha b", "Dha", "Ni b", "Ni"}

algorithms.WINDOW_TYPES = {"Rectangular", "Linear Atk", "Linear Dcy", "Gaussian"}

algorithms.PITCH_MODES = {"Independent", "Tracking"}

algorithms.MASKING_MODES = {"Stochastic", "Burst"}

algorithms.OVERSAMPLING_OPTIONS = {"None", "2x", "4x"}

------------------------------------------------------------
-- Note Name Formatter (for filter frequency display)
------------------------------------------------------------

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

function algorithms.midi_to_note_name(midi_note)
  local octave = math.floor(midi_note / 12) - 1
  local note_idx = (midi_note % 12) + 1
  return NOTE_NAMES[note_idx] .. octave
end

------------------------------------------------------------
-- Algorithm Categories
------------------------------------------------------------

algorithms.CATEGORIES = {
  oscillator = "Oscillator",
  filter = "Filter",
  effect = "Effect",
}

------------------------------------------------------------
-- Algorithm Definitions
------------------------------------------------------------

-- Each algorithm has:
--   id: internal key
--   name: display name
--   guid: 4-char file format guid from NT
--   category: oscillator, filter, effect
--   param_prefix: short prefix for norns params
--   has_note_input: true if receives notes via i2c
--   params: array of param definitions
--   ui_sections: how params group in UI

algorithms.DEFINITIONS = {
  ------------------------------------------------------------
  -- Poly FM
  ------------------------------------------------------------
  poly_fm = {
    id = "poly_fm",
    name = "Poly FM",
    guid = "pyfm",
    category = "oscillator",
    param_prefix = "pfm",
    has_note_input = true,
    params = {
      -- Voice
      { id = "sustain_mode", name = "Sustain Mode", type = "option", options = "SUSTAIN_MODES", default = 2, param_num = 8, hidden = true },
      { id = "sustain", name = "Sustain", type = "option", options = {"Off", "On"}, default = 1, param_num = 50 },
      { id = "bank", name = "Bank", type = "number", min = 1, max = 21, default = 1, param_num = 10 },
      { id = "voice", name = "Voice", type = "number", min = 1, max = 32, default = 1, param_num = 11 },
      -- Sound
      { id = "brightness", name = "Brightness", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 28, scale = 10 },
      { id = "envelope_scale", name = "Envelope Scale", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 29, scale = 10 },
      -- Tuning
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 31 },
      -- Output
      { id = "gain", name = "Gain", type = "number", min = -40, max = 6, default = 0, param_num = 32 },
      { id = "left_output", name = "Left Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 14 },
      { id = "right_output", name = "Right Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 15 },
      -- i2c
      { id = "i2c_channel", name = "i2c Channel", type = "number", min = 1, max = 16, default = 1, param_num = 13, hidden = true },
    },
    ui_sections = {
      { title = "Voice", params = {"bank", "voice"} },
      { title = "Sound", params = {"sustain", "brightness", "envelope_scale"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Output", params = {"gain", "left_output", "right_output"} },
    },
  },

  ------------------------------------------------------------
  -- Poly Plaits (Macro Oscillator 2)
  ------------------------------------------------------------
  plaits = {
    id = "plaits",
    name = "Poly Plaits",
    guid = "pym2",
    category = "oscillator",
    param_prefix = "plaits",
    has_note_input = true,
    params = {
      -- Voice
      { id = "sustain_mode", name = "Sustain Mode", type = "option", options = "SUSTAIN_MODES", default = 2, param_num = 8, hidden = true },
      { id = "model", name = "Model", type = "option", options = "PLAITS_MODELS", default = 1, param_num = 9 },
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 11 },
      -- Oscillator
      { id = "harmonics", name = "Harmonics", type = "number", min = 0, max = 127, default = 64, param_num = 12 },
      { id = "timbre", name = "Timbre", type = "number", min = 0, max = 127, default = 64, param_num = 13 },
      { id = "morph", name = "Morph", type = "number", min = 0, max = 127, default = 64, param_num = 14 },
      -- Modulation
      { id = "fm", name = "FM", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 15, scale = 10 },
      { id = "timbre_mod", name = "Timbre Mod", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 16, scale = 10 },
      { id = "morph_mod", name = "Morph Mod", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 17, scale = 10 },
      -- Envelope
      { id = "lpg", name = "Low-pass Gate", type = "number", min = 0, max = 127, default = 127, param_num = 18 },
      { id = "decay", name = "Time/Decay", type = "number", min = 0, max = 127, default = 64, param_num = 19 },
      -- CV Inputs
      { id = "level_input", name = "Level Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 20 },
      { id = "fm_input", name = "FM Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 21 },
      { id = "harmonics_input", name = "Harmonics Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 22 },
      { id = "timbre_input", name = "Timbre Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 23 },
      { id = "morph_input", name = "Morph Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 24 },
      -- Output
      { id = "main_output", name = "Main Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 25 },
      { id = "aux_output", name = "Aux Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 26 },
      { id = "output_mode", name = "Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 27 },
      -- i2c
      { id = "i2c_channel", name = "i2c Channel", type = "number", min = 1, max = 16, default = 1, param_num = 31, hidden = true },
    },
    ui_sections = {
      { title = "Voice", params = {"model", "fine_tune"} },
      { title = "Oscillator", params = {"harmonics", "timbre", "morph"} },
      { title = "Modulation", params = {"fm", "timbre_mod", "morph_mod"} },
      { title = "Envelope", params = {"lpg", "decay"} },
      { title = "Output", params = {"main_output", "aux_output", "output_mode"} },
      { title = "CV Inputs", params = {"level_input", "fm_input", "harmonics_input", "timbre_input", "morph_input"} },
    },
  },

  ------------------------------------------------------------
  -- Poly Multisample
  ------------------------------------------------------------
  poly_multisample = {
    id = "poly_multisample",
    name = "Poly Multisample",
    guid = "pymu",
    category = "oscillator",
    param_prefix = "pm",
    has_note_input = true,
    params = {
      -- Sample
      { id = "folder", name = "Folder", type = "number", min = 0, max = 99, default = 0, param_num = 22 },
      { id = "gain", name = "Gain", type = "number", min = -40, max = 24, default = 0, param_num = 25 },
      { id = "pan", name = "Pan", type = "number", min = -100, max = 100, default = 0, param_num = 26 },
      -- Envelope
      { id = "envelope", name = "Envelope", type = "option", options = {"Off", "On"}, default = 1, param_num = 29, triggers_rebuild = true },
      { id = "attack", name = "Attack", type = "number", min = 0, max = 127, default = 0, param_num = 30, visible_when = { param = "envelope", value = 2 } },
      { id = "decay", name = "Decay", type = "number", min = 0, max = 127, default = 60, param_num = 31, visible_when = { param = "envelope", value = 2 } },
      { id = "sustain", name = "Sustain", type = "control", min = 0, max = 100, default = 100, unit = "%", param_num = 32, scale = 10, visible_when = { param = "envelope", value = 2 } },
      { id = "release", name = "Release", type = "number", min = 0, max = 127, default = 77, param_num = 33, visible_when = { param = "envelope", value = 2 } },
      { id = "loop", name = "Loop", type = "option", options = {"From WAV", "Off", "On"}, default = 1, param_num = 66 },
      -- Output
      { id = "left_output", name = "Left Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 23 },
      { id = "right_output", name = "Right Output", type = "option", options = "OUTPUT_OPTIONS", default = 15, param_num = 24 },
      -- i2c
      { id = "i2c_channel", name = "i2c Channel", type = "number", min = 1, max = 16, default = 1, param_num = 28, hidden = true },
    },
    ui_sections = {
      { title = "Sample", params = {"folder", "gain", "pan"} },
      { title = "Envelope", params = {"envelope", "attack", "decay", "sustain", "release", "loop"} },
      { title = "Output", params = {"left_output", "right_output"} },
    },
  },

  ------------------------------------------------------------
  -- Poly Resonator
  ------------------------------------------------------------
  poly_resonator = {
    id = "poly_resonator",
    name = "Poly Resonator",
    guid = "pyri",
    category = "oscillator",
    param_prefix = "pres",
    has_note_input = true,
    params = {
      -- Voice
      { id = "sustain_mode", name = "Sustain Mode", type = "option", options = "SUSTAIN_MODES", default = 2, param_num = 8, hidden = true },
      { id = "mode", name = "Mode", type = "option", options = "RESONATOR_MODES", default = 1, param_num = 9 },
      { id = "synth_effect", name = "Synth Effect", type = "option", options = {"Off", "On"}, default = 1, param_num = 10 },
      -- Tuning
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 12 },
      -- Resonator
      { id = "resolution", name = "Resolution", type = "number", min = 8, max = 64, default = 16, param_num = 13 },
      { id = "structure", name = "Structure", type = "number", min = 0, max = 127, default = 64, param_num = 14 },
      { id = "brightness", name = "Brightness", type = "number", min = 0, max = 127, default = 64, param_num = 15 },
      { id = "damping", name = "Damping", type = "number", min = 0, max = 127, default = 64, param_num = 16 },
      { id = "position", name = "Position", type = "number", min = 0, max = 127, default = 64, param_num = 17 },
      -- Input
      { id = "noise_gate", name = "Noise Gate", type = "option", options = {"Off", "On"}, default = 2, param_num = 19 },
      { id = "input_gain", name = "Input Gain", type = "number", min = -40, max = 12, default = 0, param_num = 20 },
      { id = "audio_input", name = "Audio Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 21 },
      -- Output
      { id = "output_gain", name = "Output Gain", type = "number", min = -40, max = 12, default = 0, param_num = 26 },
      { id = "dry_gain", name = "Dry Gain", type = "number", min = -40, max = 12, default = -40, param_num = 27 },
      { id = "odd_output", name = "Odd Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 22 },
      { id = "even_output", name = "Even Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 23 },
      { id = "odd_output_mode", name = "Odd Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 24 },
      { id = "even_output_mode", name = "Even Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 25 },
      -- i2c
      { id = "i2c_channel", name = "i2c Channel", type = "number", min = 1, max = 16, default = 1, param_num = 29, hidden = true },
    },
    ui_sections = {
      { title = "Voice", params = {"mode", "synth_effect"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Resonator", params = {"resolution", "structure", "brightness", "damping", "position"} },
      { title = "Input", params = {"noise_gate", "input_gain", "audio_input"} },
      { title = "Output", params = {"output_gain", "dry_gain", "odd_output", "even_output", "odd_output_mode", "even_output_mode"} },
    },
  },

  ------------------------------------------------------------
  -- Poly Wavetable
  ------------------------------------------------------------
  poly_wavetable = {
    id = "poly_wavetable",
    name = "Poly Wavetable",
    guid = "pywt",
    category = "oscillator",
    param_prefix = "pwt",
    has_note_input = true,
    params = {
      -- Voice
      { id = "sustain_mode", name = "Sustain Mode", type = "option", options = "SUSTAIN_MODES", default = 2, param_num = 49, hidden = true },
      { id = "wavetable", name = "Wavetable", type = "number", min = 0, max = 271, default = 0, param_num = 8 },
      { id = "max_voices", name = "Max Voices", type = "number", min = 1, max = 24, default = 24, param_num = 57 },
      -- Wave
      { id = "wave_offset", name = "Wave Offset", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 9, scale = 10 },
      { id = "wave_spread", name = "Wave Spread", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 10, scale = 10 },
      -- Tuning
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 12 },
      -- Envelope 1
      { id = "env1_attack", name = "Env 1 Attack", type = "number", min = 0, max = 127, default = 20, param_num = 13 },
      { id = "env1_decay", name = "Env 1 Decay", type = "number", min = 0, max = 127, default = 60, param_num = 14 },
      { id = "env1_sustain", name = "Env 1 Sustain", type = "number", min = 0, max = 127, default = 80, param_num = 15 },
      { id = "env1_release", name = "Env 1 Release", type = "number", min = 0, max = 127, default = 60, param_num = 16 },
      { id = "env1_attack_shape", name = "Env 1 Atk Shape", type = "number", min = 0, max = 127, default = 64, param_num = 17 },
      { id = "env1_decay_shape", name = "Env 1 Dcy Shape", type = "number", min = 0, max = 127, default = 64, param_num = 18 },
      -- Envelope 2
      { id = "env2_attack", name = "Env 2 Attack", type = "number", min = 0, max = 127, default = 60, param_num = 19 },
      { id = "env2_decay", name = "Env 2 Decay", type = "number", min = 0, max = 127, default = 70, param_num = 20 },
      { id = "env2_sustain", name = "Env 2 Sustain", type = "number", min = -127, max = 127, default = 64, param_num = 21 },
      { id = "env2_release", name = "Env 2 Release", type = "number", min = 0, max = 127, default = 50, param_num = 22 },
      { id = "env2_attack_shape", name = "Env 2 Atk Shape", type = "number", min = 0, max = 127, default = 64, param_num = 23 },
      { id = "env2_decay_shape", name = "Env 2 Dcy Shape", type = "number", min = 0, max = 127, default = 64, param_num = 24 },
      -- Filter
      { id = "filter_type", name = "Filter Type", type = "option", options = "FILTER_TYPES", default = 1, param_num = 25 },
      { id = "filter_freq", name = "Filter Freq", type = "number", min = 0, max = 127, default = 64, param_num = 26, formatter = "midi_note" },
      { id = "filter_q", name = "Filter Q", type = "number", min = 0, max = 100, default = 50, param_num = 27 },
      -- Mod: Velocity
      { id = "veloc_volume", name = "Veloc > Volume", type = "control", min = 0, max = 100, default = 100, unit = "%", param_num = 28, scale = 10 },
      { id = "veloc_wave", name = "Veloc > Wave", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 29, scale = 10 },
      { id = "veloc_filter", name = "Veloc > Filter", type = "number", min = -127, max = 127, default = 0, param_num = 30 },
      -- Mod: Pitch
      { id = "pitch_wave", name = "Pitch > Wave", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 31, scale = 10 },
      { id = "pitch_filter", name = "Pitch > Filter", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 32, scale = 10 },
      -- Mod: Env1
      { id = "env1_wave", name = "Env1 > Wave", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 33, scale = 10 },
      { id = "env1_filter", name = "Env1 > Filter", type = "number", min = -127, max = 127, default = 0, param_num = 34 },
      -- Mod: Env2
      { id = "env2_wave", name = "Env2 > Wave", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 35, scale = 10 },
      { id = "env2_filter", name = "Env2 > Filter", type = "number", min = -127, max = 127, default = 0, param_num = 36 },
      { id = "env2_pitch", name = "Env2 > Pitch", type = "control", min = -12, max = 12, step = 0.1, default = 0, unit = "ST", param_num = 37, scale = 10 },
      -- Mod: LFO
      { id = "lfo_wave", name = "LFO > Wave", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 38, scale = 10 },
      { id = "lfo_filter", name = "LFO > Filter", type = "number", min = -127, max = 127, default = 0, param_num = 39 },
      { id = "lfo_pitch", name = "LFO > Pitch", type = "control", min = -12, max = 12, step = 0.1, default = 0, unit = "ST", param_num = 40, scale = 10 },
      -- LFO
      { id = "lfo_speed", name = "LFO Speed", type = "number", min = -100, max = 100, default = 90, param_num = 41 },
      { id = "lfo_retrigger", name = "LFO Retrigger", type = "option", options = "LFO_RETRIGGER_MODES", default = 1, param_num = 50 },
      { id = "lfo_spread", name = "LFO Spread", type = "number", min = 0, max = 90, default = 0, param_num = 51 },
      -- Unison
      { id = "unison", name = "Unison", type = "number", min = 1, max = 8, default = 1, param_num = 45 },
      { id = "unison_detune", name = "Unison Detune", type = "number", min = 0, max = 100, default = 10, param_num = 46 },
      { id = "output_spread", name = "Output Spread", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 47, scale = 10 },
      { id = "spread_mode", name = "Spread Mode", type = "option", options = "SPREAD_MODES", default = 1, param_num = 48 },
      -- Output
      { id = "gain", name = "Gain", type = "number", min = -40, max = 24, default = 0, param_num = 42 },
      { id = "sustain", name = "Sustain", type = "option", options = {"Off", "On"}, default = 1, param_num = 43 },
      { id = "left_output", name = "Left Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 61 },
      { id = "right_output", name = "Right Output", type = "option", options = "OUTPUT_OPTIONS", default = 15, param_num = 62 },
      -- i2c
      { id = "i2c_channel", name = "i2c Channel", type = "number", min = 1, max = 16, default = 1, param_num = 60, hidden = true },
    },
    ui_sections = {
      { title = "Voice", params = {"wavetable", "max_voices"} },
      { title = "Wave", params = {"wave_offset", "wave_spread"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Envelope 1", params = {"env1_attack", "env1_decay", "env1_sustain", "env1_release", "env1_attack_shape", "env1_decay_shape", "env1_wave", "env1_filter"} },
      { title = "Envelope 2", params = {"env2_attack", "env2_decay", "env2_sustain", "env2_release", "env2_attack_shape", "env2_decay_shape", "env2_wave", "env2_filter", "env2_pitch"} },
      { title = "Filter", params = {"filter_type", "filter_freq", "filter_q"} },
      { title = "Mod: Velocity", params = {"veloc_volume", "veloc_wave", "veloc_filter"} },
      { title = "Mod: Pitch", params = {"pitch_wave", "pitch_filter"} },
      { title = "LFO", params = {"lfo_speed", "lfo_retrigger", "lfo_spread", "lfo_wave", "lfo_filter", "lfo_pitch"} },
      { title = "Unison", params = {"unison", "unison_detune", "output_spread", "spread_mode"} },
      { title = "Output", params = {"gain", "sustain", "left_output", "right_output"} },
    },
  },

  ------------------------------------------------------------
  -- Seaside Jawari
  ------------------------------------------------------------
  seaside_jawari = {
    id = "seaside_jawari",
    name = "Seaside Jawari",
    guid = "ssjw",
    category = "oscillator",
    param_prefix = "jaw",
    note_input_type = "strum",  -- Triggers strum on note_on, pitch ignored
    strum_param_num = 13,       -- Direct reference for note handler
    params = {
      -- Jawari
      { id = "bridge_shape", name = "Bridge Shape", type = "control", min = 0, max = 1, step = 0.01, default = 0.5, param_num = 9, scale = 1000, arc_multi_float = {0.1, 0.05, 0.01} },
      { id = "tuning_1st", name = "1st String", type = "option", options = "INDIAN_NOTES", default = 8, param_num = 10 },
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 12, arc_multi_float = {10, 5, 1} },
      { id = "strum", name = "Strum", type = "number", min = 0, max = 1, default = 0, param_num = 13, hidden = true },
      { id = "velocity", name = "Velocity", type = "number", min = 1, max = 127, default = 127, param_num = 15, arc_multi_float = {10, 5, 1} },
      -- Tweaks
      { id = "damping", name = "Damping", type = "control", min = 0, max = 1, step = 0.001, default = 0.995, param_num = 16, scale = 1000, arc_multi_float = {0.1, 0.05, 0.01} },
      { id = "length", name = "Length", type = "control", min = 0, max = 2, step = 0.01, default = 1, unit = "s", param_num = 17, scale = 1000, arc_multi_float = {0.5, 0.1, 0.01} },
      { id = "bounce_count", name = "Bounce Count", type = "number", min = 1, max = 10000, default = 1200, param_num = 18, arc_multi_float = {50, 20, 1} },
      { id = "strum_level", name = "Strum Level", type = "control", min = 0, max = 100, default = 25, unit = "%", param_num = 19, scale = 10, arc_multi_float = {10, 5, 1} },
      { id = "bounce_level", name = "Bounce Level", type = "control", min = 0, max = 1000, default = 150, unit = "%", param_num = 20, scale = 10, arc_multi_float = {100, 50, 10} },
      { id = "start_harmonic", name = "Start Harmonic", type = "number", min = 1, max = 20, default = 3, param_num = 21, arc_multi_float = {5, 2, 1} },
      { id = "end_harmonic", name = "End Harmonic", type = "number", min = 1, max = 20, default = 10, param_num = 22, arc_multi_float = {5, 2, 1} },
      { id = "strum_type", name = "Strum Type", type = "option", options = "STRUM_TYPES", default = 1, param_num = 23 },
      -- Output
      { id = "output", name = "Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 7 },
      { id = "output_mode", name = "Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 8 },
    },
    ui_sections = {
      { title = "Jawari", params = {"bridge_shape", "tuning_1st", "fine_tune", "velocity"} },
      { title = "Tweaks", params = {"damping", "length", "bounce_count", "strum_level", "bounce_level", "start_harmonic", "end_harmonic", "strum_type"} },
      { title = "Output", params = {"output", "output_mode"} },
    },
  },

  ------------------------------------------------------------
  -- VCO Pulsar
  ------------------------------------------------------------
  vco_pulsar = {
    id = "vco_pulsar",
    name = "VCO Pulsar",
    guid = "vcop",
    category = "oscillator",
    param_prefix = "vcop",
    note_input_type = "pitch",  -- Sets Transpose param from MIDI note, drones continuously
    transpose_param_num = 17,
    params = {
      -- Wave
      { id = "wavetable", name = "Wavetable", type = "number", min = 0, max = 271, default = 0, param_num = 9 },
      { id = "wave_offset", name = "Wave Offset", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 10, scale = 10 },
      { id = "window", name = "Window", type = "option", options = "WINDOW_TYPES", default = 1, param_num = 11 },
      -- Pulsar
      { id = "pitch_mode", name = "Pitch Mode", type = "option", options = "PITCH_MODES", default = 1, param_num = 12 },
      { id = "masking_mode", name = "Masking Mode", type = "option", options = "MASKING_MODES", default = 1, param_num = 13 },
      { id = "masking", name = "Masking", type = "control", min = 0, max = 100, default = 0, unit = "%", param_num = 14, scale = 10 },
      { id = "burst_length", name = "Burst Length", type = "number", min = 2, max = 100, default = 2, param_num = 15 },
      -- Tuning
      { id = "octave", name = "Octave", type = "number", min = -16, max = 8, default = 0, param_num = 16, hidden = true },
      { id = "transpose", name = "Transpose", type = "number", min = -60, max = 60, default = 0, param_num = 17, hidden = true },
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 18 },
      -- Output
      { id = "amplitude", name = "Amplitude", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 19, scale = 100 },
      { id = "gain", name = "Gain", type = "number", min = -40, max = 6, default = 0, param_num = 20 },
      { id = "output", name = "Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 5 },
      { id = "output_mode", name = "Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 6 },
    },
    ui_sections = {
      { title = "Wave", params = {"wavetable", "wave_offset", "window"} },
      { title = "Pulsar", params = {"pitch_mode", "masking_mode", "masking", "burst_length"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Output", params = {"amplitude", "gain", "output", "output_mode"} },
    },
  },

  ------------------------------------------------------------
  -- VCO Waveshaping
  ------------------------------------------------------------
  vco_waveshaping = {
    id = "vco_waveshaping",
    name = "VCO Waveshaping",
    guid = "vcow",
    category = "oscillator",
    param_prefix = "vcow",
    note_input_type = "pitch",  -- Sets Transpose param from MIDI note, drones continuously
    transpose_param_num = 13,
    params = {
      -- VCO
      { id = "waveshape", name = "Waveshape", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 11, scale = 10 },
      { id = "oversampling", name = "Oversampling", type = "option", options = "OVERSAMPLING_OPTIONS", default = 1, param_num = 21 },
      { id = "fm_scale", name = "FM Scale", type = "number", min = 1, max = 1000, default = 100, param_num = 27 },
      -- Tuning
      { id = "octave", name = "Octave", type = "number", min = -16, max = 8, default = 0, param_num = 12, hidden = true },
      { id = "transpose", name = "Transpose", type = "number", min = -60, max = 60, default = 0, param_num = 13, hidden = true },
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 14 },
      -- Triangle/Saw
      { id = "tri_saw_amplitude", name = "Tri/Saw Amp", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 15, scale = 100 },
      { id = "tri_saw_gain", name = "Tri/Saw Gain", type = "number", min = -40, max = 6, default = 0, param_num = 18 },
      { id = "tri_saw_output", name = "Tri/Saw Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 5 },
      -- Square
      { id = "square_amplitude", name = "Square Amp", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 16, scale = 100 },
      { id = "square_gain", name = "Square Gain", type = "number", min = -40, max = 6, default = 0, param_num = 19 },
      { id = "square_output", name = "Square Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 7 },
      -- Sub
      { id = "sub_amplitude", name = "Sub Amp", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 17, scale = 100 },
      { id = "sub_gain", name = "Sub Gain", type = "number", min = -40, max = 6, default = 0, param_num = 20 },
      { id = "sub_output", name = "Sub Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 9 },
      -- Sine
      { id = "sine_amplitude", name = "Sine Amp", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 24, scale = 100 },
      { id = "sine_gain", name = "Sine Gain", type = "number", min = -40, max = 6, default = 0, param_num = 25 },
      { id = "sine_output", name = "Sine Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 22 },
    },
    ui_sections = {
      { title = "VCO", params = {"waveshape", "oversampling", "fm_scale"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Triangle/Saw", params = {"tri_saw_amplitude", "tri_saw_gain", "tri_saw_output"} },
      { title = "Square/Pulse", params = {"square_amplitude", "square_gain", "square_output"} },
      { title = "Sub", params = {"sub_amplitude", "sub_gain", "sub_output"} },
      { title = "Sine", params = {"sine_amplitude", "sine_gain", "sine_output"} },
    },
  },

  ------------------------------------------------------------
  -- VCO Wavetable
  ------------------------------------------------------------
  vco_wavetable = {
    id = "vco_wavetable",
    name = "VCO Wavetable",
    guid = "vcot",
    category = "oscillator",
    param_prefix = "vcot",
    note_input_type = "pitch",  -- Sets Transpose param from MIDI note, drones continuously
    transpose_param_num = 9,
    params = {
      -- Wave
      { id = "wavetable", name = "Wavetable", type = "number", min = 0, max = 271, default = 0, param_num = 6 },
      { id = "wave_offset", name = "Wave Offset", type = "control", min = -100, max = 100, default = 0, unit = "%", param_num = 7, scale = 10 },
      -- Tuning
      { id = "octave", name = "Octave", type = "number", min = -16, max = 8, default = 0, param_num = 8, hidden = true },
      { id = "transpose", name = "Transpose", type = "number", min = -60, max = 60, default = 0, param_num = 9, hidden = true },
      { id = "fine_tune", name = "Fine Tune", type = "number", min = -100, max = 100, default = 0, param_num = 10 },
      -- Output
      { id = "amplitude", name = "Amplitude", type = "control", min = 0, max = 10, step = 0.1, default = 10, unit = "V", param_num = 11, scale = 100 },
      { id = "gain", name = "Gain", type = "number", min = -40, max = 6, default = 0, param_num = 12 },
      { id = "output", name = "Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 4 },
      { id = "output_mode", name = "Output Mode", type = "option", options = "OUTPUT_MODES", default = 1, param_num = 5 },
    },
    ui_sections = {
      { title = "Wave", params = {"wavetable", "wave_offset"} },
      { title = "Tuning", params = {"fine_tune"} },
      { title = "Output", params = {"amplitude", "gain", "output", "output_mode"} },
    },
  },

  ------------------------------------------------------------
  -- VCF (State Variable) - for chains
  ------------------------------------------------------------
  vcf_svf = {
    id = "vcf_svf",
    name = "VCF (SVF)",
    guid = "fsvf",
    category = "filter",
    param_prefix = "vcf",
    has_note_input = false,
    params = {
      -- Filter
      { id = "blend", name = "Blend", type = "number", min = 0, max = 200, default = 0, param_num = 1 },
      { id = "sweep", name = "Sweep", type = "control", min = -36, max = 84, step = 0.01, default = 0, unit = "ST", param_num = 2 },
      { id = "resonance", name = "Resonance", type = "number", min = 0, max = 100, default = 20, param_num = 3 },
      { id = "saturate", name = "Saturate", type = "option", options = {"Off", "On"}, default = 2, param_num = 4 },
      -- Gains
      { id = "blended_gain", name = "Blended Gain", type = "number", min = -40, max = 6, default = 0, param_num = 5 },
      { id = "lowpass_gain", name = "Lowpass Gain", type = "number", min = -40, max = 6, default = 0, param_num = 6 },
      { id = "bandpass_gain", name = "Bandpass Gain", type = "number", min = -40, max = 6, default = 0, param_num = 7 },
      { id = "highpass_gain", name = "Highpass Gain", type = "number", min = -40, max = 6, default = 0, param_num = 8 },
      -- Routing
      { id = "input", name = "Input", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 9 },
      { id = "blended_output", name = "Blended Output", type = "option", options = "OUTPUT_OPTIONS", default = 14, param_num = 10 },
      { id = "lowpass_output", name = "Lowpass Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 11 },
      { id = "bandpass_output", name = "Bandpass Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 12 },
      { id = "highpass_output", name = "Highpass Output", type = "option", options = "OUTPUT_OPTIONS", default = 1, param_num = 13 },
    },
    ui_sections = {
      { title = "Filter", params = {"blend", "sweep", "resonance", "saturate"} },
      { title = "Gains", params = {"blended_gain", "lowpass_gain", "bandpass_gain", "highpass_gain"} },
      { title = "Routing", params = {"input", "blended_output", "lowpass_output", "bandpass_output", "highpass_output"} },
    },
  },
}

------------------------------------------------------------
-- Algorithm Lists (for UI dropdowns)
------------------------------------------------------------

-- All algorithms that can receive notes (polysynths)
algorithms.VOICE_ALGORITHMS = {
  "poly_fm",
  "plaits",
  "poly_multisample",
  "poly_resonator",
  "poly_wavetable",
  "seaside_jawari",
  "vco_pulsar",
  "vco_waveshaping",
  "vco_wavetable",
}

-- Display names for voice algorithm dropdown
algorithms.VOICE_ALGORITHM_NAMES = {}
for _, id in ipairs(algorithms.VOICE_ALGORITHMS) do
  table.insert(algorithms.VOICE_ALGORITHM_NAMES, algorithms.DEFINITIONS[id].name)
end

-- All filter/effect algorithms
algorithms.EFFECT_ALGORITHMS = {
  "vcf_svf",
}

------------------------------------------------------------
-- Lookup Helpers
------------------------------------------------------------

-- Get algorithm definition by index (1-based, matches VOICE_ALGORITHMS order)
function algorithms.get_by_index(index)
  local id = algorithms.VOICE_ALGORITHMS[index]
  return id and algorithms.DEFINITIONS[id] or nil
end

-- Get algorithm definition by id
function algorithms.get_by_id(id)
  return algorithms.DEFINITIONS[id]
end

-- Resolve options reference (string = lookup in algorithms, table = use directly)
function algorithms.resolve_options(options_ref)
  if type(options_ref) == "string" then
    return algorithms[options_ref]
  end
  return options_ref
end

return algorithms

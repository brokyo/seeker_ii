-- disting_nt.lua
-- Disting NT voice parameters for lane configuration
--
-- User selects algorithm type and slot number, then adjusts algorithm-specific parameters.
-- Assumes NT already has the matching algorithm at the specified slot.

local disting_nt = {}

-- Algorithm types available on the NT
local ALGORITHMS = {
  "Poly FM",
  "Poly Plaits",
  "Poly Multisample",
  "Poly Resonator",
  "Poly Wavetable",
  "Seaside Jawari",
  "VCO Pulsar",
  "VCO Waveshaping",
  "VCO Wavetable",
}

-- Plaits model names (0-23) - from NT preset editor
local PLAITS_MODELS = {
  "Virtual Analog",
  "Waveshaping",
  "FM",
  "Granular",
  "Harmonic",
  "Wavetable",
  "Chord",
  "Speech",
  "Swarm",
  "Noise",
  "Particle",
  "String",
  "Modal",
  "Bass Drum",
  "Snare Drum",
  "Hi-Hat",
  "VA VCF",
  "PD",
  "6-op FM (1)",
  "6-op FM (2)",
  "6-op FM (3)",
  "Wave Terrain",
  "String 2",
  "Chiptune",
}

-- Sustain mode options
local SUSTAIN_MODES = {"Synth", "Piano"}

-- Poly Resonator mode options (based on Rings)
local RESONATOR_MODES = {"Modal", "Sympathetic", "String", "FM", "Quantized"}

-- Filter type options for Poly Wavetable
local FILTER_TYPES = {"Off", "Lowpass", "Bandpass", "Highpass"}

-- Output bus options (0-28: None, Input 1-12, Output 1-8, Aux 1-8)
local OUTPUT_OPTIONS = {
  "None",
  "Input 1", "Input 2", "Input 3", "Input 4", "Input 5", "Input 6",
  "Input 7", "Input 8", "Input 9", "Input 10", "Input 11", "Input 12",
  "Output 1", "Output 2", "Output 3", "Output 4",
  "Output 5", "Output 6", "Output 7", "Output 8",
  "Aux 1", "Aux 2", "Aux 3", "Aux 4", "Aux 5", "Aux 6", "Aux 7", "Aux 8",
}

-- Output mode options
local OUTPUT_MODES = {"Add", "Replace"}

-- LFO retrigger options for Poly Wavetable
local LFO_RETRIGGER_MODES = {"Poly", "Mono", "Off"}

-- Spread mode options for Poly Wavetable
local SPREAD_MODES = {"By Voice", "By Pitch", "Random"}

-- Jawari strum type options
local STRUM_TYPES = {"Flat", "Ramped"}

-- VCO Pulsar window options
local WINDOW_TYPES = {"Rectangular", "Linear Atk", "Linear Dcy", "Gaussian"}

-- VCO Pulsar pitch mode options
local PITCH_MODES = {"Independent", "Tracking"}

-- VCO Pulsar masking mode options
local MASKING_MODES = {"Stochastic", "Burst"}

-- VCO Waveshaping oversampling options
local OVERSAMPLING_OPTIONS = {"None", "2x", "4x"}

-- Note names for filter frequency display (MIDI note 0-127)
local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function midi_to_note_name(midi_note)
  local octave = math.floor(midi_note / 12) - 1
  local note_idx = (midi_note % 12) + 1
  return NOTE_NAMES[note_idx] .. octave
end

-- Algorithm index to PARAM_NUMS key mapping
local ALGORITHM_KEYS = {
  "poly_fm", "plaits", "poly_multisample", "poly_resonator", "poly_wavetable",
  "seaside_jawari", "vco_pulsar", "vco_waveshaping", "vco_wavetable"
}

-- i2c parameter numbers by algorithm (1-based per NT docs)
local PARAM_NUMS = {
  poly_fm = {
    sustain_mode = 8,
    bank = 10,
    voice = 11,
    i2c_channel = 13,
    left_output = 14,
    right_output = 15,
    brightness = 28,
    envelope_scale = 29,
    fine_tune = 31,
    gain = 32,
    sustain = 50,
  },

  plaits = {
    sustain_mode = 8,
    model = 9,
    fine_tune = 11,
    harmonics = 12,
    timbre = 13,
    morph = 14,
    fm = 15,
    timbre_mod = 16,
    morph_mod = 17,
    lpg = 18,
    decay = 19,
    level_input = 20,
    fm_input = 21,
    harmonics_input = 22,
    timbre_input = 23,
    morph_input = 24,
    main_output = 25,
    aux_output = 26,
    output_mode = 27,
    i2c_channel = 31,
  },

  poly_multisample = {
    folder = 22,
    left_output = 23,
    right_output = 24,
    gain = 25,
    pan = 26,
    i2c_channel = 28,
    envelope = 29,
    attack = 30,
    decay = 31,
    sustain = 32,
    release = 33,
    loop = 66,
  },

  poly_resonator = {
    sustain_mode = 8,
    mode = 9,
    synth_effect = 10,
    fine_tune = 12,
    resolution = 13,
    structure = 14,
    brightness = 15,
    damping = 16,
    position = 17,
    noise_gate = 19,
    input_gain = 20,
    audio_input = 21,
    odd_output = 22,
    even_output = 23,
    odd_output_mode = 24,
    even_output_mode = 25,
    output_gain = 26,
    dry_gain = 27,
    i2c_channel = 29,
  },

  poly_wavetable = {
    wavetable = 8,
    wave_offset = 9,
    wave_spread = 10,
    fine_tune = 12,
    -- Envelope 1
    env1_attack = 13,
    env1_decay = 14,
    env1_sustain = 15,
    env1_release = 16,
    env1_attack_shape = 17,
    env1_decay_shape = 18,
    -- Envelope 2
    env2_attack = 19,
    env2_decay = 20,
    env2_sustain = 21,
    env2_release = 22,
    env2_attack_shape = 23,
    env2_decay_shape = 24,
    -- Filter
    filter_type = 25,
    filter_freq = 26,
    filter_q = 27,
    -- Modulation matrix
    veloc_volume = 28,
    veloc_wave = 29,
    veloc_filter = 30,
    pitch_wave = 31,
    pitch_filter = 32,
    env1_wave = 33,
    env1_filter = 34,
    env2_wave = 35,
    env2_filter = 36,
    env2_pitch = 37,
    lfo_wave = 38,
    lfo_filter = 39,
    lfo_pitch = 40,
    -- LFO
    lfo_speed = 41,
    lfo_retrigger = 50,
    lfo_spread = 51,
    -- Output
    gain = 42,
    sustain = 43,
    unison = 45,
    unison_detune = 46,
    output_spread = 47,
    spread_mode = 48,
    sustain_mode = 49,
    max_voices = 57,
    i2c_channel = 60,
    left_output = 61,
    right_output = 62,
  },

  seaside_jawari = {
    -- Routing (input buses)
    strum_input = 2,
    bridge_shape_input = 3,
    reset_input = 4,
    voct_main_input = 5,
    voct_1st_input = 6,
    output = 7,
    output_mode = 8,
    -- Jawari params
    bridge_shape = 9,
    tuning_1st = 10,
    fine_tune = 12,
    strum = 13,
    reset = 14,
    velocity = 15,
    -- Tweaks
    damping = 16,
    length = 17,
    bounce_count = 18,
    strum_level = 19,
    bounce_level = 20,
    start_harmonic = 21,
    end_harmonic = 22,
    strum_type = 23,
  },

  vco_pulsar = {
    -- Routing
    pitch_input = 2,
    formant_input = 3,
    wave_input = 4,
    output = 5,
    output_mode = 6,
    inverse_output = 7,
    inverse_output_mode = 8,
    -- VCO
    wavetable = 9,
    wave_offset = 10,
    window = 11,
    pitch_mode = 12,
    masking_mode = 13,
    masking = 14,
    burst_length = 15,
    octave = 16,
    fine_tune = 18,
    amplitude = 19,
    gain = 20,
  },

  vco_waveshaping = {
    -- Routing
    pitch_input = 2,
    shape_input = 3,
    sync_input = 4,
    tri_saw_output = 5,
    tri_saw_mode = 6,
    square_output = 7,
    square_mode = 8,
    sub_output = 9,
    sub_mode = 10,
    -- VCO
    waveshape = 11,
    octave = 12,
    fine_tune = 14,
    -- Amplitudes
    tri_saw_amplitude = 15,
    square_amplitude = 16,
    sub_amplitude = 17,
    -- Gains
    tri_saw_gain = 18,
    square_gain = 19,
    sub_gain = 20,
    -- Oversampling
    oversampling = 21,
    -- Sine
    sine_output = 22,
    sine_mode = 23,
    sine_amplitude = 24,
    sine_gain = 25,
    -- FM
    fm_input = 26,
    fm_scale = 27,
  },

  vco_wavetable = {
    -- Routing
    pitch_input = 2,
    wave_input = 3,
    output = 4,
    output_mode = 5,
    -- VCO
    wavetable = 6,
    wave_offset = 7,
    octave = 8,
    fine_tune = 10,
    amplitude = 11,
    gain = 12,
  },
}

------------------------------------------------------------
-- i2c Communication Helpers
------------------------------------------------------------

local I2C_ADDRESS = 0x41

local CMD = {
  SET_PARAM      = 0x46,
  NOTE_PITCH     = 0x54,
  NOTE_ON        = 0x55,
  NOTE_OFF       = 0x56,
  ALL_NOTES_OFF  = 0x57,
  NOTE_PITCH_CH  = 0x68,
  NOTE_ON_CH     = 0x69,
  NOTE_OFF_CH    = 0x6A,
}

local function split_bytes(value)
  local msb = math.floor(value / 256) % 256
  local lsb = value % 256
  return msb, lsb
end

local function to_unsigned(value)
  if value < 0 then
    return 65536 + value
  end
  return value
end

local function i2c_send(bytes)
  local bytestring = string.char(table.unpack(bytes))
  crow.ii.raw(I2C_ADDRESS, bytestring)
end

-- Select which algorithm slot receives subsequent parameter changes
local function select_algorithm(slot)
  local msb, lsb = split_bytes(slot)
  i2c_send({CMD.SET_PARAM, 255, msb, lsb})
end

-- Set parameter to actual value (after calling select_algorithm)
local function set_param(param_num, value)
  local unsigned = to_unsigned(value)
  local msb, lsb = split_bytes(unsigned)
  i2c_send({CMD.SET_PARAM, param_num, msb, lsb})
end

-- Convert MIDI note to pitch value (0V = middle C = MIDI 60)
local function midi_to_pitch(midi_note)
  local volts = (midi_note - 60) / 12
  return math.floor(volts * 1638.4)
end


------------------------------------------------------------
-- i2c Param Sending (uses lane's algorithm slot)
------------------------------------------------------------

local function send_param_for_lane(lane_idx, param_num, value)
  if param_num == nil then return end
  local slot = params:get("lane_" .. lane_idx .. "_dnt_slot")
  select_algorithm(slot)
  set_param(param_num, value)
end

------------------------------------------------------------
-- Per-Lane Parameter Creation
------------------------------------------------------------

local function create_poly_fm_params(i)
  local prefix = "lane_" .. i .. "_dnt_pfm_"

  params:add_option(prefix .. "sustain_mode", "Sustain Mode", SUSTAIN_MODES, 1)
  params:set_action(prefix .. "sustain_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.sustain_mode, value - 1)
  end)

  params:add_option(prefix .. "sustain", "Sustain", {"Off", "On"}, 1)
  params:set_action(prefix .. "sustain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.sustain, value - 1)
  end)

  params:add_number(prefix .. "bank", "Bank", 1, 21, 1)
  params:set_action(prefix .. "bank", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.bank, value)
  end)

  params:add_number(prefix .. "voice", "Voice", 1, 32, 1)
  params:set_action(prefix .. "voice", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.voice, value)
  end)

  params:add_control(prefix .. "brightness", "Brightness",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "brightness", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.brightness, math.floor(value))
  end)

  params:add_control(prefix .. "envelope_scale", "Envelope Scale",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "envelope_scale", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.envelope_scale, math.floor(value))
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.fine_tune, value)
  end)

  params:add_number(prefix .. "gain", "Gain", -40, 6, 0)
  params:set_action(prefix .. "gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.gain, value)
  end)

  params:add_option(prefix .. "left_output", "Left Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "left_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.left_output, value - 1)
  end)

  params:add_option(prefix .. "right_output", "Right Output", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "right_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_fm.right_output, value - 1)
  end)
end

local function create_plaits_params(i)
  local prefix = "lane_" .. i .. "_dnt_plaits_"

  params:add_option(prefix .. "sustain_mode", "Sustain Mode", SUSTAIN_MODES, 1)
  params:set_action(prefix .. "sustain_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.sustain_mode, value - 1)
  end)

  params:add_option(prefix .. "model", "Model", PLAITS_MODELS, 1)
  params:set_action(prefix .. "model", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.model, value - 1)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.fine_tune, value)
  end)

  params:add_number(prefix .. "harmonics", "Harmonics", 0, 127, 64)
  params:set_action(prefix .. "harmonics", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.harmonics, value)
  end)

  params:add_number(prefix .. "timbre", "Timbre", 0, 127, 64)
  params:set_action(prefix .. "timbre", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.timbre, value)
  end)

  params:add_number(prefix .. "morph", "Morph", 0, 127, 64)
  params:set_action(prefix .. "morph", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.morph, value)
  end)

  params:add_control(prefix .. "fm", "FM",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "fm", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.fm, math.floor(value))
  end)

  params:add_control(prefix .. "timbre_mod", "Timbre Mod",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "timbre_mod", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.timbre_mod, math.floor(value))
  end)

  params:add_control(prefix .. "morph_mod", "Morph Mod",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "morph_mod", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.morph_mod, math.floor(value))
  end)

  params:add_number(prefix .. "lpg", "Low-pass Gate", 0, 127, 127)
  params:set_action(prefix .. "lpg", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.lpg, value)
  end)

  params:add_number(prefix .. "decay", "Time/Decay", 0, 127, 64)
  params:set_action(prefix .. "decay", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.decay, value)
  end)

  -- CV Inputs
  params:add_option(prefix .. "level_input", "Level Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "level_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.level_input, value - 1)
  end)

  params:add_option(prefix .. "fm_input", "FM Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "fm_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.fm_input, value - 1)
  end)

  params:add_option(prefix .. "harmonics_input", "Harmonics Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "harmonics_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.harmonics_input, value - 1)
  end)

  params:add_option(prefix .. "timbre_input", "Timbre Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "timbre_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.timbre_input, value - 1)
  end)

  params:add_option(prefix .. "morph_input", "Morph Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "morph_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.morph_input, value - 1)
  end)

  -- Outputs
  params:add_option(prefix .. "main_output", "Main Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "main_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.main_output, value - 1)
  end)

  params:add_option(prefix .. "aux_output", "Aux Output", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "aux_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.aux_output, value - 1)
  end)

  params:add_option(prefix .. "output_mode", "Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.plaits.output_mode, value - 1)
  end)
end

local function create_multisample_params(i)
  local prefix = "lane_" .. i .. "_dnt_pm_"

  params:add_number(prefix .. "folder", "Folder", 0, 99, 0)
  params:set_action(prefix .. "folder", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.folder, value)
  end)

  params:add_number(prefix .. "gain", "Gain", -40, 24, 0)
  params:set_action(prefix .. "gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.gain, value)
  end)

  params:add_number(prefix .. "pan", "Pan", -100, 100, 0)
  params:set_action(prefix .. "pan", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.pan, value)
  end)

  params:add_option(prefix .. "envelope", "Envelope", {"Off", "On"}, 1)
  params:set_action(prefix .. "envelope", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.envelope, value - 1)
  end)

  params:add_number(prefix .. "attack", "Attack", 0, 127, 0)
  params:set_action(prefix .. "attack", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.attack, value)
  end)

  params:add_number(prefix .. "decay", "Decay", 0, 127, 60)
  params:set_action(prefix .. "decay", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.decay, value)
  end)

  params:add_control(prefix .. "sustain", "Sustain",
    controlspec.new(0, 100, 'lin', 1, 100, "%"))
  params:set_action(prefix .. "sustain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.sustain, math.floor(value))
  end)

  params:add_number(prefix .. "release", "Release", 0, 127, 77)
  params:set_action(prefix .. "release", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.release, value)
  end)

  params:add_option(prefix .. "loop", "Loop", {"From WAV", "Off", "On"}, 1)
  params:set_action(prefix .. "loop", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.loop, value - 1)
  end)

  params:add_option(prefix .. "left_output", "Left Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "left_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.left_output, value - 1)
  end)

  params:add_option(prefix .. "right_output", "Right Output", OUTPUT_OPTIONS, 15)
  params:set_action(prefix .. "right_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_multisample.right_output, value - 1)
  end)
end

local function create_poly_resonator_params(i)
  local prefix = "lane_" .. i .. "_dnt_pres_"

  params:add_option(prefix .. "sustain_mode", "Sustain Mode", SUSTAIN_MODES, 1)
  params:set_action(prefix .. "sustain_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.sustain_mode, value - 1)
  end)

  params:add_option(prefix .. "mode", "Mode", RESONATOR_MODES, 1)
  params:set_action(prefix .. "mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.mode, value - 1)
  end)

  params:add_option(prefix .. "synth_effect", "Synth Effect", {"Off", "On"}, 1)
  params:set_action(prefix .. "synth_effect", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.synth_effect, value - 1)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.fine_tune, value)
  end)

  params:add_number(prefix .. "resolution", "Resolution", 8, 64, 16)
  params:set_action(prefix .. "resolution", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.resolution, value)
  end)

  params:add_number(prefix .. "structure", "Structure", 0, 127, 64)
  params:set_action(prefix .. "structure", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.structure, value)
  end)

  params:add_number(prefix .. "brightness", "Brightness", 0, 127, 64)
  params:set_action(prefix .. "brightness", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.brightness, value)
  end)

  params:add_number(prefix .. "damping", "Damping", 0, 127, 64)
  params:set_action(prefix .. "damping", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.damping, value)
  end)

  params:add_number(prefix .. "position", "Position", 0, 127, 64)
  params:set_action(prefix .. "position", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.position, value)
  end)

  params:add_option(prefix .. "noise_gate", "Noise Gate", {"Off", "On"}, 2)
  params:set_action(prefix .. "noise_gate", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.noise_gate, value - 1)
  end)

  params:add_number(prefix .. "input_gain", "Input Gain", -40, 12, 0)
  params:set_action(prefix .. "input_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.input_gain, value)
  end)

  params:add_option(prefix .. "audio_input", "Audio Input", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "audio_input", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.audio_input, value - 1)
  end)

  params:add_option(prefix .. "odd_output", "Odd Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "odd_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.odd_output, value - 1)
  end)

  params:add_option(prefix .. "even_output", "Even Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "even_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.even_output, value - 1)
  end)

  params:add_option(prefix .. "odd_output_mode", "Odd Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "odd_output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.odd_output_mode, value - 1)
  end)

  params:add_option(prefix .. "even_output_mode", "Even Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "even_output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.even_output_mode, value - 1)
  end)

  params:add_number(prefix .. "output_gain", "Output Gain", -40, 12, 0)
  params:set_action(prefix .. "output_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.output_gain, value)
  end)

  params:add_number(prefix .. "dry_gain", "Dry Gain", -40, 12, -40)
  params:set_action(prefix .. "dry_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_resonator.dry_gain, value)
  end)
end

local function create_poly_wavetable_params(i)
  local prefix = "lane_" .. i .. "_dnt_pwt_"

  params:add_option(prefix .. "sustain_mode", "Sustain Mode", SUSTAIN_MODES, 1)
  params:set_action(prefix .. "sustain_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.sustain_mode, value - 1)
  end)

  params:add_number(prefix .. "wavetable", "Wavetable", 0, 271, 0)
  params:set_action(prefix .. "wavetable", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.wavetable, value)
  end)

  params:add_control(prefix .. "wave_offset", "Wave Offset",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "wave_offset", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.wave_offset, math.floor(value))
  end)

  params:add_control(prefix .. "wave_spread", "Wave Spread",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "wave_spread", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.wave_spread, math.floor(value))
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.fine_tune, value)
  end)

  -- Envelope 1
  params:add_number(prefix .. "env1_attack", "Env 1 Attack", 0, 127, 20)
  params:set_action(prefix .. "env1_attack", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_attack, value)
  end)

  params:add_number(prefix .. "env1_decay", "Env 1 Decay", 0, 127, 60)
  params:set_action(prefix .. "env1_decay", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_decay, value)
  end)

  params:add_number(prefix .. "env1_sustain", "Env 1 Sustain", 0, 127, 80)
  params:set_action(prefix .. "env1_sustain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_sustain, value)
  end)

  params:add_number(prefix .. "env1_release", "Env 1 Release", 0, 127, 60)
  params:set_action(prefix .. "env1_release", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_release, value)
  end)

  params:add_number(prefix .. "env1_attack_shape", "Env 1 Atk Shape", 0, 127, 64)
  params:set_action(prefix .. "env1_attack_shape", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_attack_shape, value)
  end)

  params:add_number(prefix .. "env1_decay_shape", "Env 1 Dcy Shape", 0, 127, 64)
  params:set_action(prefix .. "env1_decay_shape", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_decay_shape, value)
  end)

  -- Envelope 2
  params:add_number(prefix .. "env2_attack", "Env 2 Attack", 0, 127, 60)
  params:set_action(prefix .. "env2_attack", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_attack, value)
  end)

  params:add_number(prefix .. "env2_decay", "Env 2 Decay", 0, 127, 70)
  params:set_action(prefix .. "env2_decay", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_decay, value)
  end)

  params:add_number(prefix .. "env2_sustain", "Env 2 Sustain", -127, 127, 64)
  params:set_action(prefix .. "env2_sustain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_sustain, value)
  end)

  params:add_number(prefix .. "env2_release", "Env 2 Release", 0, 127, 50)
  params:set_action(prefix .. "env2_release", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_release, value)
  end)

  params:add_number(prefix .. "env2_attack_shape", "Env 2 Atk Shape", 0, 127, 64)
  params:set_action(prefix .. "env2_attack_shape", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_attack_shape, value)
  end)

  params:add_number(prefix .. "env2_decay_shape", "Env 2 Dcy Shape", 0, 127, 64)
  params:set_action(prefix .. "env2_decay_shape", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_decay_shape, value)
  end)

  -- Filter
  params:add_option(prefix .. "filter_type", "Filter Type", FILTER_TYPES, 1)
  params:set_action(prefix .. "filter_type", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.filter_type, value - 1)
  end)

  params:add_number(prefix .. "filter_freq", "Filter Freq", 0, 127, 64, function(param)
    return midi_to_note_name(param:get())
  end)
  params:set_action(prefix .. "filter_freq", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.filter_freq, value)
  end)

  params:add_number(prefix .. "filter_q", "Filter Q", 0, 100, 50)
  params:set_action(prefix .. "filter_q", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.filter_q, value)
  end)

  -- Modulation: Velocity
  params:add_control(prefix .. "veloc_volume", "Veloc > Volume",
    controlspec.new(0, 100, 'lin', 1, 100, "%"))
  params:set_action(prefix .. "veloc_volume", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.veloc_volume, math.floor(value))
  end)

  params:add_control(prefix .. "veloc_wave", "Veloc > Wave",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "veloc_wave", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.veloc_wave, math.floor(value))
  end)

  params:add_number(prefix .. "veloc_filter", "Veloc > Filter", -127, 127, 0)
  params:set_action(prefix .. "veloc_filter", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.veloc_filter, value)
  end)

  -- Modulation: Pitch
  params:add_control(prefix .. "pitch_wave", "Pitch > Wave",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "pitch_wave", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.pitch_wave, math.floor(value))
  end)

  params:add_control(prefix .. "pitch_filter", "Pitch > Filter",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "pitch_filter", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.pitch_filter, math.floor(value))
  end)

  -- Modulation: Env 1
  params:add_control(prefix .. "env1_wave", "Env1 > Wave",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "env1_wave", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_wave, math.floor(value))
  end)

  params:add_number(prefix .. "env1_filter", "Env1 > Filter", -127, 127, 0)
  params:set_action(prefix .. "env1_filter", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env1_filter, value)
  end)

  -- Modulation: Env 2
  params:add_control(prefix .. "env2_wave", "Env2 > Wave",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "env2_wave", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_wave, math.floor(value))
  end)

  params:add_number(prefix .. "env2_filter", "Env2 > Filter", -127, 127, 0)
  params:set_action(prefix .. "env2_filter", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_filter, value)
  end)

  params:add_control(prefix .. "env2_pitch", "Env2 > Pitch",
    controlspec.new(-12, 12, 'lin', 0.1, 0, "ST"))
  params:set_action(prefix .. "env2_pitch", function(value)
    -- Convert semitones to internal representation (value * 10 for 0.1 resolution)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.env2_pitch, math.floor(value * 10))
  end)

  -- Modulation: LFO
  params:add_control(prefix .. "lfo_wave", "LFO > Wave",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "lfo_wave", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_wave, math.floor(value))
  end)

  params:add_number(prefix .. "lfo_filter", "LFO > Filter", -127, 127, 0)
  params:set_action(prefix .. "lfo_filter", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_filter, value)
  end)

  params:add_control(prefix .. "lfo_pitch", "LFO > Pitch",
    controlspec.new(-12, 12, 'lin', 0.1, 0, "ST"))
  params:set_action(prefix .. "lfo_pitch", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_pitch, math.floor(value * 10))
  end)

  -- LFO
  params:add_number(prefix .. "lfo_speed", "LFO Speed", -100, 100, 90)
  params:set_action(prefix .. "lfo_speed", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_speed, value)
  end)

  params:add_option(prefix .. "lfo_retrigger", "LFO Retrigger", LFO_RETRIGGER_MODES, 1)
  params:set_action(prefix .. "lfo_retrigger", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_retrigger, value - 1)
  end)

  params:add_number(prefix .. "lfo_spread", "LFO Spread", 0, 90, 0)
  params:set_action(prefix .. "lfo_spread", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.lfo_spread, value)
  end)

  -- Unison / Girth
  params:add_number(prefix .. "unison", "Unison", 1, 8, 1)
  params:set_action(prefix .. "unison", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.unison, value)
  end)

  params:add_number(prefix .. "unison_detune", "Unison Detune", 0, 100, 10)
  params:set_action(prefix .. "unison_detune", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.unison_detune, value)
  end)

  params:add_control(prefix .. "output_spread", "Output Spread",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "output_spread", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.output_spread, math.floor(value))
  end)

  params:add_option(prefix .. "spread_mode", "Spread Mode", SPREAD_MODES, 1)
  params:set_action(prefix .. "spread_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.spread_mode, value - 1)
  end)

  -- Output
  params:add_number(prefix .. "gain", "Gain", -40, 24, 0)
  params:set_action(prefix .. "gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.gain, value)
  end)

  params:add_option(prefix .. "sustain", "Sustain", {"Off", "On"}, 1)
  params:set_action(prefix .. "sustain", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.sustain, value - 1)
  end)

  params:add_number(prefix .. "max_voices", "Max Voices", 1, 24, 24)
  params:set_action(prefix .. "max_voices", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.max_voices, value)
  end)

  params:add_option(prefix .. "left_output", "Left Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "left_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.left_output, value - 1)
  end)

  params:add_option(prefix .. "right_output", "Right Output", OUTPUT_OPTIONS, 15)
  params:set_action(prefix .. "right_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.poly_wavetable.right_output, value - 1)
  end)
end

local function create_seaside_jawari_params(i)
  local prefix = "lane_" .. i .. "_dnt_jaw_"

  -- Jawari
  params:add_control(prefix .. "bridge_shape", "Bridge Shape",
    controlspec.new(0, 1, 'lin', 0.01, 0.5, ""))
  params:set_action(prefix .. "bridge_shape", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.bridge_shape, math.floor(value * 1000))
  end)

  params:add_number(prefix .. "tuning_1st", "1st String", 0, 11, 7)
  params:set_action(prefix .. "tuning_1st", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.tuning_1st, value)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.fine_tune, value)
  end)

  params:add_number(prefix .. "velocity", "Velocity", 1, 127, 127)
  params:set_action(prefix .. "velocity", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.velocity, value)
  end)

  -- Tweaks
  params:add_control(prefix .. "damping", "Damping",
    controlspec.new(0, 1, 'lin', 0.001, 0.995, ""))
  params:set_action(prefix .. "damping", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.damping, math.floor(value * 1000))
  end)

  params:add_control(prefix .. "length", "Length",
    controlspec.new(0, 2, 'lin', 0.01, 1, "s"))
  params:set_action(prefix .. "length", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.length, math.floor(value * 1000))
  end)

  params:add_number(prefix .. "bounce_count", "Bounce Count", 1, 10000, 1200)
  params:set_action(prefix .. "bounce_count", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.bounce_count, value)
  end)

  params:add_control(prefix .. "strum_level", "Strum Level",
    controlspec.new(0, 100, 'lin', 1, 25, "%"))
  params:set_action(prefix .. "strum_level", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.strum_level, math.floor(value * 10))
  end)

  params:add_control(prefix .. "bounce_level", "Bounce Level",
    controlspec.new(0, 1000, 'lin', 1, 150, "%"))
  params:set_action(prefix .. "bounce_level", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.bounce_level, math.floor(value * 10))
  end)

  params:add_number(prefix .. "start_harmonic", "Start Harmonic", 1, 20, 3)
  params:set_action(prefix .. "start_harmonic", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.start_harmonic, value)
  end)

  params:add_number(prefix .. "end_harmonic", "End Harmonic", 1, 20, 10)
  params:set_action(prefix .. "end_harmonic", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.end_harmonic, value)
  end)

  params:add_option(prefix .. "strum_type", "Strum Type", STRUM_TYPES, 1)
  params:set_action(prefix .. "strum_type", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.strum_type, value - 1)
  end)

  -- Output
  params:add_option(prefix .. "output", "Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "output", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.output, value - 1)
  end)

  params:add_option(prefix .. "output_mode", "Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.seaside_jawari.output_mode, value - 1)
  end)
end

local function create_vco_pulsar_params(i)
  local prefix = "lane_" .. i .. "_dnt_vcop_"

  -- VCO
  params:add_number(prefix .. "wavetable", "Wavetable", 0, 271, 0)
  params:set_action(prefix .. "wavetable", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.wavetable, value)
  end)

  params:add_control(prefix .. "wave_offset", "Wave Offset",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "wave_offset", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.wave_offset, math.floor(value))
  end)

  params:add_option(prefix .. "window", "Window", WINDOW_TYPES, 1)
  params:set_action(prefix .. "window", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.window, value - 1)
  end)

  params:add_option(prefix .. "pitch_mode", "Pitch Mode", PITCH_MODES, 1)
  params:set_action(prefix .. "pitch_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.pitch_mode, value - 1)
  end)

  params:add_option(prefix .. "masking_mode", "Masking Mode", MASKING_MODES, 1)
  params:set_action(prefix .. "masking_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.masking_mode, value - 1)
  end)

  params:add_control(prefix .. "masking", "Masking",
    controlspec.new(0, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "masking", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.masking, math.floor(value))
  end)

  params:add_number(prefix .. "burst_length", "Burst Length", 2, 100, 2)
  params:set_action(prefix .. "burst_length", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.burst_length, value)
  end)

  -- Tuning
  params:add_number(prefix .. "octave", "Octave", -16, 8, 0)
  params:set_action(prefix .. "octave", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.octave, value)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.fine_tune, value)
  end)

  -- Output
  params:add_control(prefix .. "amplitude", "Amplitude",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "gain", "Gain", -40, 6, 0)
  params:set_action(prefix .. "gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.gain, value)
  end)

  params:add_option(prefix .. "output", "Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.output, value - 1)
  end)

  params:add_option(prefix .. "output_mode", "Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_pulsar.output_mode, value - 1)
  end)
end

local function create_vco_waveshaping_params(i)
  local prefix = "lane_" .. i .. "_dnt_vcow_"

  -- VCO
  params:add_control(prefix .. "waveshape", "Waveshape",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "waveshape", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.waveshape, math.floor(value))
  end)

  -- Tuning
  params:add_number(prefix .. "octave", "Octave", -16, 8, 0)
  params:set_action(prefix .. "octave", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.octave, value)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.fine_tune, value)
  end)

  params:add_option(prefix .. "oversampling", "Oversampling", OVERSAMPLING_OPTIONS, 1)
  params:set_action(prefix .. "oversampling", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.oversampling, value - 1)
  end)

  params:add_number(prefix .. "fm_scale", "FM Scale", 1, 1000, 100)
  params:set_action(prefix .. "fm_scale", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.fm_scale, value)
  end)

  -- Triangle/Saw
  params:add_control(prefix .. "tri_saw_amplitude", "Tri/Saw Amp",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "tri_saw_amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.tri_saw_amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "tri_saw_gain", "Tri/Saw Gain", -40, 6, 0)
  params:set_action(prefix .. "tri_saw_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.tri_saw_gain, value)
  end)

  params:add_option(prefix .. "tri_saw_output", "Tri/Saw Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "tri_saw_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.tri_saw_output, value - 1)
  end)

  -- Square/Pulse
  params:add_control(prefix .. "square_amplitude", "Square Amp",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "square_amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.square_amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "square_gain", "Square Gain", -40, 6, 0)
  params:set_action(prefix .. "square_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.square_gain, value)
  end)

  params:add_option(prefix .. "square_output", "Square Output", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "square_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.square_output, value - 1)
  end)

  -- Sub
  params:add_control(prefix .. "sub_amplitude", "Sub Amp",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "sub_amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sub_amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "sub_gain", "Sub Gain", -40, 6, 0)
  params:set_action(prefix .. "sub_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sub_gain, value)
  end)

  params:add_option(prefix .. "sub_output", "Sub Output", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "sub_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sub_output, value - 1)
  end)

  -- Sine
  params:add_control(prefix .. "sine_amplitude", "Sine Amp",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "sine_amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sine_amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "sine_gain", "Sine Gain", -40, 6, 0)
  params:set_action(prefix .. "sine_gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sine_gain, value)
  end)

  params:add_option(prefix .. "sine_output", "Sine Output", OUTPUT_OPTIONS, 1)
  params:set_action(prefix .. "sine_output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_waveshaping.sine_output, value - 1)
  end)
end

local function create_vco_wavetable_params(i)
  local prefix = "lane_" .. i .. "_dnt_vcot_"

  -- VCO
  params:add_number(prefix .. "wavetable", "Wavetable", 0, 271, 0)
  params:set_action(prefix .. "wavetable", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.wavetable, value)
  end)

  params:add_control(prefix .. "wave_offset", "Wave Offset",
    controlspec.new(-100, 100, 'lin', 1, 0, "%"))
  params:set_action(prefix .. "wave_offset", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.wave_offset, math.floor(value))
  end)

  -- Tuning
  params:add_number(prefix .. "octave", "Octave", -16, 8, 0)
  params:set_action(prefix .. "octave", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.octave, value)
  end)

  params:add_number(prefix .. "fine_tune", "Fine Tune", -100, 100, 0)
  params:set_action(prefix .. "fine_tune", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.fine_tune, value)
  end)

  -- Output
  params:add_control(prefix .. "amplitude", "Amplitude",
    controlspec.new(0, 10, 'lin', 0.1, 10, "V"))
  params:set_action(prefix .. "amplitude", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.amplitude, math.floor(value * 100))
  end)

  params:add_number(prefix .. "gain", "Gain", -40, 6, 0)
  params:set_action(prefix .. "gain", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.gain, value)
  end)

  params:add_option(prefix .. "output", "Output", OUTPUT_OPTIONS, 14)
  params:set_action(prefix .. "output", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.output, value - 1)
  end)

  params:add_option(prefix .. "output_mode", "Output Mode", OUTPUT_MODES, 1)
  params:set_action(prefix .. "output_mode", function(value)
    send_param_for_lane(i, PARAM_NUMS.vco_wavetable.output_mode, value - 1)
  end)
end

------------------------------------------------------------
-- Main Entry Point
------------------------------------------------------------

-- Set the NT algorithm's i2c_channel parameter to match the slot number.
-- Algorithm and slot can be provided directly or read from params.
local function sync_i2c_channel(lane_idx, algorithm, slot)
  algorithm = algorithm or params:get("lane_" .. lane_idx .. "_dnt_algorithm")
  slot = slot or params:get("lane_" .. lane_idx .. "_dnt_slot")

  local key = ALGORITHM_KEYS[algorithm]
  local i2c_param = key and PARAM_NUMS[key].i2c_channel

  if i2c_param then
    select_algorithm(slot)
    set_param(i2c_param, slot)
  end
end

function disting_nt.create_params(i)
  -- Lane activation
  params:add_binary("lane_" .. i .. "_disting_nt_active", "Disting NT Active", "toggle", 0)
  params:set_action("lane_" .. i .. "_disting_nt_active", function(value)
    _seeker.lanes[i].disting_nt_active = (value == 1)
    if value == 1 then
      sync_i2c_channel(i)  -- Set i2c channel when activated
    end
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  -- Lane volume
  params:add_control("lane_" .. i .. "_disting_nt_volume", "Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1, ""))
  params:set_action("lane_" .. i .. "_disting_nt_volume", function(value)
    _seeker.lanes[i].disting_nt_volume = value
  end)

  -- Which algorithm type (must match what's actually at this slot on NT)
  params:add_option("lane_" .. i .. "_dnt_algorithm", "Algorithm", ALGORITHMS, 1)
  params:set_action("lane_" .. i .. "_dnt_algorithm", function(value)
    sync_i2c_channel(i, value, nil)  -- pass new algorithm directly
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  -- NT slot: which algorithm instance to control (also used as note channel)
  params:add_number("lane_" .. i .. "_dnt_slot", "Slot", 1, 32, i)
  params:set_action("lane_" .. i .. "_dnt_slot", function(value)
    sync_i2c_channel(i, nil, value)  -- pass new slot directly
  end)

  -- Create all algorithm-specific params for this lane
  create_poly_fm_params(i)
  create_plaits_params(i)
  create_multisample_params(i)
  create_poly_resonator_params(i)
  create_poly_wavetable_params(i)
  create_seaside_jawari_params(i)
  create_vco_pulsar_params(i)
  create_vco_waveshaping_params(i)
  create_vco_wavetable_params(i)
end

------------------------------------------------------------
-- Public API: Note Control
------------------------------------------------------------

function disting_nt.note_pitch(channel, note_id, pitch)
  local msb, lsb = split_bytes(to_unsigned(pitch))
  i2c_send({CMD.NOTE_PITCH_CH, channel, note_id, msb, lsb})
end

function disting_nt.note_on(channel, note_id, velocity)
  local msb, lsb = split_bytes(velocity)
  i2c_send({CMD.NOTE_ON_CH, channel, note_id, msb, lsb})
end

function disting_nt.note_off(channel, note_id)
  i2c_send({CMD.NOTE_OFF_CH, channel, note_id})
end

function disting_nt.all_notes_off()
  i2c_send({CMD.ALL_NOTES_OFF})
end

function disting_nt.midi_to_pitch(midi_note)
  return midi_to_pitch(midi_note)
end

function disting_nt.scale_velocity(velocity_0_127, volume_multiplier)
  return math.floor(velocity_0_127 * volume_multiplier * 16384 / 127)
end

------------------------------------------------------------
-- Voice Interface (called by lane.lua)
------------------------------------------------------------

function disting_nt.is_active(lane_idx)
  return params:get("lane_" .. lane_idx .. "_disting_nt_active") == 1
end

function disting_nt.handle_note_on(lane_idx, note, event_velocity)
  local voice_volume = params:get("lane_" .. lane_idx .. "_disting_nt_volume")
  local lane_volume = params:get("lane_" .. lane_idx .. "_volume")
  local slot = params:get("lane_" .. lane_idx .. "_dnt_slot")  -- slot = channel
  local nt_pitch = disting_nt.midi_to_pitch(note)
  local nt_velocity = disting_nt.scale_velocity(event_velocity, voice_volume * lane_volume)

  disting_nt.note_pitch(slot, note, nt_pitch)
  disting_nt.note_on(slot, note, nt_velocity)
end

function disting_nt.handle_note_off(lane_idx, note)
  local slot = params:get("lane_" .. lane_idx .. "_dnt_slot")  -- slot = channel
  disting_nt.note_off(slot, note)
end

------------------------------------------------------------
-- UI Helper: Returns param entries for lane_config
------------------------------------------------------------

function disting_nt.get_params_for_ui(lane_idx)
  local algorithm = params:get("lane_" .. lane_idx .. "_dnt_algorithm")
  local prefix = "lane_" .. lane_idx .. "_dnt_"

  -- Slot assignment (algorithm selector is added by lane_config)
  local entries = {
    { id = "lane_" .. lane_idx .. "_dnt_slot" },
  }

  -- Helper to append algorithm-specific params
  local function add_entries(new_entries)
    for _, entry in ipairs(new_entries) do
      table.insert(entries, entry)
    end
  end

  -- Poly FM
  if algorithm == 1 then
    add_entries({
      { separator = true, title = "Voice" },
      { id = prefix .. "pfm_sustain_mode" },
      { id = prefix .. "pfm_bank" },
      { id = prefix .. "pfm_voice" },

      { separator = true, title = "Sound" },
      { id = prefix .. "pfm_sustain" },
      { id = prefix .. "pfm_brightness", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pfm_envelope_scale", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Tuning" },
      { id = prefix .. "pfm_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Output" },
      { id = prefix .. "pfm_gain" },
      { id = prefix .. "pfm_left_output" },
      { id = prefix .. "pfm_right_output" },
    })

  -- Plaits
  elseif algorithm == 2 then
    add_entries({
      { separator = true, title = "Voice" },
      { id = prefix .. "plaits_sustain_mode" },
      { id = prefix .. "plaits_model" },
      { id = prefix .. "plaits_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Oscillator" },
      { id = prefix .. "plaits_harmonics", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "plaits_timbre", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "plaits_morph", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Modulation" },
      { id = prefix .. "plaits_fm", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "plaits_timbre_mod", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "plaits_morph_mod", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope" },
      { id = prefix .. "plaits_lpg", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "plaits_decay", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Output" },
      { id = prefix .. "plaits_main_output" },
      { id = prefix .. "plaits_aux_output" },
      { id = prefix .. "plaits_output_mode" },

      { separator = true, title = "CV Inputs" },
      { id = prefix .. "plaits_level_input" },
      { id = prefix .. "plaits_fm_input" },
      { id = prefix .. "plaits_harmonics_input" },
      { id = prefix .. "plaits_timbre_input" },
      { id = prefix .. "plaits_morph_input" },
    })

  -- Poly Multisample
  elseif algorithm == 3 then
    local envelope_on = {{ id = prefix .. "pm_envelope", operator = "=", value = "On" }}
    add_entries({
      { separator = true, title = "Sample" },
      { id = prefix .. "pm_folder" },
      { id = prefix .. "pm_gain" },
      { id = prefix .. "pm_pan", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope" },
      { id = prefix .. "pm_envelope" },
      { id = "lane_" .. lane_idx .. "_dnt_pm_visual_edit", is_action = true, custom_name = "Visual Edit", custom_value = "...", view_conditions = envelope_on },
      { id = prefix .. "pm_attack", arc_multi_float = {10, 5, 1}, view_conditions = envelope_on },
      { id = prefix .. "pm_decay", arc_multi_float = {10, 5, 1}, view_conditions = envelope_on },
      { id = prefix .. "pm_sustain", arc_multi_float = {10, 5, 1}, view_conditions = envelope_on },
      { id = prefix .. "pm_release", arc_multi_float = {10, 5, 1}, view_conditions = envelope_on },

      { separator = true, title = "Output" },
      { id = prefix .. "pm_left_output" },
      { id = prefix .. "pm_right_output" },
    })

  -- Poly Resonator
  elseif algorithm == 4 then
    add_entries({
      { separator = true, title = "Voice" },
      { id = prefix .. "pres_sustain_mode" },
      { id = prefix .. "pres_mode" },
      { id = prefix .. "pres_synth_effect" },

      { separator = true, title = "Tuning" },
      { id = prefix .. "pres_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Resonator" },
      { id = prefix .. "pres_resolution", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pres_structure", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pres_brightness", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pres_damping", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pres_position", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Input" },
      { id = prefix .. "pres_noise_gate" },
      { id = prefix .. "pres_input_gain" },
      { id = prefix .. "pres_audio_input" },

      { separator = true, title = "Output" },
      { id = prefix .. "pres_output_gain" },
      { id = prefix .. "pres_dry_gain" },
      { id = prefix .. "pres_odd_output" },
      { id = prefix .. "pres_even_output" },
      { id = prefix .. "pres_odd_output_mode" },
      { id = prefix .. "pres_even_output_mode" },
    })

  -- Poly Wavetable
  elseif algorithm == 5 then
    add_entries({
      { separator = true, title = "Voice" },
      { id = prefix .. "pwt_sustain_mode" },
      { id = prefix .. "pwt_wavetable" },
      { id = prefix .. "pwt_max_voices" },

      { separator = true, title = "Wave" },
      { id = prefix .. "pwt_wave_offset", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_wave_spread", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Tuning" },
      { id = prefix .. "pwt_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope 1" },
      { id = "lane_" .. lane_idx .. "_dnt_pwt_env1_visual_edit", is_action = true, custom_name = "Visual Edit", custom_value = "..." },
      { id = prefix .. "pwt_env1_attack", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_decay", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_sustain", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_release", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_attack_shape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_decay_shape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_wave", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env1_filter", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope 2" },
      { id = "lane_" .. lane_idx .. "_dnt_pwt_env2_visual_edit", is_action = true, custom_name = "Visual Edit", custom_value = "..." },
      { id = prefix .. "pwt_env2_attack", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_decay", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_sustain", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_release", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_attack_shape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_decay_shape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_wave", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_filter", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_env2_pitch", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Filter" },
      { id = prefix .. "pwt_filter_type" },
      { id = prefix .. "pwt_filter_freq", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_filter_q", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Mod: Velocity" },
      { id = prefix .. "pwt_veloc_volume", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_veloc_wave", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_veloc_filter", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Mod: Pitch" },
      { id = prefix .. "pwt_pitch_wave", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_pitch_filter", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "LFO" },
      { id = prefix .. "pwt_lfo_speed", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_lfo_retrigger" },
      { id = prefix .. "pwt_lfo_spread", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_lfo_wave", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_lfo_filter", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_lfo_pitch", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Unison" },
      { id = prefix .. "pwt_unison" },
      { id = prefix .. "pwt_unison_detune", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_output_spread", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "pwt_spread_mode" },

      { separator = true, title = "Output" },
      { id = prefix .. "pwt_gain" },
      { id = prefix .. "pwt_sustain" },
      { id = prefix .. "pwt_left_output" },
      { id = prefix .. "pwt_right_output" },
    })

  -- Seaside Jawari
  elseif algorithm == 6 then
    add_entries({
      { separator = true, title = "Jawari" },
      { id = prefix .. "jaw_bridge_shape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_tuning_1st" },
      { id = prefix .. "jaw_fine_tune", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_velocity" },

      { separator = true, title = "Tweaks" },
      { id = prefix .. "jaw_damping", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_length", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_bounce_count" },
      { id = prefix .. "jaw_strum_level", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_bounce_level", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "jaw_start_harmonic" },
      { id = prefix .. "jaw_end_harmonic" },
      { id = prefix .. "jaw_strum_type" },

      { separator = true, title = "Output" },
      { id = prefix .. "jaw_output" },
      { id = prefix .. "jaw_output_mode" },
    })

  -- VCO Pulsar
  elseif algorithm == 7 then
    add_entries({
      { separator = true, title = "Wave" },
      { id = prefix .. "vcop_wavetable" },
      { id = prefix .. "vcop_wave_offset", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcop_window" },

      { separator = true, title = "Pulsar" },
      { id = prefix .. "vcop_pitch_mode" },
      { id = prefix .. "vcop_masking_mode" },
      { id = prefix .. "vcop_masking", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcop_burst_length" },

      { separator = true, title = "Tuning" },
      { id = prefix .. "vcop_octave" },
      { id = prefix .. "vcop_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Output" },
      { id = prefix .. "vcop_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcop_gain" },
      { id = prefix .. "vcop_output" },
      { id = prefix .. "vcop_output_mode" },
    })

  -- VCO Waveshaping
  elseif algorithm == 8 then
    add_entries({
      { separator = true, title = "VCO" },
      { id = prefix .. "vcow_waveshape", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcow_oversampling" },
      { id = prefix .. "vcow_fm_scale" },

      { separator = true, title = "Tuning" },
      { id = prefix .. "vcow_octave" },
      { id = prefix .. "vcow_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Triangle/Saw" },
      { id = prefix .. "vcow_tri_saw_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcow_tri_saw_gain" },
      { id = prefix .. "vcow_tri_saw_output" },

      { separator = true, title = "Square/Pulse" },
      { id = prefix .. "vcow_square_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcow_square_gain" },
      { id = prefix .. "vcow_square_output" },

      { separator = true, title = "Sub" },
      { id = prefix .. "vcow_sub_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcow_sub_gain" },
      { id = prefix .. "vcow_sub_output" },

      { separator = true, title = "Sine" },
      { id = prefix .. "vcow_sine_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcow_sine_gain" },
      { id = prefix .. "vcow_sine_output" },
    })

  -- VCO Wavetable
  elseif algorithm == 9 then
    add_entries({
      { separator = true, title = "Wave" },
      { id = prefix .. "vcot_wavetable" },
      { id = prefix .. "vcot_wave_offset", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Tuning" },
      { id = prefix .. "vcot_octave" },
      { id = prefix .. "vcot_fine_tune", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Output" },
      { id = prefix .. "vcot_amplitude", arc_multi_float = {10, 5, 1} },
      { id = prefix .. "vcot_gain" },
      { id = prefix .. "vcot_output" },
      { id = prefix .. "vcot_output_mode" },
    })
  end

  return entries
end

-- Algorithm list (for external use)
disting_nt.ALGORITHMS = ALGORITHMS

-- Diagnostic tool: send arbitrary param to NT for testing/discovery
function disting_nt.probe_param(lane_idx, param_num, value)
  print("disting_nt: probing param " .. param_num .. " = " .. value)
  send_param_for_lane(lane_idx, param_num, value)
end

return disting_nt

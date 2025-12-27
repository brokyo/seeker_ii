-- disting_nt.lua
-- Disting NT voice parameters for lane configuration
--
-- Architecture:
--   - Per-lane: active, channel, volume (which channel receives notes)
--   - Global view: edit one channel's algorithm config at a time
--   - Storage: channel_configs[N] tracks what we've sent to each channel (in-memory only)
--
-- Channel is purely an addressing mechanism - it routes i2c commands to a
-- specific algorithm instance. Each algorithm listens on its assigned channel.
--
-- No persistence: NT holds actual state. channel_configs is just a session cache
-- so the view pattern knows what values to display when switching channels.

local disting_nt = {}

-- Algorithm types available on the NT
local ALGORITHMS = {
  "DX7",
  "Plaits",
  "Poly Multisample",
  "Rings",
}

-- Default channel for each algorithm type (so common setups "just work")
local DEFAULT_CHANNELS = {
  ["DX7"] = 1,
  ["Plaits"] = 2,
  ["Poly Multisample"] = 3,
  ["Rings"] = 4,
}

-- Plaits model names (0-23)
local PLAITS_MODELS = {
  "Virtual Analog",
  "Waveshaping",
  "FM",
  "Grain",
  "Additive",
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
  "FM Drum",
  "Chirp",
  "Dust",
  "Sync",
  "Grain FM",
  "Resonator",
  "Chiptune",
  "Wavefold",
}

-- I2C mode options
local I2C_MODES = {
  "Off",
  "Pitch",
  "Trigger",
  "Pitch & Trigger",
}

-- i2c parameter numbers by algorithm (sequential from NT docs)
-- nil = not yet mapped, will skip i2c send
local PARAM_NUMS = {
  dx7 = {
    -- Globals (0-1)
    -- global_gain = 0 (skipped)
    -- sustain_mode = 1 (skipped)
    -- Per-timbre (2-13)
    bank = 2,
    voice = 3,
    -- transpose = 4 (skipped)
    -- fine_tune = 5 (skipped)
    brightness = 6,
    envelope_scale = 7,
    -- gain = 8 (skipped)
    -- sustain = 9 (skipped)
    -- press_volume = 10 (skipped - MPE)
    -- press_bright = 11 (skipped - MPE)
    -- mpe_y_volume = 12 (skipped - MPE)
    -- mpe_y_bright = 13 (skipped - MPE)
    -- Per-timbre setup (14-19)
    left_output = 14,
    right_output = 15,
    -- midi_channel = 16 (skipped)
    -- mpe_channels = 17 (skipped)
    i2c_channel = 18,
    -- bend_range = 19 (skipped)
  },

  plaits = {
    -- Params are sequential; skipped params still count
    model = 0,
    -- coarse_tune = 1 (skipped)
    -- fine_tune = 2 (skipped)
    harmonics = 3,
    timbre = 4,
    morph = 5,
    fm = 6,
    timbre_mod = 7,
    morph_mod = 8,
    lpg = 9,
    decay = 10,
    -- trigger_input = 11 (skipped)
    -- level_input = 12 (skipped)
    -- cv_input = 13 (skipped)
    fm_input = 14,
    harmonics_input = 15,
    timbre_input = 16,
    morph_input = 17,
    main_output = 18,
    aux_output = 19,
    output_mode = 20,
    -- main_gain = 21 (skipped)
    -- aux_gain = 22 (skipped)
    -- midi_mode = 23 (skipped)
    i2c_mode = 24,
    -- midi_channel = 25 (skipped)
    i2c_channel = 26,
  },

  poly_multisample = {
    -- Sample params (0-5)
    folder = 0,
    -- sample = 1 (skipped - usually -1 for auto)
    gain = 2,
    pan = 3,
    -- transpose = 4 (skipped)
    -- fine_tune = 5 (skipped)
    -- Crossfade (6-7)
    -- crossfade_mode = 6 (skipped)
    -- crossfade_length = 7 (skipped)
    -- Trim (8-9)
    -- loop_point_coarse = 8 (skipped)
    -- loop_point_fine = 9 (skipped)
    -- Setup (10-16)
    -- sustain_mode = 10 (skipped)
    -- sustain = 11 (skipped)
    -- gate_offset = 12 (skipped)
    -- round_robin = 13 (skipped)
    loop = 14,
    -- bend_range = 15 (skipped)
    -- confirm_change = 16 (skipped)
    -- Envelope (17-24)
    envelope = 17,
    attack = 18,
    decay = 19,
    sustain = 20,
    release = 21,
    -- velocity = 22 (skipped)
    -- press_volume = 23 (skipped - MPE)
    -- mpe_y_volume = 24 (skipped - MPE)
    -- Routing (25-29)
    left_output = 25,
    right_output = 26,
    -- midi_channel = 27 (skipped)
    -- mpe_channels = 28 (skipped)
    i2c_channel = 29,
  },

  rings = {
    -- Rings params (0-11)
    mode = 0,
    synth_effect = 1,
    -- coarse_tune = 2 (skipped)
    -- fine_tune = 3 (skipped)
    resolution = 4,
    structure = 5,
    brightness = 6,
    damping = 7,
    position = 8,
    chord = 9,
    noise_gate = 10,
    input_gain = 11,
    -- Routing (12-18)
    audio_input = 12,
    odd_output = 13,
    even_output = 14,
    -- odd_output_mode = 15 (skipped)
    -- even_output_mode = 16 (skipped)
    -- output_gain = 17 (skipped)
    -- dry_gain = 18 (skipped)
    -- Setup (19-24)
    -- midi_channel = 19 (skipped)
    -- mpe_channels = 20 (skipped)
    i2c_channel = 21,
    -- bend_range = 22 (skipped)
    -- sustain_mode = 23 (skipped)
    -- sustain = 24 (skipped)
  },
}

------------------------------------------------------------
-- i2c Communication Helpers
-- Raw i2c for disting NT (no crow convenience methods available)
------------------------------------------------------------

local I2C_ADDRESS = 0x41  -- Default disting NT i2c address

local CMD = {
  SET_PARAM      = 0x46,  -- set parameter to actual value
  NOTE_PITCH     = 0x54,  -- set pitch for note id
  NOTE_ON        = 0x55,  -- note on for note id
  NOTE_OFF       = 0x56,  -- note off for note id
  ALL_NOTES_OFF  = 0x57,  -- all notes off
  NOTE_PITCH_CH  = 0x68,  -- set pitch for note id, with channel
  NOTE_ON_CH     = 0x69,  -- note on for note id, with channel
  NOTE_OFF_CH    = 0x6A,  -- note off for note id, with channel
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
  crow.ii.raw(I2C_ADDRESS, bytes)
end

-- Select which algorithm slot receives subsequent parameter changes
local function select_algorithm(channel)
  local msb, lsb = split_bytes(channel)
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

-- Convert 0-1 normalized velocity to 0-16384
local function normalize_velocity(vel_0_to_1)
  return math.floor(vel_0_to_1 * 16384)
end

------------------------------------------------------------
-- Per-channel configuration storage (in-memory session cache)
------------------------------------------------------------

-- Indexed by channel number: channel_configs[1] = {algorithm = 1, pm_folder = 5, ...}
local channel_configs = {}

-- Currently editing channel (for view pattern)
local current_edit_channel = 1

------------------------------------------------------------
-- Channel Config Management
------------------------------------------------------------

local function default_channel_config()
  return {
    algorithm = 1,  -- DX7 is now index 1

    -- DX7 defaults (from NT docs)
    dx7_bank = 0,
    dx7_voice = 1,
    dx7_brightness = 0,
    dx7_envelope_scale = 0,
    dx7_left_output = 13,
    dx7_right_output = 0,
    dx7_i2c_channel = 1,

    -- Plaits defaults (from NT docs)
    plaits_model = 0,
    plaits_harmonics = 64,
    plaits_timbre = 64,
    plaits_morph = 64,
    plaits_fm = 0,
    plaits_timbre_mod = 0,
    plaits_morph_mod = 0,
    plaits_lpg = 127,
    plaits_decay = 64,
    plaits_fm_input = 0,
    plaits_harmonics_input = 0,
    plaits_timbre_input = 0,
    plaits_morph_input = 0,
    plaits_main_output = 13,
    plaits_aux_output = 0,
    plaits_output_mode = 0,
    plaits_i2c_mode = 3,  -- "Pitch & Trigger" so notes work
    plaits_i2c_channel = 1,

    -- Poly Multisample defaults (from NT docs)
    pm_folder = 0,
    pm_gain = 0,
    pm_pan = 0,
    pm_envelope = 0,
    pm_attack = 0,
    pm_decay = 60,
    pm_sustain = 100,
    pm_release = 77,
    pm_loop = 0,
    pm_left_output = 13,
    pm_right_output = 0,
    pm_i2c_channel = 1,

    -- Rings defaults (from NT docs)
    rings_mode = 0,
    rings_synth_effect = 0,
    rings_resolution = 16,
    rings_structure = 64,
    rings_brightness = 64,
    rings_damping = 64,
    rings_position = 64,
    rings_chord = 0,
    rings_noise_gate = 1,
    rings_input_gain = 0,
    rings_audio_input = 0,
    rings_odd_output = 13,
    rings_even_output = 13,
    rings_i2c_channel = 1,

  }
end

local function get_channel_config(channel)
  if not channel_configs[channel] then
    channel_configs[channel] = default_channel_config()
  end
  return channel_configs[channel]
end

local function save_to_channel(key, value)
  local config = get_channel_config(current_edit_channel)
  config[key] = value
end

------------------------------------------------------------
-- i2c Param Sending
------------------------------------------------------------

local function send_param(channel, param_num, value)
  if param_num == nil then
    -- Param number not yet discovered, skip silently
    return
  end
  select_algorithm(channel)
  set_param(param_num, value)
end

------------------------------------------------------------
-- View Pattern: Load/Save Channel Configs to Params
------------------------------------------------------------

local function load_channel_into_params(channel)
  local config = get_channel_config(channel)
  current_edit_channel = channel

  -- Algorithm selection
  params:set("dnt_algorithm", config.algorithm, true)

  -- DX7
  params:set("dnt_dx7_bank", config.dx7_bank, true)
  params:set("dnt_dx7_voice", config.dx7_voice, true)
  params:set("dnt_dx7_brightness", config.dx7_brightness, true)
  params:set("dnt_dx7_envelope_scale", config.dx7_envelope_scale, true)
  params:set("dnt_dx7_left_output", config.dx7_left_output, true)
  params:set("dnt_dx7_right_output", config.dx7_right_output, true)
  params:set("dnt_dx7_i2c_channel", config.dx7_i2c_channel, true)

  -- Plaits
  params:set("dnt_plaits_model", config.plaits_model + 1, true)
  params:set("dnt_plaits_harmonics", config.plaits_harmonics, true)
  params:set("dnt_plaits_timbre", config.plaits_timbre, true)
  params:set("dnt_plaits_morph", config.plaits_morph, true)
  params:set("dnt_plaits_fm", config.plaits_fm, true)
  params:set("dnt_plaits_timbre_mod", config.plaits_timbre_mod, true)
  params:set("dnt_plaits_morph_mod", config.plaits_morph_mod, true)
  params:set("dnt_plaits_lpg", config.plaits_lpg, true)
  params:set("dnt_plaits_decay", config.plaits_decay, true)
  params:set("dnt_plaits_fm_input", config.plaits_fm_input, true)
  params:set("dnt_plaits_harmonics_input", config.plaits_harmonics_input, true)
  params:set("dnt_plaits_timbre_input", config.plaits_timbre_input, true)
  params:set("dnt_plaits_morph_input", config.plaits_morph_input, true)
  params:set("dnt_plaits_main_output", config.plaits_main_output, true)
  params:set("dnt_plaits_aux_output", config.plaits_aux_output, true)
  params:set("dnt_plaits_output_mode", config.plaits_output_mode + 1, true)
  params:set("dnt_plaits_i2c_mode", config.plaits_i2c_mode + 1, true)
  params:set("dnt_plaits_i2c_channel", config.plaits_i2c_channel, true)

  -- Poly Multisample
  params:set("dnt_pm_folder", config.pm_folder, true)
  params:set("dnt_pm_gain", config.pm_gain, true)
  params:set("dnt_pm_pan", config.pm_pan, true)
  params:set("dnt_pm_envelope", config.pm_envelope + 1, true)
  params:set("dnt_pm_attack", config.pm_attack, true)
  params:set("dnt_pm_decay", config.pm_decay, true)
  params:set("dnt_pm_sustain", config.pm_sustain, true)
  params:set("dnt_pm_release", config.pm_release, true)
  params:set("dnt_pm_loop", config.pm_loop + 1, true)
  params:set("dnt_pm_left_output", config.pm_left_output, true)
  params:set("dnt_pm_right_output", config.pm_right_output, true)
  params:set("dnt_pm_i2c_channel", config.pm_i2c_channel, true)

  -- Rings
  params:set("dnt_rings_mode", config.rings_mode + 1, true)
  params:set("dnt_rings_synth_effect", config.rings_synth_effect + 1, true)
  params:set("dnt_rings_resolution", config.rings_resolution, true)
  params:set("dnt_rings_structure", config.rings_structure, true)
  params:set("dnt_rings_brightness", config.rings_brightness, true)
  params:set("dnt_rings_damping", config.rings_damping, true)
  params:set("dnt_rings_position", config.rings_position, true)
  params:set("dnt_rings_chord", config.rings_chord, true)
  params:set("dnt_rings_noise_gate", config.rings_noise_gate + 1, true)
  params:set("dnt_rings_input_gain", config.rings_input_gain, true)
  params:set("dnt_rings_audio_input", config.rings_audio_input, true)
  params:set("dnt_rings_odd_output", config.rings_odd_output, true)
  params:set("dnt_rings_even_output", config.rings_even_output, true)
  params:set("dnt_rings_i2c_channel", config.rings_i2c_channel, true)

end

------------------------------------------------------------
-- Per-Lane Params (minimal: active, channel, volume)
------------------------------------------------------------

local function create_lane_params(i)
  params:add_binary("lane_" .. i .. "_disting_nt_active", "Disting NT Active", "toggle", 0)
  params:set_action("lane_" .. i .. "_disting_nt_active", function(value)
    _seeker.lanes[i].disting_nt_active = (value == 1)
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  params:add_number("lane_" .. i .. "_disting_nt_channel", "Channel", 1, 255, i)
  params:set_action("lane_" .. i .. "_disting_nt_channel", function(value)
    _seeker.lanes[i].disting_nt_channel = value
  end)

  params:add_control("lane_" .. i .. "_disting_nt_volume", "Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1, ""))
  params:set_action("lane_" .. i .. "_disting_nt_volume", function(value)
    _seeker.lanes[i].disting_nt_volume = value
  end)
end

------------------------------------------------------------
-- Global View Params (edit any channel's config)
------------------------------------------------------------

local function create_view_params()
  params:add_group("disting_nt", "DISTING NT", 53)

  -- Which channel to edit
  params:add_number("dnt_edit_channel", "Edit Channel", 1, 255, 1)
  params:set_action("dnt_edit_channel", function(value)
    load_channel_into_params(value)
    if _seeker and _seeker.lane_config then
      _seeker.lane_config.screen:rebuild_params()
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  -- Algorithm type for this channel
  params:add_option("dnt_algorithm", "Algorithm", ALGORITHMS, 1)
  params:set_action("dnt_algorithm", function(value)
    save_to_channel("algorithm", value)

    -- Auto-configure i2c channel to default for this algorithm type
    local alg_name = ALGORITHMS[value]
    local default_ch = DEFAULT_CHANNELS[alg_name] or current_edit_channel
    send_param(current_edit_channel, PARAM_NUMS.i2c_channel, default_ch)

    if _seeker and _seeker.lane_config then
      _seeker.lane_config.screen:rebuild_params()
      _seeker.screen_ui.set_needs_redraw()
    end
  end)

  ----------------------------------------
  -- DX7 params
  ----------------------------------------

  params:add_number("dnt_dx7_bank", "Bank", 0, 127, 0)
  params:set_action("dnt_dx7_bank", function(value)
    save_to_channel("dx7_bank", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.bank, value)
  end)

  params:add_number("dnt_dx7_voice", "Voice", 1, 32, 1)
  params:set_action("dnt_dx7_voice", function(value)
    save_to_channel("dx7_voice", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.voice, value)
  end)

  params:add_number("dnt_dx7_brightness", "Brightness", -100, 100, 0)
  params:set_action("dnt_dx7_brightness", function(value)
    save_to_channel("dx7_brightness", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.brightness, value)
  end)

  params:add_number("dnt_dx7_envelope_scale", "Envelope Scale", -100, 100, 0)
  params:set_action("dnt_dx7_envelope_scale", function(value)
    save_to_channel("dx7_envelope_scale", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.envelope_scale, value)
  end)

  params:add_number("dnt_dx7_left_output", "Left Output", 1, 28, 13)
  params:set_action("dnt_dx7_left_output", function(value)
    save_to_channel("dx7_left_output", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.left_output, value)
  end)

  params:add_number("dnt_dx7_right_output", "Right Output", 0, 28, 0)
  params:set_action("dnt_dx7_right_output", function(value)
    save_to_channel("dx7_right_output", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.right_output, value)
  end)

  params:add_number("dnt_dx7_i2c_channel", "I2C Channel", 0, 255, 1)
  params:set_action("dnt_dx7_i2c_channel", function(value)
    save_to_channel("dx7_i2c_channel", value)
    send_param(current_edit_channel, PARAM_NUMS.dx7.i2c_channel, value)
  end)

  ----------------------------------------
  -- Plaits params
  ----------------------------------------

  params:add_option("dnt_plaits_model", "Model", PLAITS_MODELS, 1)
  params:set_action("dnt_plaits_model", function(value)
    local actual = value - 1
    save_to_channel("plaits_model", actual)
    send_param(current_edit_channel, PARAM_NUMS.plaits.model, actual)
  end)

  params:add_number("dnt_plaits_harmonics", "Harmonics", 0, 127, 64)
  params:set_action("dnt_plaits_harmonics", function(value)
    save_to_channel("plaits_harmonics", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.harmonics, value)
  end)

  params:add_number("dnt_plaits_timbre", "Timbre", 0, 127, 64)
  params:set_action("dnt_plaits_timbre", function(value)
    save_to_channel("plaits_timbre", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.timbre, value)
  end)

  params:add_number("dnt_plaits_morph", "Morph", 0, 127, 64)
  params:set_action("dnt_plaits_morph", function(value)
    save_to_channel("plaits_morph", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.morph, value)
  end)

  params:add_number("dnt_plaits_fm", "FM", 0, 127, 0)
  params:set_action("dnt_plaits_fm", function(value)
    save_to_channel("plaits_fm", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.fm, value)
  end)

  params:add_number("dnt_plaits_timbre_mod", "Timbre Mod", 0, 127, 0)
  params:set_action("dnt_plaits_timbre_mod", function(value)
    save_to_channel("plaits_timbre_mod", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.timbre_mod, value)
  end)

  params:add_number("dnt_plaits_morph_mod", "Morph Mod", 0, 127, 0)
  params:set_action("dnt_plaits_morph_mod", function(value)
    save_to_channel("plaits_morph_mod", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.morph_mod, value)
  end)

  params:add_number("dnt_plaits_lpg", "LPG", 0, 127, 127)
  params:set_action("dnt_plaits_lpg", function(value)
    save_to_channel("plaits_lpg", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.lpg, value)
  end)

  params:add_number("dnt_plaits_decay", "Decay", 0, 127, 64)
  params:set_action("dnt_plaits_decay", function(value)
    save_to_channel("plaits_decay", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.decay, value)
  end)

  params:add_number("dnt_plaits_fm_input", "FM Input", 0, 28, 0)
  params:set_action("dnt_plaits_fm_input", function(value)
    save_to_channel("plaits_fm_input", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.fm_input, value)
  end)

  params:add_number("dnt_plaits_harmonics_input", "Harmonics Input", 0, 28, 0)
  params:set_action("dnt_plaits_harmonics_input", function(value)
    save_to_channel("plaits_harmonics_input", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.harmonics_input, value)
  end)

  params:add_number("dnt_plaits_timbre_input", "Timbre Input", 0, 28, 0)
  params:set_action("dnt_plaits_timbre_input", function(value)
    save_to_channel("plaits_timbre_input", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.timbre_input, value)
  end)

  params:add_number("dnt_plaits_morph_input", "Morph Input", 0, 28, 0)
  params:set_action("dnt_plaits_morph_input", function(value)
    save_to_channel("plaits_morph_input", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.morph_input, value)
  end)

  params:add_number("dnt_plaits_main_output", "Main Output", 1, 28, 13)
  params:set_action("dnt_plaits_main_output", function(value)
    save_to_channel("plaits_main_output", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.main_output, value)
  end)

  params:add_number("dnt_plaits_aux_output", "Aux Output", 0, 28, 0)
  params:set_action("dnt_plaits_aux_output", function(value)
    save_to_channel("plaits_aux_output", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.aux_output, value)
  end)

  local OUTPUT_MODES = {"Both", "Main only", "Aux only"}
  params:add_option("dnt_plaits_output_mode", "Output Mode", OUTPUT_MODES, 1)
  params:set_action("dnt_plaits_output_mode", function(value)
    local actual = value - 1
    save_to_channel("plaits_output_mode", actual)
    send_param(current_edit_channel, PARAM_NUMS.plaits.output_mode, actual)
  end)

  params:add_option("dnt_plaits_i2c_mode", "I2C Mode", I2C_MODES, 4)
  params:set_action("dnt_plaits_i2c_mode", function(value)
    local actual = value - 1
    save_to_channel("plaits_i2c_mode", actual)
    send_param(current_edit_channel, PARAM_NUMS.plaits.i2c_mode, actual)
  end)

  params:add_number("dnt_plaits_i2c_channel", "I2C Channel", 1, 255, 1)
  params:set_action("dnt_plaits_i2c_channel", function(value)
    save_to_channel("plaits_i2c_channel", value)
    send_param(current_edit_channel, PARAM_NUMS.plaits.i2c_channel, value)
  end)

  ----------------------------------------
  -- Poly Multisample params
  ----------------------------------------

  params:add_number("dnt_pm_folder", "Folder", 0, 99, 0)
  params:set_action("dnt_pm_folder", function(value)
    save_to_channel("pm_folder", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.folder, value)
  end)

  params:add_number("dnt_pm_gain", "Gain", -40, 24, 0)
  params:set_action("dnt_pm_gain", function(value)
    save_to_channel("pm_gain", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.gain, value)
  end)

  params:add_number("dnt_pm_pan", "Pan", -100, 100, 0)
  params:set_action("dnt_pm_pan", function(value)
    save_to_channel("pm_pan", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.pan, value)
  end)

  params:add_option("dnt_pm_envelope", "Envelope", {"Off", "On"}, 1)
  params:set_action("dnt_pm_envelope", function(value)
    local actual = value - 1
    save_to_channel("pm_envelope", actual)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.envelope, actual)
  end)

  params:add_number("dnt_pm_attack", "Attack", 0, 127, 0)
  params:set_action("dnt_pm_attack", function(value)
    save_to_channel("pm_attack", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.attack, value)
  end)

  params:add_number("dnt_pm_decay", "Decay", 0, 127, 60)
  params:set_action("dnt_pm_decay", function(value)
    save_to_channel("pm_decay", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.decay, value)
  end)

  params:add_number("dnt_pm_sustain", "Sustain", 0, 100, 100)
  params:set_action("dnt_pm_sustain", function(value)
    save_to_channel("pm_sustain", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.sustain, value)
  end)

  params:add_number("dnt_pm_release", "Release", 0, 127, 77)
  params:set_action("dnt_pm_release", function(value)
    save_to_channel("pm_release", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.release, value)
  end)

  params:add_option("dnt_pm_loop", "Loop", {"From WAV", "Off", "On"}, 1)
  params:set_action("dnt_pm_loop", function(value)
    local actual = value - 1
    save_to_channel("pm_loop", actual)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.loop, actual)
  end)

  params:add_number("dnt_pm_left_output", "Left Output", 1, 28, 13)
  params:set_action("dnt_pm_left_output", function(value)
    save_to_channel("pm_left_output", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.left_output, value)
  end)

  params:add_number("dnt_pm_right_output", "Right Output", 0, 28, 0)
  params:set_action("dnt_pm_right_output", function(value)
    save_to_channel("pm_right_output", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.right_output, value)
  end)

  params:add_number("dnt_pm_i2c_channel", "I2C Channel", 0, 255, 1)
  params:set_action("dnt_pm_i2c_channel", function(value)
    save_to_channel("pm_i2c_channel", value)
    send_param(current_edit_channel, PARAM_NUMS.poly_multisample.i2c_channel, value)
  end)

  ----------------------------------------
  -- Rings params
  ----------------------------------------

  params:add_option("dnt_rings_mode", "Mode", {
    "Modal", "Sympathetic", "String", "FM", "Quantized"
  }, 1)
  params:set_action("dnt_rings_mode", function(value)
    local actual = value - 1
    save_to_channel("rings_mode", actual)
    send_param(current_edit_channel, PARAM_NUMS.rings.mode, actual)
  end)

  params:add_option("dnt_rings_synth_effect", "Synth Effect", {"Off", "On"}, 1)
  params:set_action("dnt_rings_synth_effect", function(value)
    local actual = value - 1
    save_to_channel("rings_synth_effect", actual)
    send_param(current_edit_channel, PARAM_NUMS.rings.synth_effect, actual)
  end)

  params:add_number("dnt_rings_resolution", "Resolution", 8, 64, 16)
  params:set_action("dnt_rings_resolution", function(value)
    save_to_channel("rings_resolution", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.resolution, value)
  end)

  params:add_number("dnt_rings_structure", "Structure", 0, 127, 64)
  params:set_action("dnt_rings_structure", function(value)
    save_to_channel("rings_structure", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.structure, value)
  end)

  params:add_number("dnt_rings_brightness", "Brightness", 0, 127, 64)
  params:set_action("dnt_rings_brightness", function(value)
    save_to_channel("rings_brightness", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.brightness, value)
  end)

  params:add_number("dnt_rings_damping", "Damping", 0, 127, 64)
  params:set_action("dnt_rings_damping", function(value)
    save_to_channel("rings_damping", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.damping, value)
  end)

  params:add_number("dnt_rings_position", "Position", 0, 127, 64)
  params:set_action("dnt_rings_position", function(value)
    save_to_channel("rings_position", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.position, value)
  end)

  params:add_number("dnt_rings_chord", "Chord", 0, 10, 0)
  params:set_action("dnt_rings_chord", function(value)
    save_to_channel("rings_chord", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.chord, value)
  end)

  params:add_option("dnt_rings_noise_gate", "Noise Gate", {"Off", "On"}, 2)
  params:set_action("dnt_rings_noise_gate", function(value)
    local actual = value - 1
    save_to_channel("rings_noise_gate", actual)
    send_param(current_edit_channel, PARAM_NUMS.rings.noise_gate, actual)
  end)

  params:add_number("dnt_rings_input_gain", "Input Gain", -40, 12, 0)
  params:set_action("dnt_rings_input_gain", function(value)
    save_to_channel("rings_input_gain", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.input_gain, value)
  end)

  params:add_number("dnt_rings_audio_input", "Audio Input", 0, 28, 0)
  params:set_action("dnt_rings_audio_input", function(value)
    save_to_channel("rings_audio_input", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.audio_input, value)
  end)

  params:add_number("dnt_rings_odd_output", "Odd Output", 0, 28, 13)
  params:set_action("dnt_rings_odd_output", function(value)
    save_to_channel("rings_odd_output", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.odd_output, value)
  end)

  params:add_number("dnt_rings_even_output", "Even Output", 0, 28, 13)
  params:set_action("dnt_rings_even_output", function(value)
    save_to_channel("rings_even_output", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.even_output, value)
  end)

  params:add_number("dnt_rings_i2c_channel", "I2C Channel", 0, 255, 1)
  params:set_action("dnt_rings_i2c_channel", function(value)
    save_to_channel("rings_i2c_channel", value)
    send_param(current_edit_channel, PARAM_NUMS.rings.i2c_channel, value)
  end)

  -- Initialize view to channel 1
  load_channel_into_params(1)
end

------------------------------------------------------------
-- Public API: Note Control (called by lane.lua during playback)
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

-- Convert MIDI note to NT pitch format
function disting_nt.midi_to_pitch(midi_note)
  return midi_to_pitch(midi_note)
end

-- Convert 0-127 velocity to NT format (0-16384)
function disting_nt.scale_velocity(velocity_0_127, volume_multiplier)
  return math.floor(velocity_0_127 * volume_multiplier * 16384 / 127)
end

------------------------------------------------------------
-- Voice Interface: Unified note handling for lane.lua
-- These methods encapsulate the voice-specific logic so lane.lua
-- can call a single method instead of inline i2c commands.
------------------------------------------------------------

function disting_nt.is_active(lane_idx)
  return params:get("lane_" .. lane_idx .. "_disting_nt_active") == 1
end

function disting_nt.handle_note_on(lane_idx, note, event_velocity)
  local voice_volume = params:get("lane_" .. lane_idx .. "_disting_nt_volume")
  local lane_volume = params:get("lane_" .. lane_idx .. "_volume")
  local channel = disting_nt.get_channel_for_lane(lane_idx)
  local nt_pitch = disting_nt.midi_to_pitch(note)
  local nt_velocity = disting_nt.scale_velocity(event_velocity, voice_volume * lane_volume)

  disting_nt.note_pitch(channel, note, nt_pitch)
  disting_nt.note_on(channel, note, nt_velocity)
end

function disting_nt.handle_note_off(lane_idx, note)
  local channel = disting_nt.get_channel_for_lane(lane_idx)
  disting_nt.note_off(channel, note)
end

------------------------------------------------------------
-- Public API: Param Setup
------------------------------------------------------------

-- Main entry point, called per lane during param setup
function disting_nt.create_params(i)
  create_lane_params(i)

  -- Create global view params only once (on lane 1)
  if i == 1 then
    create_view_params()
  end
end

-- Get channel for a lane (used by lane.lua for note routing)
function disting_nt.get_channel_for_lane(lane_idx)
  return params:get("lane_" .. lane_idx .. "_disting_nt_channel")
end

-- Get current edit channel
function disting_nt.get_current_edit_channel()
  return current_edit_channel
end

-- Get algorithm name for a channel
function disting_nt.get_algorithm(channel)
  local config = get_channel_config(channel)
  return ALGORITHMS[config.algorithm]
end

-- Get algorithm index for a channel
function disting_nt.get_algorithm_index(channel)
  local config = get_channel_config(channel)
  return config.algorithm
end

-- Algorithm list (for external use)
disting_nt.ALGORITHMS = ALGORITHMS

------------------------------------------------------------
-- UI Helper: Returns formatted param entries for lane_config
------------------------------------------------------------

function disting_nt.get_params_for_ui(algorithm_index)
  -- DX7
  if algorithm_index == 1 then
    return {
      { separator = true, title = "Voice" },
      { id = "dnt_dx7_bank" },
      { id = "dnt_dx7_voice" },

      { separator = true, title = "Sound" },
      { id = "dnt_dx7_brightness", arc_multi_float = {10, 5, 1} },
      { id = "dnt_dx7_envelope_scale", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Outputs" },
      { id = "dnt_dx7_left_output" },
      { id = "dnt_dx7_right_output" },

      { separator = true, title = "I2C" },
      { id = "dnt_dx7_i2c_channel" },
    }

  -- Plaits
  elseif algorithm_index == 2 then
    return {
      { separator = true, title = "Oscillator" },
      { id = "dnt_plaits_model" },
      { id = "dnt_plaits_harmonics", arc_multi_float = {10, 5, 1} },
      { id = "dnt_plaits_timbre", arc_multi_float = {10, 5, 1} },
      { id = "dnt_plaits_morph", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Modulation" },
      { id = "dnt_plaits_fm", arc_multi_float = {10, 5, 1} },
      { id = "dnt_plaits_timbre_mod", arc_multi_float = {10, 5, 1} },
      { id = "dnt_plaits_morph_mod", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope" },
      { id = "dnt_plaits_lpg", arc_multi_float = {10, 5, 1} },
      { id = "dnt_plaits_decay", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "CV Inputs" },
      { id = "dnt_plaits_fm_input" },
      { id = "dnt_plaits_harmonics_input" },
      { id = "dnt_plaits_timbre_input" },
      { id = "dnt_plaits_morph_input" },

      { separator = true, title = "Outputs" },
      { id = "dnt_plaits_main_output" },
      { id = "dnt_plaits_aux_output" },
      { id = "dnt_plaits_output_mode" },

      { separator = true, title = "I2C" },
      { id = "dnt_plaits_i2c_mode" },
      { id = "dnt_plaits_i2c_channel" },
    }

  -- Poly Multisample
  elseif algorithm_index == 3 then
    return {
      { separator = true, title = "Sample" },
      { id = "dnt_pm_folder" },
      { id = "dnt_pm_gain", arc_multi_float = {5, 2, 1} },
      { id = "dnt_pm_pan", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Envelope" },
      { id = "dnt_pm_envelope" },
      { id = "dnt_pm_attack", arc_multi_float = {10, 5, 1} },
      { id = "dnt_pm_decay", arc_multi_float = {10, 5, 1} },
      { id = "dnt_pm_sustain", arc_multi_float = {10, 5, 1} },
      { id = "dnt_pm_release", arc_multi_float = {10, 5, 1} },

      { separator = true, title = "Playback" },
      { id = "dnt_pm_loop" },

      { separator = true, title = "Outputs" },
      { id = "dnt_pm_left_output" },
      { id = "dnt_pm_right_output" },

      { separator = true, title = "I2C" },
      { id = "dnt_pm_i2c_channel" },
    }

  -- Rings
  elseif algorithm_index == 4 then
    return {
      { separator = true, title = "Mode" },
      { id = "dnt_rings_mode" },
      { id = "dnt_rings_synth_effect" },

      { separator = true, title = "Resonator" },
      { id = "dnt_rings_resolution", arc_multi_float = {10, 5, 1} },
      { id = "dnt_rings_structure", arc_multi_float = {10, 5, 1} },
      { id = "dnt_rings_brightness", arc_multi_float = {10, 5, 1} },
      { id = "dnt_rings_damping", arc_multi_float = {10, 5, 1} },
      { id = "dnt_rings_position", arc_multi_float = {10, 5, 1} },
      { id = "dnt_rings_chord" },

      { separator = true, title = "Input" },
      { id = "dnt_rings_noise_gate" },
      { id = "dnt_rings_input_gain", arc_multi_float = {5, 2, 1} },
      { id = "dnt_rings_audio_input" },

      { separator = true, title = "Outputs" },
      { id = "dnt_rings_odd_output" },
      { id = "dnt_rings_even_output" },

      { separator = true, title = "I2C" },
      { id = "dnt_rings_i2c_channel" },
    }
  end

  return {}
end

return disting_nt

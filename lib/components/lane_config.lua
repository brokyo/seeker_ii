-- lane_config.lua
-- Self-contained component for Lane configuration following the component pattern

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid_constants")

local LaneConfig = {}
LaneConfig.__index = LaneConfig

-- Get sorted list of available instruments
local function get_instrument_list()
    local instruments = {}
    for k, v in pairs(_seeker.skeys.instrument) do
        table.insert(instruments, k)
    end
    table.sort(instruments)
    return instruments
end

local function create_mx_samples_params(i)
    params:add_binary("lane_" .. i .. "_mx_samples_active", "MX Samples Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_mx_samples_active", function(value)
        if value == 1 then
            _seeker.lanes[i].mx_samples_active = true
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    params:add_control("lane_" .. i .. "_mx_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_mx_voice_volume", function(value)
        _seeker.lanes[i].mx_voice_volume = value
    end)
    
    local instruments = get_instrument_list()
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)

    -- ADSR envelope controls
    params:add_control("lane_" .. i .. "_attack", "Attack", controlspec.new(0, 10, 'lin', 0.01, 0, "s"), 
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_attack", function(value)
        _seeker.lanes[i].attack = value
    end)

    params:add_control("lane_" .. i .. "_decay", "Decay", controlspec.new(0, 10, 'lin', 0.01, 1, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_decay", function(value)
        _seeker.lanes[i].decay = value
    end)

    params:add_control("lane_" .. i .. "_sustain", "Sustain", controlspec.new(0, 2, 'lin', 0.01, 0.9, "amp"),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_sustain", function(value)
        _seeker.lanes[i].sustain = value
    end)

    params:add_control("lane_" .. i .. "_release", "Release", controlspec.new(0, 10, 'lin', 0.01, 2, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_release", function(value)
        _seeker.lanes[i].release = value
    end)

    params:add_control("lane_" .. i .. "_pan", "Pan", controlspec.new(-1, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_pan", function(value)
        _seeker.lanes[i].pan = value
    end)

    -- Filter controls
    params:add_taper("lane_" .. i .. "_lpf", "LPF Cutoff", 20, 20000, 20000, 3, "Hz")
    params:set_action("lane_" .. i .. "_lpf", function(value)
        _seeker.lanes[i].lpf = value
    end)

    params:add_control("lane_" .. i .. "_resonance", "LPF Resonance", controlspec.new(0, 4, 'lin', 0.01, 0, ""))
    params:set_action("lane_" .. i .. "_resonance", function(value)
        _seeker.lanes[i].resonance = value
    end)

    params:add_taper("lane_" .. i .. "_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
    params:set_action("lane_" .. i .. "_hpf", function(value)
        _seeker.lanes[i].hpf = value
    end)

    -- Effects sends
    params:add_control("lane_" .. i .. "_delay_send", "Delay Send", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_delay_send", function(value)
        _seeker.lanes[i].delay_send = value
    end)

    params:add_control("lane_" .. i .. "_reverb_send", "Reverb Send", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_reverb_send", function(value)
        _seeker.lanes[i].reverb_send = value
    end)
end

local function create_midi_params(i)
    params:add_binary("lane_" .. i .. "_midi_active", "MIDI Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_midi_active", function(value)
        if value == 1 then
            _seeker.lanes[i].midi_active = true
        else
            _seeker.lanes[i].midi_active = false
        end
        
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_midi_voice_volume", "MIDI Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_midi_voice_volume", function(value)
        _seeker.lanes[i].midi_voice_volume = value
    end)

    local device_names = {"none"}
    for _, dev in pairs(midi.devices) do
        table.insert(device_names, dev.name)
    end
    params:add_option("lane_" .. i .. "_midi_device", "MIDI Device", device_names, 1)
    params:set_action("lane_" .. i .. "_midi_device", function(value)
        if value > 1 then
            _seeker.lanes[i].midi_out_device = midi.connect(value)
        end
    end)

    params:add_number("lane_" .. i .. "_midi_channel", "MIDI Channel", 0, 16, 0)
end

local function create_crow_txo_params(i)
    params:add_binary("lane_" .. i .. "_eurorack_active", "CV/Gate Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_eurorack_active", function(value)
        if value == 1 then
            _seeker.lanes[i].eurorack_active = true
        else
            _seeker.lanes[i].eurorack_active = false
        end
        
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_euro_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_euro_voice_volume", function(value)
        _seeker.lanes[i].euro_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_gate_out", "Gate Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
    params:add_option("lane_" .. i .. "_cv_out", "CV Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo cv 1", "txo cv 2", "txo cv 3", "txo cv 4"}, 1)
    params:add_option("lane_" .. i .. "_loop_start_trigger", "Loop Start Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
end

local function create_just_friends_params(i)
    params:add_binary("lane_" .. i .. "_just_friends_active", "Just Friends Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_just_friends_active", function(value)
        if value == 1 then
            crow.ii.jf.mode(1)
        else
            crow.ii.jf.mode(0)
        end
        
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_just_friends_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_just_friends_voice_volume", function(value)
        _seeker.lanes[i].just_friends_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_just_friends_voice_select", "JF Voice", {"All", "1", "2", "3", "4", "5", "6"}, 1)
    params:set_action("lane_" .. i .. "_just_friends_voice_select", function(value)
        _seeker.lanes[i].just_friends_voice_select = value
    end)
end

local function create_wsyn_params(i)
    params:add_binary("lane_" .. i .. "_wsyn_active", "w/syn Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_wsyn_active", function(value)
        if value == 1 then
            _seeker.lanes[i].wsyn_active = true
        else
            _seeker.lanes[i].wsyn_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_wsyn_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_wsyn_voice_volume", function(value)
        _seeker.lanes[i].wsyn_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_wsyn_voice_select", "w/syn Voice", {"All", "1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_voice_select", function(value)
        _seeker.lanes[i].wsyn_voice_select = value
    end)

    params:add_option("lane_" .. i .. "_wsyn_ar_mode", "Pluck Mode", {"Off", "On"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_ar_mode", function(value)
        if value == 2 then
            crow.ii.wsyn.ar_mode(1)
        else
            crow.ii.wsyn.ar_mode(0)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_curve", "Curve", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_curve", function(value)
        crow.ii.wsyn.curve(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_ramp", "Ramp", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_ramp", function(value)
        crow.ii.wsyn.ramp(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_index", "FM Index", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_index", function(value)
        crow.ii.wsyn.fm_index(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_env", "FM Env", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_env", function(value)
        crow.ii.wsyn.fm_env(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_num", "FM Ratio Numerator", controlspec.new(0.01, 1, 'lin', 0.001, 0.5),
        function(param) return string.format("%.3f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_num", function(numerator)
        if _seeker.lanes[i] then
            local denominator = params:get("lane_" .. i .. "_wsyn_fm_ratio_denom")
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_denom", "FM Ratio Denominator", controlspec.new(0.01, 1, 'lin', 0.001, 0.5),
        function(param) return string.format("%.3f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_denom", function(denominator)
        if _seeker.lanes[i] then
            local numerator = params:get("lane_" .. i .. "_wsyn_fm_ratio_num") 
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_time", "LPG Time", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_lpg_time", function(value)
        crow.ii.wsyn.lpg_time(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_symmetry", "LPG Symmetry", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_lpg_symmetry", function(value)
        crow.ii.wsyn.lpg_symmetry(value)
    end)

    params:add_option("lane_" .. i .. "_wsyn_patch_this", "THIS",
        {"ramp", "curve", "fm_env", "fm_index", "lpg_time", "lpg_symmetry", "gate", "pitch", "fm_ratio_num", "fm_ratio_denom"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_patch_this", function(value)
        local param_map = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local param_num = param_map[value]
        crow.ii.wsyn.patch(1, param_num)
    end)

    params:add_option("lane_" .. i .. "_wsyn_patch_that", "THAT",
        {"ramp", "curve", "fm_env", "fm_index", "lpg_time", "lpg_symmetry", "gate", "pitch", "fm_ratio_num", "fm_ratio_denom"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_patch_that", function(value)
        local param_map = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local param_num = param_map[value]
        crow.ii.wsyn.patch(2, param_num)
    end)
end

local function create_osc_params(i)
    params:add_binary("lane_" .. i .. "_osc_active", "OSC Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_osc_active", function(value)
        if value == 1 then
            _seeker.lanes[i].osc_active = true
        else
            _seeker.lanes[i].osc_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)
end

-- Disting EX helper functions
local function disting_macro_osc_2_offset()
    local active_lane = _seeker.ui_state.get_focused_lane()
    local selected_voice = params:get("lane_" .. active_lane .. "_disting_macro_osc_2_voice_select")
    return 11 * (selected_voice - 1)
end

local function disting_poly_fm_offset()
    return 7
end

-- Multisample parameters
local function create_disting_multisample_params(i)
    params:add_number("lane_" .. i .. "_disting_multisample_sample_folder", "Sample Folder", 1, 100)
    params:set_action("lane_" .. i .. "_disting_multisample_sample_folder", function(value)
        crow.ii.disting.parameter(7, value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_attack", "Attack", 0, 100, 0)
    params:set_action("lane_" .. i .. "_disting_multisample_attack", function(value)
        local converted_value = math.floor((value / 100) * 127)
        crow.ii.disting.parameter(8, converted_value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_decay", "Decay", 0, 100, 50)
    params:set_action("lane_" .. i .. "_disting_multisample_decay", function(value)
        local converted_value = math.floor((value / 100) * 127)
        crow.ii.disting.parameter(9, converted_value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_sustain", "Sustain", 0, 100, 100)
    params:set_action("lane_" .. i .. "_disting_multisample_sustain", function(value)
        local converted_value = math.floor((value / 100) * 127)
        crow.ii.disting.parameter(10, converted_value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_release", "Release", 0, 100, 0)
    params:set_action("lane_" .. i .. "_disting_multisample_release", function(value)
        local converted_value = math.floor((value / 100) * 127)
        crow.ii.disting.parameter(11, converted_value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_gain", "Gain", -40, 24, 0)
    params:set_action("lane_" .. i .. "_disting_multisample_gain", function(value)
        crow.ii.disting.parameter(12, value)
    end)

    params:add_option("lane_" .. i .. "_disting_multisample_delay_mode", "Delay Mode", {"Off", "Stereo", "Ping-Pong"}, 1)
    params:set_action("lane_" .. i .. "_disting_multisample_delay_mode", function(value)
        local shifted_index = value - 1
        crow.ii.disting.parameter(51, shifted_index)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_delay_level", "Delay Level", -40, 0, -3)
    params:set_action("lane_" .. i .. "_disting_multisample_delay_level", function(value)
        crow.ii.disting.parameter(52, value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_delay_time", "Delay Time", 1, 1365, 500)
    params:set_action("lane_" .. i .. "_disting_multisample_delay_time", function(value)
        crow.ii.disting.parameter(53, value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_tone_bass", "Tone Bass", -240, 240, 0)
    params:set_action("lane_" .. i .. "_disting_multisample_tone_bass", function(value)
        crow.ii.disting.parameter(55, value)
    end)

    params:add_number("lane_" .. i .. "_disting_multisample_tone_treble", "Tone Treble", -240, 240, 0)
    params:set_action("lane_" .. i .. "_disting_multisample_tone_treble", function(value)
        crow.ii.disting.parameter(56, value)
    end)
end

-- Rings parameters
local function create_disting_rings_params(i)
    params:add_option("lane_" .. i .. "_disting_rings_mode", "Mode", {
        "Modal Resonator", "Sympathetic Strings", "String", "FM Voice", "Sympathetic Quantized", "Strings & Reverb", "Syth"
    }, 1)
    params:set_action("lane_" .. i .. "_disting_rings_mode", function(value)
        local shifted_index = value - 1
        crow.ii.disting.parameter(7, shifted_index)
    end)

    params:add_option("lane_" .. i .. "_disting_rings_effect", "Effect", {
        "Formant", "Chorus", "Reverb", "Formant 2", "Ensemble", "Reverb 2"
    }, 1)
    params:set_action("lane_" .. i .. "_disting_rings_effect", function(value)
        local shifted_index = value - 1
        crow.ii.disting.parameter(8, shifted_index)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_polyphony", "Polyphony", 1, 4)
    params:set_action("lane_" .. i .. "_disting_rings_polyphony", function(value)
        crow.ii.disting.parameter(9, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_structure", "Structure", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_rings_structure", function(value)
        crow.ii.disting.parameter(12, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_brightness", "Brightness", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_rings_brightness", function(value)
        crow.ii.disting.parameter(13, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_damping", "Damping", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_rings_damping", function(value)
        crow.ii.disting.parameter(14, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_position", "Position", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_rings_position", function(value)
        crow.ii.disting.parameter(15, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_output_gain", "Output Gain", -40, 12, 0)
    params:set_action("lane_" .. i .. "_disting_rings_output_gain", function(value)
        crow.ii.disting.parameter(19, value)
    end)

    params:add_number("lane_" .. i .. "_disting_rings_dry_gain", "Dry Gain", -40, 12, 0)
    params:set_action("lane_" .. i .. "_disting_rings_dry_gain", function(value)
        crow.ii.disting.parameter(20, value)
    end)
end

-- Plaits parameters
local function create_disting_plaits_params(i)
    params:add_option("lane_" .. i .. "_disting_plaits_voice_select", "Disting Voice", {"All","1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_disting_plaits_voice_select", function(value)
        _seeker.lanes[i].disting_plaits_voice_select = value
    end)

    params:add_option("lane_" .. i .. "_disting_plaits_output", "Output", {"Individual", "Mixed"}, 1)
    params:set_action("lane_" .. i .. "_disting_plaits_output", function(value)
        if value == 1 then
            crow.ii.disting.parameter(65, 0)
        else
            crow.ii.disting.parameter(65, 1)
        end
    end)

    params:add_option("lane_" .. i .. "_disting_plaits_model", "Model", {
        "Virtual Analog", "Waveshaping", "FM", "Granular", "Harmonic", "Wavetable", "Chord", "Speech", 
        "Swarm", "Noise", "Particle", "String", "Modal", "Bass Drum", "Snare Drum", "Hi-Hat", 
        "VA VCF", "PD", "6-Op FM", "6-Op FM 2", "6-Op FM 3", "Wave Terrain", "String", "Chiptune"
    }, 1)
    params:set_action("lane_" .. i .. "_disting_plaits_model", function(value)
        local param_offset = disting_macro_osc_2_offset()
        local shifted_index = value - 1
        crow.ii.disting.parameter(param_offset + 7, shifted_index)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_harmonics", "Harmonics", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_harmonics", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 10, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_timbre", "Timbre", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_timbre", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 11, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_morph", "Morph", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_morph", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 12, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_fm", "FM", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_fm", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 13, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_timbre_mod", "Timbre Mod", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_timbre_mod", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 14, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_morph_mod", "Morph Mod", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_morph_mod", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 15, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_low_pass_gate", "LPG", 0, 127, 127)
    params:set_action("lane_" .. i .. "_disting_plaits_low_pass_gate", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 16, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_time", "Time/decay", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_time", function(n)
        local param_offset = disting_macro_osc_2_offset()
        crow.ii.disting.parameter(param_offset + 17, n)
    end)
end

-- DX7 parameters
local function create_disting_dx7_params(i)
    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_bank", "Voice Bank", 1, 27)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_bank", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice", "Voice", 1, 32)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 1, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_gain", "Voice Gain", -40, 24, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_gain", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 3, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_pan", "Voice Pan", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_pan", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 4, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_brightness", "Voice Brightness", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_brightness", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 5, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_morph", "Voice Morph", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_morph", function(value)
        local param_offset = disting_poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 6, value)
    end)
end

local function create_disting_params(i)
    params:add_binary("lane_" .. i .. "_disting_active", "Disting Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_disting_active", function(value)
        if value == 1 then
            _seeker.lanes[i].disting_active = true
        else
            _seeker.lanes[i].disting_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_option("lane_" .. i .. "_disting_algorithm", "Algorithm", {"Multisample", "Rings", "Plaits", "DX7"}, 1)
    params:set_action("lane_" .. i .. "_disting_algorithm", function(value)
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
        
        if value == 1 then
            crow.ii.disting.algorithm(3)
        elseif value == 2 then
            crow.ii.disting.algorithm(20)
            crow.ii.disting.parameter(26, 0)
            crow.ii.disting.parameter(33, 3)
        elseif value == 3 then
            crow.ii.disting.algorithm(21)
        elseif value == 4 then
            crow.ii.disting.algorithm(23)
        end
    end)

    params:add_control("lane_" .. i .. "_disting_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_disting_voice_volume", function(value)
        _seeker.lanes[i].disting_voice_volume = value
    end)

    -- Create algorithm-specific parameters
    create_disting_multisample_params(i)
    create_disting_rings_params(i)
    create_disting_plaits_params(i)
    create_disting_dx7_params(i)
end

local function create_params()
    -- Create parameters for all lanes
    for i = 1, 8 do
        params:add_group("lane_" .. i, "LANE " .. i .. " VOICES", 81)
        
        -- Config Voice selector
        params:add_option("lane_" .. i .. "_visible_voice", "Config Voice", 
            {"MX Samples", "MIDI", "Crow/TXO", "Just Friends", "w/syn", "OSC", "Disting"})
        params:set_action("lane_" .. i .. "_visible_voice", function(value)
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Create all voice-specific parameters
        create_mx_samples_params(i)
        create_midi_params(i)
        create_crow_txo_params(i)
        create_just_friends_params(i)
        create_wsyn_params(i)
        create_osc_params(i)
        create_disting_params(i)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "LANE_CONFIG",
        name = "Lane 1",
        icon = "⌸",
        description = "Select and configure voices. Any number can run in parallel.",
        params = {}
    })
    
    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end
    
    -- Dynamic parameter rebuilding based on current focused lane
    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local visible_voice = params:get("lane_" .. lane_idx .. "_visible_voice")
        
        -- Update section name with current lane
        self.name = string.format("Lane %d", lane_idx)
        
        -- Start with common params
        local param_table = {
            { separator = true, title = string.format("Lane %d Config", lane_idx) },
            { id = "lane_" .. lane_idx .. "_volume" },
            { id = "lane_" .. lane_idx .. "_visible_voice" }
        }
        
        -- Add params based on visible voice selection
        if visible_voice == 1 then -- MX Samples
            table.insert(param_table, { separator = true, title = "Mx Samples" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_mx_samples_active" })
            
            -- Only show additional MX Samples params if active
            if params:get("lane_" .. lane_idx .. "_mx_samples_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_mx_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_instrument" })
                table.insert(param_table, { separator = true, title = "Individual Event" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_pan" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_attack", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_decay", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_sustain", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_release", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { separator = true, title = "Lane Effects" })
                table.insert(param_table, { 
                    id = "lane_" .. lane_idx .. "_lpf", 
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_resonance" })
                table.insert(param_table, { 
                    id = "lane_" .. lane_idx .. "_hpf", 
                    arc_multi_float = {1000, 100, 10}
                })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_delay_send" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_reverb_send" })
            end
        elseif visible_voice == 2 then -- MIDI
            table.insert(param_table, { separator = true, title = "MIDI" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_active" })
            
            -- Only show additional MIDI params if active
            if params:get("lane_" .. lane_idx .. "_midi_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_device" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_midi_channel" })
            end
        elseif visible_voice == 3 then -- CV/Gate via i2c
            table.insert(param_table, { separator = true, title = "CV/Gate" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_eurorack_active" })
            
            -- Only show additional Crow/TXO params if active
            if params:get("lane_" .. lane_idx .. "_eurorack_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_euro_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_gate_out" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_cv_out" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_loop_start_trigger" })
            end
        elseif visible_voice == 4 then -- Just Friends
            table.insert(param_table, { separator = true, title = "Just Friends" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_active" })
            
            -- Only show additional Just Friends params if active
            if params:get("lane_" .. lane_idx .. "_just_friends_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_just_friends_voice_select" })
            end
        elseif visible_voice == 5 then -- w/syn
            table.insert(param_table, { separator = true, title = "w/syn" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_active" })
            
            -- Only show additional w/syn params if active
            if params:get("lane_" .. lane_idx .. "_wsyn_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_voice_select" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_ar_mode" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_curve", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_ramp", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_index", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_env", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_num", arc_multi_float = {0.1, 0.01, 0.001} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_denom", arc_multi_float = {0.1, 0.01, 0.001} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_lpg_time", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_lpg_symmetry", arc_multi_float = {1.0, 0.1, 0.01} })
                table.insert(param_table, { separator = true, title = "CV Patching" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_patch_this" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_wsyn_patch_that" })
            end
        elseif visible_voice == 6 then -- OSC
            table.insert(param_table, { separator = true, title = "OSC" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_osc_active" })
        elseif visible_voice == 7 then -- Disting
            table.insert(param_table, { separator = true, title = "Disting" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_active" })
            
            -- Only show additional Disting params if active
            if params:get("lane_" .. lane_idx .. "_disting_active") == 1 then
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_voice_volume" })
                table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_algorithm" })

                -- Multisample Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 1 then
                    table.insert(param_table, { separator = true, title = "Multisample Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_sample_folder" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_attack" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_decay" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_sustain" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_release" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_gain" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_mode" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_level" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_delay_time" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_tone_bass" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_multisample_tone_treble" })
                end
                -- Rings Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 2 then
                    table.insert(param_table, { separator = true, title = "Rings Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_mode" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_effect" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_polyphony" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_structure" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_brightness" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_damping" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_position" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_output_gain" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_rings_dry_gain" })
                end

                -- Plaits Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 3 then
                    table.insert(param_table, { separator = true, title = "Plaits Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_voice_select" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_output" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_model" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_harmonics" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_timbre" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_morph" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_fm" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_timbre_mod" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_morph_mod" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_low_pass_gate" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_plaits_time" })
                end
                -- DX 7 Params
                if params:get("lane_" .. lane_idx .. "_disting_algorithm") == 4 then
                    table.insert(param_table, { separator = true, title = "DX 7 Params" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_bank" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_gain" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_pan" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_brightness" })
                    table.insert(param_table, { id = "lane_" .. lane_idx .. "_disting_poly_fm_voice_morph" })
                end
            end
        end
        
        -- Update the UI with the new parameter table
        self.params = param_table
    end
    
    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "LANE_CONFIG",
        layout = {
            x = 13,
            y = 6,
            width = 4,
            height = 2
        }
    })
    
    -- Flash state for visual feedback
    grid_ui.flash_state = {
        flash_until = nil
    }
    
    -- Override draw method to handle lane display and flash feedback
    function grid_ui:draw(layers)
        local is_lane_section = _seeker.ui_state.get_current_section() == "LANE_CONFIG"
        
        -- Draw keyboard outline during lane switch flash
        if self.flash_state.flash_until and util.time() < self.flash_state.flash_until then
            -- Top and bottom rows
            for x = 0, 5 do
                layers.response[6 + x][2] = GridConstants.BRIGHTNESS.HIGH
                layers.response[6 + x][7] = GridConstants.BRIGHTNESS.HIGH
            end
            -- Left and right columns
            for y = 0, 5 do
                layers.response[6][2 + y] = GridConstants.BRIGHTNESS.HIGH
                layers.response[11][2 + y] = GridConstants.BRIGHTNESS.HIGH
            end
        end
        
        -- Draw lane buttons
        for row = 0, self.layout.height - 1 do
            for i = 0, self.layout.width - 1 do
                local lane_idx = (row * self.layout.width) + i + 1
                local is_focused = lane_idx == _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[lane_idx]
                
                local brightness
                if is_lane_section and is_focused then
                    brightness = GridConstants.BRIGHTNESS.FULL
                elseif lane.playing then
                    -- Pulsing bright when playing, unless focused
                    brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
                elseif is_lane_section then
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
                
                layers.ui[self.layout.x + i][self.layout.y + row] = brightness
            end
        end
    end
    
    -- Override handle_key to manage lane selection
    function grid_ui:handle_key(x, y, z)
        if not self:contains(x, y) then
            return false
        end
        
        local row = y - self.layout.y
        local new_lane_idx = (row * self.layout.width) + (x - self.layout.x) + 1
        local key_id = string.format("%d,%d", x, y)
        
        if z == 1 then -- Key pressed
            -- Use GridUI base class key tracking for long press detection
            self:key_down(key_id)
            
            -- Always focus the lane on press
            _seeker.ui_state.set_focused_lane(new_lane_idx)
            _seeker.ui_state.set_current_section("LANE_CONFIG")
            
            -- Update screen UI to reflect new lane
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
            
            -- Start flash effect (0.15 seconds)
            self.flash_state.flash_until = util.time() + 0.15
            
        else -- Key released
            -- Only toggle playback on long press
            if self:is_long_press(key_id) then
                local lane = _seeker.lanes[new_lane_idx]
                if lane.playing then
                    lane:stop()
                else
                    lane:play()
                end
            end
            
            -- Clean up key tracking
            self:key_release(key_id)
        end
        
        return true
    end
    
    return grid_ui
end

function LaneConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return LaneConfig
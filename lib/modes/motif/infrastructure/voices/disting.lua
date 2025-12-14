-- disting.lua
-- Disting EX voice parameters for lane configuration

local disting = {}

-- Helper functions for parameter offsets
local function macro_osc_2_offset(lane_idx)
    local selected_voice = params:get("lane_" .. lane_idx .. "_disting_plaits_voice_select")
    return 11 * (selected_voice - 1)
end

local function poly_fm_offset()
    return 7
end

-- Multisample algorithm parameters
local function create_multisample_params(i)
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

-- Rings algorithm parameters
local function create_rings_params(i)
    params:add_option("lane_" .. i .. "_disting_rings_mode", "Mode", {
        "Modal Resonator", "Sympathetic Strings", "String", "FM Voice", "Sympathetic Quantized", "Strings & Reverb", "Synth"
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

    params:add_number("lane_" .. i .. "_disting_rings_polyphony", "Polyphony", 1, 4, 1)
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

-- Plaits algorithm parameters
local function create_plaits_params(i)
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
        local param_offset = macro_osc_2_offset(i)
        local shifted_index = value - 1
        crow.ii.disting.parameter(param_offset + 7, shifted_index)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_harmonics", "Harmonics", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_harmonics", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 10, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_timbre", "Timbre", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_timbre", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 11, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_morph", "Morph", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_morph", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 12, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_fm", "FM", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_fm", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 13, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_timbre_mod", "Timbre Mod", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_timbre_mod", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 14, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_morph_mod", "Morph Mod", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_plaits_morph_mod", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 15, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_low_pass_gate", "LPG", 0, 127, 127)
    params:set_action("lane_" .. i .. "_disting_plaits_low_pass_gate", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 16, n)
    end)

    params:add_number("lane_" .. i .. "_disting_plaits_time", "Time/decay", 0, 127, 64)
    params:set_action("lane_" .. i .. "_disting_plaits_time", function(n)
        local param_offset = macro_osc_2_offset(i)
        crow.ii.disting.parameter(param_offset + 17, n)
    end)
end

-- DX7 algorithm parameters
local function create_dx7_params(i)
    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_bank", "Voice Bank", 1, 27)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_bank", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice", "Voice", 1, 32)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 1, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_gain", "Voice Gain", -40, 24, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_gain", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 3, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_pan", "Voice Pan", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_pan", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 4, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_brightness", "Voice Brightness", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_brightness", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 5, value)
    end)

    params:add_number("lane_" .. i .. "_disting_poly_fm_voice_morph", "Voice Morph", -100, 100, 0)
    params:set_action("lane_" .. i .. "_disting_poly_fm_voice_morph", function(value)
        local param_offset = poly_fm_offset()
        crow.ii.disting.parameter(param_offset + 6, value)
    end)
end

-- Main entry point for creating all Disting parameters
function disting.create_params(i)
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

    params:add_control("lane_" .. i .. "_disting_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_disting_voice_volume", function(value)
        _seeker.lanes[i].disting_voice_volume = value
    end)

    -- Create algorithm-specific parameters
    create_multisample_params(i)
    create_rings_params(i)
    create_plaits_params(i)
    create_dx7_params(i)
end

return disting

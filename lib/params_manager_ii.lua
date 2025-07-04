-- params_manager_ii.lua
-- Manage norns-stored params
local params_manager_ii = {}
local musicutil = require('musicutil')
local theory = include('lib/theory_utils')
local transforms = include('lib/transforms')

-- Old Component Approach
local ClearMotif = include("lib/components/clear_motif")

-- Get sorted list of available instruments
function params_manager_ii.get_instrument_list()
    local instruments = {}
    for k, v in pairs(_seeker.skeys.instrument) do
        table.insert(instruments, k)
    end
    table.sort(instruments)
    return instruments
end

--------------------------------
-- LANE SECTION
---------------------------------
function create_keyboard_config_params(i)
    params:add_number("lane_" .. i .. "_keyboard_octave", "Keyboard Octave", 1, 7, 3)
    -- Grid offset (shifts starting position within scale)
    params:add_number("lane_" .. i .. "_grid_offset", "Grid Offset", -8, 8, 0)

    -- Scale degree offset for in-scale transposition
    params:add_number("lane_" .. i .. "_scale_degree_offset", "Scale Degree Offset", -7, 7, 0)
end

function create_mx_samples_params(i)
    -- Active
    params:add_binary("lane_" .. i .. "_mx_samples_active", "MX Samples Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_mx_samples_active", function(value)
        if value == 1 then
            _seeker.lanes[i].mx_samples_active = true
        end

        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
            _seeker.ui_state.get_focused_lane() == i then
            _seeker.screen_ui.sections.LANE:update_focused_lane(i)
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Voice volume
    params:add_control("lane_" .. i .. "_mx_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_mx_voice_volume", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].mx_voice_volume = value
        end
    end)
    
    -- Instrument
    local instruments = params_manager_ii.get_instrument_list()
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)

    -- Add ADSR envelope controls
    params:add_control("lane_" .. i .. "_attack", "Attack", controlspec.new(0, 10, 'lin', 0.1, 0, "s"))
    params:set_action("lane_" .. i .. "_attack", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].attack = value
        end
    end)

    params:add_control("lane_" .. i .. "_decay", "Decay", controlspec.new(0, 10, 'lin', 0.1, 1, "s"))
    params:set_action("lane_" .. i .. "_decay", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].decay = value
        end
    end)

    params:add_control("lane_" .. i .. "_sustain", "Sustain", controlspec.new(0, 2, 'lin', 0.1, 0.9, "amp"))
    params:set_action("lane_" .. i .. "_sustain", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].sustain = value
        end
    end)

    params:add_control("lane_" .. i .. "_release", "Release", controlspec.new(0, 10, 'lin', 0.1, 2, "s"))
    params:set_action("lane_" .. i .. "_release", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].release = value
        end
    end)
    -- Pan
    params:add_control("lane_" .. i .. "_pan", "Pan", controlspec.new(-1, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_pan", function(value)
        if _seeker.lanes[i] then
            -- Store pan value on lane for use during note playback
            _seeker.lanes[i].pan = value
        end
    end)

    -- LPF
    params:add_taper("lane_" .. i .. "_lpf", "LPF Cutoff", 20, -- min
    20000, -- max
    20000, -- default (maximum = no filtering)
    3, -- k (curve shape)
    "Hz" -- units
    )

    params:set_action("lane_" .. i .. "_lpf", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].lpf = value
        end
    end)

    params:add_control("lane_" .. i .. "_resonance", "LPF Resonance", controlspec.new(0, 4, 'lin', 0.01, 0, ""))
    params:set_action("lane_" .. i .. "_resonance", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].resonance = value
        end
    end)

    -- Add high-pass filter with taper for better control
    params:add_taper("lane_" .. i .. "_hpf", "HPF Cutoff", 20, -- min
    20000, -- max
    20, -- default (minimum = no filtering)
    3, -- k (curve shape)
    "Hz" -- units
    )
    params:set_action("lane_" .. i .. "_hpf", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].hpf = value
        end
    end)

    -- Add delay send
    params:add_control("lane_" .. i .. "_delay_send", "Delay Send", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_delay_send", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].delay_send = value
        end
    end)

    -- Add reverb send
    params:add_control("lane_" .. i .. "_reverb_send", "Reverb Send", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_reverb_send", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].reverb_send = value
        end
    end)
end

function create_midi_params(i)
    -- Active
    params:add_binary("lane_" .. i .. "_midi_active", "MIDI Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_midi_active", function(value)
        if value == 1 then
            _seeker.lanes[i].midi_active = true
        end

        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
            _seeker.ui_state.get_focused_lane() == i then
            _seeker.screen_ui.sections.LANE:update_focused_lane(i)
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- MIDI voice volume
    params:add_control("lane_" .. i .. "_midi_voice_volume", "MIDI Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_midi_voice_volume", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].midi_voice_volume = value
        end
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

function create_crow_txo_params(i)
    -- Active   
    params:add_binary("lane_" .. i .. "_eurorack_active", "CV/Gate Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_eurorack_active", function(value)
        if value == 1 then
            _seeker.lanes[i].eurorack_active = true
        end

        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
            _seeker.ui_state.get_focused_lane() == i then
            _seeker.screen_ui.sections.LANE:update_focused_lane(i)
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    params:add_control("lane_" .. i .. "_euro_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_euro_voice_volume", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].euro_voice_volume = value
        end
    end)

    params:add_option("lane_" .. i .. "_gate_out", "Gate Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
    params:add_option("lane_" .. i .. "_cv_out", "CV Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo cv 1", "txo cv 2", "txo cv 3", "txo cv 4"}, 1)
    params:add_option("lane_" .. i .. "_loop_start_trigger", "Loop Start Trigger",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
end

function create_just_friends_params(i)
    -- Add Just Friends
    params:add_binary("lane_" .. i .. "_just_friends_active", "Just Friends Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_just_friends_active", function(value)
        -- Turn JF on or off based on parameter
        if value == 1 then
            crow.ii.jf.mode(1)
        else
            crow.ii.jf.mode(0)
        end

        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
        _seeker.ui_state.get_focused_lane() == i then
        _seeker.screen_ui.sections.LANE:update_focused_lane(i)
        _seeker.screen_ui.set_needs_redraw()
        end
    end)
    -- Voice volume
    params:add_control("lane_" .. i .. "_just_friends_voice_volume", "Voice Volume",
        controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_just_friends_voice_volume", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].just_friends_voice_volume = value
        end
    end)
    -- Voice selection (All or 1-6)
    params:add_option("lane_" .. i .. "_just_friends_voice_select", "JF Voice", {"All", "1", "2", "3", "4", "5", "6"}, 1)
    params:set_action("lane_" .. i .. "_just_friends_voice_select", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].just_friends_voice_select = value
        end
    end)
end

function create_wsyn_params(i)
    -- Add w/ synth mode
    params:add_binary("lane_" .. i .. "_wsyn_active", "w/Synth Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_wsyn_active", function(value)
        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
        _seeker.ui_state.get_focused_lane() == i then
        _seeker.screen_ui.sections.LANE:update_focused_lane(i)
        _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Voice volume
    params:add_control("lane_" .. i .. "_wsyn_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_wsyn_voice_volume", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].wsyn_voice_volume = value
        end
    end)

    -- Voice selection (All or 1-6)
    params:add_option("lane_" .. i .. "_wsyn_voice_select", "w/syn Voice", {"All", "1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_voice_select", function(value)
        if _seeker.lanes[i] then
            _seeker.lanes[i].wsyn_voice_select = value
        end
    end)

    -- w/syn parameters
    params:add_option("lane_" .. i .. "_wsyn_ar_mode", "AR Mode", {"Off", "On"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_ar_mode", function(value)
        if value == 2 then
            crow.ii.wsyn.ar_mode(1)
        else
            crow.ii.wsyn.ar_mode(0)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_curve", "Curve", controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_curve", function(value)
        crow.ii.wsyn.curve(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_ramp", "Ramp", controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_ramp", function(value)
        crow.ii.wsyn.ramp(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_index", "FM Index", controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_fm_index", function(value)
        crow.ii.wsyn.fm_index(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_env", "FM Env", controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_fm_env", function(value)
        crow.ii.wsyn.fm_env(value)
    end)

    -- Add numerator and denominator parameters
    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_num", "FM Ratio Numerator", controlspec.new(0.01, 1, 'lin', 0.01, 0.5))
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_num", function(numerator)
        if _seeker.lanes[i] then
            local denominator = params:get("lane_" .. i .. "_wsyn_fm_ratio_denom")
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_denom", "FM Ratio Denominator", controlspec.new(0.01, 1, 'lin', 0.01, 0.5))
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_denom", function(denominator)
        if _seeker.lanes[i] then
            local numerator = params:get("lane_" .. i .. "_wsyn_fm_ratio_num") 
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_time", "LPG Time", controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_lpg_time", function(value)
        crow.ii.wsyn.lpg_time(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_symmetry", "LPG Symmetry",
        controlspec.new(-5, 5, 'lin', 0.1, 0, ""))
    params:set_action("lane_" .. i .. "_wsyn_lpg_symmetry", function(value)
        crow.ii.wsyn.lpg_symmetry(value)
    end)

    -- w/syn patch parameters for THIS and THAT jacks
    -- Patch THIS jack (jack 1) to parameter destination
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
        -- Map the option index to the parameter number (1-10)
        local param_map = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local param_num = param_map[value]
        crow.ii.wsyn.patch(2, param_num)
    end)
end

function create_osc_params(i)
    -- OSC Active
    params:add_binary("lane_" .. i .. "_osc_active", "OSC Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_osc_active", function(value)
        if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
            _seeker.ui_state.get_focused_lane() == i then
            _seeker.screen_ui.sections.LANE:update_focused_lane(i)
            _seeker.screen_ui.set_needs_redraw()
        end
    end)
end

function create_motif_playback_params(i)
    -- Playback octave offset
    params:add_number("lane_" .. i .. "_playback_offset", "Playback Offset", -3, 3, 0)

    -- TODO: These times may note be having the anticipated effect. Check.
    -- Replace continuous speed with musical ratios
    params:add_option("lane_" .. i .. "_speed", "Speed",
        {"1/12x", "1/11x", "1/10x", "1/9x", "1/8x", "1/7x", "1/6x", "1/5x", "1/4x", "1/3x", "1/2x", "1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x", "11x", "12x"}, 12)
    params:set_action("lane_" .. i .. "_speed", function(value)
        local speed_ratios = {0.0833, 0.0909, 0.1, 0.1111, 0.125, 0.1429, 0.1667, 0.1818, 0.25, 0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0}
        if _seeker.lanes[i] then
            _seeker.lanes[i].speed = speed_ratios[value]
        end
    end)

end

function create_stage_tracker_params(i)
    -- See forms.lua for stage configuration
    for j = 1, 4 do

        params:add_number("lane_" .. i .. "_stage_" .. j .. "_loops", "Loops", 1, 10, 2)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_loops", function(value)
            if _seeker.lanes[i] then
                _seeker.lanes[i]:sync_stage_from_params(j)
            end
        end)

        -- Add loop end trigger
        params:add_option("lane_" .. i .. "_stage_" .. j .. "_loop_trigger", "Loop Trigger", {"none", "crow 1",
                                                                                              "crow 2", "crow 3",
                                                                                              "crow 4", "txo tr 1",
                                                                                              "txo tr 2", "txo tr 3",
                                                                                              "txo tr 4"}, 1)

        -- Add transform selection for each slot
        local transform_names = {}
        for name, _ in pairs(transforms.available) do
            table.insert(transform_names, name)
        end
        table.sort(transform_names) -- For consistent ordering

        params:add_option("lane_" .. i .. "_stage_" .. j .. "_transform", "Transform", transform_names, #transform_names)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_transform", function(value)
            _seeker.lanes[i]:change_stage_transform(i, j, transform_names[value])
        end)
    end
end

function init_lane_params()
    local instruments = params_manager_ii.get_instrument_list()
    for i = 1, 8 do
        params:add_group("lane_" .. i, "LANE " .. i .. " VOICES", 59)
        params:add_option("lane_" .. i .. "_visible_voice", "Config Voice:",
            {"MX Samples", "MIDI", "Crow/TXO", "Just Friends", "w/syn", "OSC"})
        params:set_action("lane_" .. i .. "_visible_voice", function(value)
            -- Update lane section if it's currently showing this lane
            if _seeker.screen_ui and _seeker.ui_state.get_current_section() == "LANE" and
                _seeker.ui_state.get_focused_lane() == i then
                _seeker.screen_ui.sections.LANE:update_focused_lane(i)
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Volume
        params:add_control("lane_" .. i .. "_volume", "Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
        params:set_action("lane_" .. i .. "_volume", function(value)
            _seeker.lanes[i].volume = value
        end)

        create_keyboard_config_params(i)
        create_mx_samples_params(i)
        create_midi_params(i)
        create_crow_txo_params(i)
        create_just_friends_params(i)
        create_wsyn_params(i)
        create_osc_params(i)
        create_stage_tracker_params(i)
        create_motif_playback_params(i)
    end
end

-- Initialize MIDI input parameters
local function add_midi_input_params()
    params:add_group("midi_input", "MIDI INPUT", 1)

    -- MIDI input device selection (None = disabled)
    local midi_devices = {"None"}
    for i = 1, #midi.vports do
        local name = midi.vports[i].name or string.format("Port %d", i)
        table.insert(midi_devices, name)
    end

    params:add{
        type = "option",
        id = "midi_input_device",
        name = "MIDI Input Device",
        options = midi_devices,
        default = 2, -- Default to first available device
        action = function(value)
            if _seeker.midi_input then
                if value > 1 then
                    -- Enable MIDI and set device
                    _seeker.midi_input.set_enabled(true)
                    _seeker.midi_input.set_device(value - 1)
                else
                    -- Disable MIDI input when "None" is selected
                    _seeker.midi_input.set_enabled(false)
                end
            end
        end
    }
end

function params_manager_ii.init_params()
    init_lane_params()

    -- Initialize components
    ClearMotif.init().params.create()
    
    -- Add MIDI input parameters
    add_midi_input_params()
end

return params_manager_ii

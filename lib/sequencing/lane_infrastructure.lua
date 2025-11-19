-- lane_infrastructure.lua
-- Creates the foundational parameter structure that lane.lua depends on
-- Intended to be centralized Lane setup so that components like @lane_config and @stage_config are focused on configuration, not infrastructure

local theory = include('lib/motif_core/theory')
local transforms = include('lib/motif_core/transforms')
local lane_infrastructure = {}

-- Create stage-related parameters that lane.lua needs for sequencing
local function create_stage_params(i)
    
    params:add_group("lane_" .. i .. "_stage_setup", "STAGE SETUP", 44)
    -- Create four stages per lane with their defaults
    -- NB: Many of these params are not (yet?) available on the front end. Most notably: loop count and trigger
    for stage_idx = 1, 4 do
        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", "Loops", 1, 10, 2)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", function(value)
            _seeker.lanes[i]:sync_stage_from_params(stage_idx)
        end)

        -- By default stage 1 is active and stages 2-4 are not
        local default_active = 1
        if stage_idx == 1 then
            default_active = 2
        end
        
        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_active", "Active", {"No", "Yes"}, default_active)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_active", function(value)
            _seeker.lanes[i]:sync_stage_from_params(stage_idx)
        end)

        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_reset_motif", "Reset Motif", {"No", "Yes"}, 2)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_reset_motif", function(value)
            _seeker.lanes[i]:sync_stage_from_params(stage_idx)
        end)

        -- Loop trigger parameters
        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_loop_trigger", "Loop Trigger", 
            {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)

        -- Transform selection for lane.lua
        local transform_names = {}
        for name, _ in pairs(transforms.available) do
            table.insert(transform_names, name)
        end
        table.sort(transform_names)

        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_transform", "Transform", transform_names, #transform_names)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_transform", function(value)
            _seeker.lanes[i]:change_stage_transform(i, stage_idx, transform_names[value])
        end)

        -- Arpeggio-specific stage parameters (velocity curves and strum)
        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_velocity_curve", "Velocity Curve",
            {"Flat", "Crescendo", "Decrescendo", "Wave", "Accent First", "Accent Last", "Random"}, 1)

        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_velocity_min", "Velocity Min", 1, 127, 60)
        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_velocity_max", "Velocity Max", 1, 127, 100)

        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_strum_curve", "Strum Curve",
            {"None", "Gentle", "Picking", "Sweep", "Natural"}, 1)

        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_strum_amount", "Strum Amount", 0, 100, 0, function(param) return param.value .. "%" end)

        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_arpeggio_strum_direction", "Strum Direction",
            {"Forward", "Reverse", "Center Out", "Edges In", "Thumb First", "Random"}, 1)
    end
end

-- Create motif playback parameters that lane.lua uses
-- TODO: These should be moved to @play_motif.lua when that component is refactored
local function create_motif_playback_params(i)
    params:add_group("lane_" .. i .. "_motif_playback", "MOTIF PLAYBACK", 3)
    -- Playback octave offset
    params:add_number("lane_" .. i .. "_playback_offset", "Playback Offset", -3, 3, 0)

    -- Speed control with musical ratios
    params:add_option("lane_" .. i .. "_speed", "Speed",
        {"1/12x", "1/11x", "1/10x", "1/9x", "1/8x", "1/7x", "1/6x", "1/5x", "1/4x", "1/3x", "1/2x", "1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x", "11x", "12x"}, 12)
    params:set_action("lane_" .. i .. "_speed", function(value)
        local speed_ratios = {0.0833, 0.0909, 0.1, 0.1111, 0.125, 0.1429, 0.1667, 0.1818, 0.25, 0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0}
        _seeker.lanes[i].speed = speed_ratios[value]
    end)

    -- Quantize control
    params:add_option("lane_" .. i .. "_quantize", "Quantize",
        {"off", "1/32", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1"}, 3)
end

-- Create basic lane parameters that lane.lua needs
local function create_basic_lane_params(i)
    -- Core lane parameters
    params:add_group("lane_" .. i .. "_infrastructure", "INFRASTRUCTURE", 5)

    -- Per-lane motif creation type
    params:add_option("lane_" .. i .. "_motif_type", "Motif Type", {"Tape", "Arpeggio"}, 1)
    params:set_action("lane_" .. i .. "_motif_type", function(value)
        -- Stop playback when switching modes
        if _seeker and _seeker.lanes and _seeker.lanes[i] then
            _seeker.lanes[i]:stop()
        end

        -- Rebuild UI if initialized
        if _seeker and _seeker.create_motif and _seeker.create_motif.screen then
            _seeker.create_motif.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Per-Lane keyboard tuning
    params:add_number("lane_" .. i .. "_keyboard_octave", "Keyboard Octave", 1, 7, 3)
    params:add_number("lane_" .. i .. "_grid_offset", "Grid Offset", -8, 8, 0)

    -- Volume parameter that lane.lua expects
    params:add_control("lane_" .. i .. "_volume", "Volume", controlspec.new(0, 1, 'lin', 0.02, 1, ""))
    params:set_action("lane_" .. i .. "_volume", function(value)
        _seeker.lanes[i].volume = value
    end)

    -- Scale degree offset for in-scale transposition (used by lane.lua)
    params:add_number("lane_" .. i .. "_scale_degree_offset", "Scale Degree Offset", -7, 7, 0)

end

-- Create arpeggio sequencer parameters for each lane
-- NOTE: Arpeggio params are technically generation/creation params (used by recorder), not sequencing params
-- Architecturally they might belong in a component or in motif_core, but lane_infrastructure serves as the
-- param dumping ground for all lane-related parameters to keep them grouped in PARAMS menu
local function create_arpeggio_lane_params(i)
    params:add_group("lane_" .. i .. "_arpeggio", "ARPEGGIO SEQUENCER", 16)

    params:add_number("lane_" .. i .. "_arpeggio_num_steps", "Number of Steps", 4, 24, 16)
    params:add_option("lane_" .. i .. "_arpeggio_chord_root", "Chord Root", {"I", "ii", "iii", "IV", "V", "vi", "vii°"}, 1)
    params:add_option("lane_" .. i .. "_arpeggio_chord_type", "Chord Type",
        {"Diatonic", "Major", "Minor", "Sus2", "Sus4", "Maj7", "Min7", "Dom7", "Dim", "Aug"}, 1)
    params:add_number("lane_" .. i .. "_arpeggio_chord_length", "Chord Length", 1, 12, 3)
    params:add_option("lane_" .. i .. "_arpeggio_chord_inversion", "Chord Inversion",
        {"Root", "1st", "2nd", "3rd"}, 1)
    params:add_option("lane_" .. i .. "_arpeggio_chord_direction", "Chord Direction",
        {"Up", "Down", "Up-Down", "Down-Up", "Random"}, 1)
    params:add_option("lane_" .. i .. "_arpeggio_chord_phasing", "Chord Phasing",
        {"Off", "On"}, 1)
    params:add_number("lane_" .. i .. "_arpeggio_note_duration", "Note Duration", 1, 99, 50, function(param) return param.value .. "%" end)
    params:add_option("lane_" .. i .. "_arpeggio_step_length", "Step Length",
        {"1/32", "1/24", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "16", "24", "32"}, 12)

    -- Velocity curve params
    params:add_option("lane_" .. i .. "_arpeggio_velocity_curve", "Velocity Curve",
        {"Flat", "Crescendo", "Decrescendo", "Wave", "Accent First", "Accent Last", "Random"}, 1)
    params:add_number("lane_" .. i .. "_arpeggio_velocity_min", "Velocity Min", 1, 127, 60)
    params:add_number("lane_" .. i .. "_arpeggio_velocity_max", "Velocity Max", 1, 127, 100)

    -- Strum params (strum amount is percentage of total sequence duration)
    params:add_option("lane_" .. i .. "_arpeggio_strum_curve", "Strum Curve",
        {"None", "Gentle", "Picking", "Sweep", "Natural"}, 1)
    params:add_number("lane_" .. i .. "_arpeggio_strum_amount", "Strum Amount", 0, 100, 0, function(param) return param.value .. "%" end)
    params:add_option("lane_" .. i .. "_arpeggio_strum_direction", "Strum Direction",
        {"Forward", "Reverse", "Center Out", "Edges In", "Thumb First", "Random"}, 1)
end

-- Initialize all lane infrastructure parameters
function lane_infrastructure.init()
    print("⚙ Setting up lane infrastructure...")

    -- Create infrastructure parameters for all 8 lanes
    -- NB: Ideally we would also want to create the params in @stage_config and @lane_config here so they stay grouped in the PARAMS UI. Long list thing.
    for i = 1, 8 do
        params:add_separator("lane_" .. i .. "_separator", "LANE " .. i)
        create_stage_params(i)
        create_basic_lane_params(i)
        create_motif_playback_params(i)
        create_arpeggio_lane_params(i)
    end
    
    print("⚙ Lane infrastructure complete")
end

return lane_infrastructure
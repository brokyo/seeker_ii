-- lane_infrastructure.lua
-- Creates the foundational parameter structure that lane.lua depends on
-- Intended to be centralized Lane setup so that components like @lane_config and @stage_config are focused on configuration, not infrastructure

local lane_infrastructure = {}

-- Create stage-related parameters that lane.lua needs for sequencing
local function create_stage_params(i)
    -- Separate repository for transforms. Makes maintenance easier and keeps boundaries clear.
    local transforms = include('lib/transforms')
    
    params:add_group("lane_" .. i .. "_stage", "STAGE CONFIG", 24)
    -- Create four stages per lane with their defaults
    -- NB: Many of these params are not (yet?) available on the front end. Most notably: loop count and trigger
    for j = 1, 4 do
        params:add_number("lane_" .. i .. "_stage_" .. j .. "_loops", "Loops", 1, 10, 2)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_loops", function(value)
            _seeker.lanes[i]:sync_stage_from_params(j)
        end)

        -- By default stage 1 enabled and stages 2-4 are disabled
        local default_enabled = 2
        if j == 1 then
            default_enabled = 1
        end
        
        params:add_option("lane_" .. i .. "_stage_" .. j .. "_enabled", "Enabled", {"Yes", "No"}, default_enabled)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_enabled", function(value)
            _seeker.lanes[i]:sync_stage_from_params(j)
        end)

        params:add_option("lane_" .. i .. "_stage_" .. j .. "_mute", "Mute", {"Yes", "No"}, 2)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_mute", function(value)
            _seeker.lanes[i]:sync_stage_from_params(j)
        end)
        
        params:add_option("lane_" .. i .. "_stage_" .. j .. "_reset_motif", "Reset Motif", {"Yes", "No"}, 1)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_reset_motif", function(value)
            _seeker.lanes[i]:sync_stage_from_params(j)
        end)

        -- Loop trigger parameters
        params:add_option("lane_" .. i .. "_stage_" .. j .. "_loop_trigger", "Loop Trigger", 
            {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)

        -- Transform selection for lane.lua
        local transform_names = {}
        for name, _ in pairs(transforms.available) do
            table.insert(transform_names, name)
        end
        table.sort(transform_names)

        params:add_option("lane_" .. i .. "_stage_" .. j .. "_transform", "Transform", transform_names, #transform_names)
        params:set_action("lane_" .. i .. "_stage_" .. j .. "_transform", function(value)
            _seeker.lanes[i]:change_stage_transform(i, j, transform_names[value])
        end)
    end
end

-- Create motif playback parameters that lane.lua uses
-- TODO: These should be moved to @play_motif.lua when that component is refactored
local function create_motif_playback_params(i)
    params:add_group("lane_" .. i .. "_motif_playback", "MOTIF PLAYBACK", 2)
    -- Playback octave offset
    params:add_number("lane_" .. i .. "_playback_offset", "Playback Offset", -3, 3, 0)

    -- Speed control with musical ratios
    params:add_option("lane_" .. i .. "_speed", "Speed",
        {"1/12x", "1/11x", "1/10x", "1/9x", "1/8x", "1/7x", "1/6x", "1/5x", "1/4x", "1/3x", "1/2x", "1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x", "11x", "12x"}, 12)
    params:set_action("lane_" .. i .. "_speed", function(value)
        local speed_ratios = {0.0833, 0.0909, 0.1, 0.1111, 0.125, 0.1429, 0.1667, 0.1818, 0.25, 0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0}
        _seeker.lanes[i].speed = speed_ratios[value]
    end)
end

-- Create basic lane parameters that lane.lua needs
local function create_basic_lane_params(i)
    -- Core lane parameters
    params:add_group("lane_" .. i, "INFRASTRUCTURE", 5)
    
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
    
    -- Loop start trigger for lane sequencing
    params:add_option("lane_" .. i .. "_loop_start_trigger", "Loop Start Trigger", 
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
end

-- Initialize all lane infrastructure parameters
function lane_infrastructure.init()
    print("⚙ Setting up lane infrastructure...")
    
    -- Create infrastructure parameters for all 8 lanes
    -- NB: Ideally we would also want to create the params in @stage_config and @lane_config here so they stay grouped in the PARAMS UI. Long list thing.
    for i = 1, 8 do
        params:add_separator("lane_" .. i .. "_separator", "LANE " .. i)
        create_basic_lane_params(i)
        create_stage_params(i)
        create_motif_playback_params(i)
    end
    
    print("⚙ Lane infrastructure complete")
end

return lane_infrastructure
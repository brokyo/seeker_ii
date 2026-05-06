-- lane_infrastructure.lua
-- Creates foundational parameters that lane.lua REQUIRES during initialization:
--   - Stage params (loops, active, reset_motif, transform) - read by Lane:sync_stage_from_params()
--   - Volume param - read by Lane.new()
--   - Playback params (offset, speed, quantize) - read by Lane playback logic
--   - Keyboard octave - read by keyboard components
--   - Scale degree offset - read by Lane note transformation
--
-- DOES NOT create:
--   - Instrument, MIDI device, sends (created in @lane_config)
--   - Composer params (created in @composer_expression_stages)
--   - Transform params (created in @stage_config)

local theory = include('lib/modes/motif/core/theory')
local transforms = include('lib/modes/motif/core/transforms')
local fileselect = require("fileselect")
local LaneMap = include("lib/lanes/lane_map")
local lane_infrastructure = {}

-- Create stage-related parameters that lane.lua needs for sequencing
local function create_stage_params(i)
    local sub_mode = LaneMap.from_flat(i)
    local local_index = i - LaneMap.OFFSETS[sub_mode]
    local label = sub_mode:sub(1,1):upper() .. sub_mode:sub(2) .. " " .. local_index

    params:add_group("lane_" .. i .. "_stage_setup", label .. " STAGE SETUP", 48)
    for stage_idx = 1, 8 do
        -- Stage volume (used by all motif types)
        params:add_control("lane_" .. i .. "_stage_" .. stage_idx .. "_volume", "Volume", controlspec.new(0, 1, "lin", 0.01, 1, ""))

        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", "Loops", 1, 10, 2)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", function(value)
            _seeker.lanes[i]:sync_stage_from_params(stage_idx)
        end)

        -- Composer: all stages active. Tape/Sampler: only stage 1.
        local all_active = (sub_mode == "composer")
        local active_default = (all_active or stage_idx == 1) and 2 or 1
        params:add_option("lane_" .. i .. "_stage_" .. stage_idx .. "_active", "Active", {"No", "Yes"}, active_default)
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
    end
end

-- Create motif playback parameters that lane.lua uses
-- TODO: These should be moved to @play_motif.lua when that component is refactored
local function create_motif_playback_params(i)
    local sub_mode = LaneMap.from_flat(i)
    local local_index = i - LaneMap.OFFSETS[sub_mode]
    local label = sub_mode:sub(1,1):upper() .. sub_mode:sub(2) .. " " .. local_index
    params:add_group("lane_" .. i .. "_motif_playback", label .. " PLAYBACK", 5)
    -- Octave offset for playback transposition
    params:add_number("lane_" .. i .. "_octave_offset", "Octave Offset", -8, 8, 0)

    -- Speed control with musical ratios
    params:add_option("lane_" .. i .. "_speed", "Speed",
        {"1/12x", "1/11x", "1/10x", "1/9x", "1/8x", "1/7x", "1/6x", "1/5x", "1/4x", "1/3x", "1/2x", "2/3x", "1x", "1.5x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x", "11x", "12x"}, 13)
    params:set_action("lane_" .. i .. "_speed", function(value)
        local speed_ratios = {0.0833, 0.0909, 0.1, 0.1111, 0.125, 0.1429, 0.1667, 0.1818, 0.25, 0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0}
        _seeker.lanes[i].speed = speed_ratios[value]
    end)

    -- Quantize control
    params:add_option("lane_" .. i .. "_quantize", "Quantize",
        {"off", "1/8", "1/4", "1/2", "1"}, 2)

    -- Swing control (0-100%, applied to even subdivisions when quantize is active)
    params:add_control("lane_" .. i .. "_swing", "Swing",
        controlspec.new(0, 100, 'lin', 1, 0, '%'))

    -- Phase offset for loop alignment (in beats)
    params:add_control("lane_" .. i .. "_offset", "Offset",
        controlspec.new(-16, 16, 'lin', 0.01, 0, 'beats'))
end

-- Create basic lane parameters that lane.lua needs
local function create_basic_lane_params(i)
    local sub_mode = LaneMap.from_flat(i)
    local local_index = i - LaneMap.OFFSETS[sub_mode]
    local label = sub_mode:sub(1,1):upper() .. sub_mode:sub(2) .. " " .. local_index

    -- Core lane parameters
    params:add_group("lane_" .. i .. "_infrastructure", label .. " CORE", 7)

    -- Motif type is fixed per lane based on sub-mode assignment
    params:add_option("lane_" .. i .. "_motif_type", "Motif Type", {"Tape", "Composer", "Sampler", "Form"}, 1)

    -- File selector for loading audio samples into softcut buffers
    params:add_binary("lane_" .. i .. "_load_sample", "Load Sample", "trigger", 0)
    params:set_action("lane_" .. i .. "_load_sample", function()
        local audio_path = _path.audio .. "seeker_ii"

        -- Track fileselect state (norns fileselect takes over screen, no modal needed)
        if _seeker and _seeker.sampler then
            _seeker.sampler.file_select_active = true
        end

        fileselect.enter(audio_path, function(filepath)
            -- Clear fileselect state and reset screen styles (fileselect leaves font dirty)
            if _seeker and _seeker.sampler then
                _seeker.sampler.file_select_active = false
            end
            screen.font_face(1)
            screen.font_size(8)

            if filepath and filepath ~= "cancel" then
                -- Delay load to let fileselect screen cleanup complete
                clock.run(function()
                    clock.sleep(0.1)
                    if _seeker and _seeker.sampler then
                        _seeker.sampler.load_file(i, filepath)
                    end
                    if _seeker and _seeker.screen_ui then
                        _seeker.screen_ui.set_needs_redraw()
                    end
                end)
            else
                if _seeker and _seeker.screen_ui then
                    _seeker.screen_ui.set_needs_redraw()
                end
            end
        end)
    end)

    -- Record audio input directly into sampler buffer
    params:add_binary("lane_" .. i .. "_record_sample", "Record Sample", "trigger", 0)
    params:set_action("lane_" .. i .. "_record_sample", function()
        if _seeker and _seeker.sampler then
            if _seeker.sampler.is_recording then
                _seeker.sampler.stop_recording(i)
            else
                _seeker.sampler.start_recording(i)
            end
            _seeker.lane_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Per-Lane keyboard tuning
    params:add_number("lane_" .. i .. "_keyboard_octave", "Keyboard Octave", 1, 7, 3)
    params:add_number("lane_" .. i .. "_grid_offset", "Grid Offset", -8, 8, -4)

    -- Volume parameter that lane.lua expects
    params:add_control("lane_" .. i .. "_volume", "Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_volume", function(value)
        _seeker.lanes[i].volume = value
    end)

    -- Scale degree offset for in-scale transposition (used by lane.lua)
    params:add_number("lane_" .. i .. "_scale_degree_offset", "Scale Degree Offset", -7, 7, 0)

end


-- Initialize all lane infrastructure parameters
function lane_infrastructure.init()
    for i = 1, LaneMap.ACTIVE_LANES do
        create_stage_params(i)
        create_basic_lane_params(i)
        create_motif_playback_params(i)
    end
end

return lane_infrastructure
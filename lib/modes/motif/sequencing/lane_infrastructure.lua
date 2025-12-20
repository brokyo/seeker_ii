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
local lane_infrastructure = {}

-- Create stage-related parameters that lane.lua needs for sequencing
local function create_stage_params(i)

    params:add_group("lane_" .. i .. "_stage_setup", "LANE " .. i .. " STAGE SETUP", 24)
    -- Create four stages per lane with their defaults
    for stage_idx = 1, 4 do
        -- Stage volume (used by all motif types)
        params:add_control("lane_" .. i .. "_stage_" .. stage_idx .. "_volume", "Volume", controlspec.new(0, 1, "lin", 0.01, 1, ""))

        params:add_number("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", "Loops", 1, 10, 2)
        params:set_action("lane_" .. i .. "_stage_" .. stage_idx .. "_loops", function(value)
            _seeker.lanes[i]:sync_stage_from_params(stage_idx)
        end)

        -- Stage 1 defaults active, stages 2-4 default inactive
        local active_default = (stage_idx == 1) and 2 or 1
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
    params:add_group("lane_" .. i .. "_motif_playback", "LANE " .. i .. " PLAYBACK", 4)
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
        {"off", "1/32", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1"}, 3)

    -- Swing control (0-100%, applied to even subdivisions when quantize is active)
    params:add_control("lane_" .. i .. "_swing", "Swing",
        controlspec.new(0, 100, 'lin', 1, 0, '%'))
end

-- Create basic lane parameters that lane.lua needs
local function create_basic_lane_params(i)
    -- Core lane parameters
    params:add_group("lane_" .. i .. "_infrastructure", "LANE " .. i .. " CORE", 7)

    -- Per-lane motif creation type
    params:add_option("lane_" .. i .. "_motif_type", "Motif Type", {"Tape", "Composer", "Sampler"}, 1)
    params:set_action("lane_" .. i .. "_motif_type", function(value)
        -- Sampler mode limited to 2 simultaneous lanes (softcut has 2 mono buffers)
        -- Prevent switching to sampler if buffers are full
        if value == 3 and _seeker and _seeker.sampler then
            local has_buffer = _seeker.sampler.get_buffer_for_lane(i) ~= nil
            if not has_buffer then
                -- Check if we can allocate a new buffer
                local available = false
                for buffer_id = 1, 2 do
                    if not _seeker.sampler.buffer_occupied[buffer_id] then
                        available = true
                        break
                    end
                end

                if not available then
                    -- Revert to previous value (Tape)
                    params:set("lane_" .. i .. "_motif_type", 1, true)
                    return
                end
            end
        end

        -- Stop playback when switching modes
        if _seeker and _seeker.lanes and _seeker.lanes[i] then
            _seeker.lanes[i]:stop()
            -- Stop any playing sampler voices for this lane
            if _seeker.sampler then
                for pad = 1, 16 do
                    _seeker.sampler.stop_pad(i, pad)
                end
            end
        end

        -- Set stage defaults based on motif type
        -- Composer: enable all 4 stages (typical workflow uses all stages)
        -- Tape/Sampler: enable only stage 1 (additional stages inactive by default)
        local all_stages_active = (value == 2)  -- Composer
        for stage_idx = 1, 4 do
            if all_stages_active then
                params:set("lane_" .. i .. "_stage_" .. stage_idx .. "_active", 2, true)
            else
                params:set("lane_" .. i .. "_stage_" .. stage_idx .. "_active", (stage_idx == 1) and 2 or 1, true)
            end
        end

        -- Rebuild screens (motif type affects tape_create params and Lane Config voice routing)
        if _seeker and _seeker.tape and _seeker.tape.create and _seeker.tape.create.screen then
            _seeker.tape.create.screen:rebuild_params()
        end
        if _seeker and _seeker.lane_config and _seeker.lane_config.screen then
            _seeker.lane_config.screen:rebuild_params()
        end
        if _seeker and _seeker.screen_ui then
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

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
    -- Create infrastructure parameters for all 8 lanes
    -- NB: Ideally we would also want to create the params in @stage_config and @lane_config here so they stay grouped in the PARAMS UI. Long list thing.
    for i = 1, 8 do
        create_stage_params(i)
        create_basic_lane_params(i)
        create_motif_playback_params(i)
    end
end

return lane_infrastructure
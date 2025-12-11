-- stage_config.lua
-- Configure tape mode stage transformations
-- Provides screen UI and parameters for tape transform stages
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local tape_transforms = include("lib/modes/motif/core/transforms")
local tape_transform = include("lib/modes/motif/types/tape/transform")

local TapeStageConfig = {}

-- Use tape transform UI names for transform selector
local transform_types = tape_transforms.ui_names

-- Local state for stage configuration
local config_state = {
    selected_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_tape_transform_stage", "LANE " .. lane_idx .. " TAPE STAGE", 65)
        params:add_number("lane_" .. lane_idx .. "_tape_config_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_tape_config_stage", function(value)
            config_state.selected_stage = value
            _seeker.tape.stage_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, function(value)
                _seeker.tape.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage volume provided by lane_infrastructure (lane_X_stage_Y_volume)

            -- Tape Transform Params (Overdub Filter, Harmonize, etc.)
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode", "Filter Mode", {"Up to", "Only", "Except"}, 1)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round", "Filter Round", 1, 10, 1)

            -- Harmonize Params
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance", "Sub Octave Chance", {"Off", "Low", "Medium", "High", "Always"}, 3)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume", "Sub Octave Volume", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance", "Fifth Above Chance", {"Off", "Low", "Medium", "High", "Always"}, 3)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume", "Fifth Above Volume", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance", "Octave Above Chance", {"Off", "Low", "Medium", "High", "Always"}, 3)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume", "Octave Above Volume", 0, 100, 50, function(param) return param.value .. "%" end)

            -- Transpose Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount", "Transpose Amount", -12, 12, 1)

            -- Rotate Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount", "Rotate Amount", -12, 12, 1)

            -- Skip Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_interval", "Skip Interval", 2, 8, 2)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_offset", "Skip Offset", 0, 7, 0)

            -- Ratchet Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_chance", "Ratchet Chance", 0, 100, 90, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_max_repeats", "Max Repeats", 1, 8, 3)
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_timing", "Timing Window", {"1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8"}, 15)
        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TAPE_STAGE_CONFIG",
        name = "Tape Stage Config",
        description = "Sequence changes to the loop. Structured and probabilistic options. Harmonize is a lot of fun.",
        params = {
            { separator = true, title = "Tape Stage Config" },
        }
    })

    local original_enter = norns_ui.enter

    norns_ui.enter = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.selected_stage

        -- Sync the config stage param with local state
        params:set("lane_" .. lane_idx .. "_tape_config_stage", config_state.selected_stage)

        original_enter(self)
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.selected_stage

        -- Update footer to show current stage
        self.name = "Stage " .. stage_idx .. " Config"

        -- Rebuild params using tape transform module
        tape_transform.rebuild_params(self, lane_idx, stage_idx)
    end

    return norns_ui
end

function TapeStageConfig.enter(component)
    component.screen:enter()

    -- Initialize local config stage with current global focused stage
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    config_state.selected_stage = current_global_stage

    -- Sync the config stage param with local state
    params:set("lane_" .. lane_idx .. "_tape_config_stage", config_state.selected_stage)
end

function TapeStageConfig.init()
    local component = {
        screen = create_screen_ui()
    }
    create_params()

    return component
end

return TapeStageConfig

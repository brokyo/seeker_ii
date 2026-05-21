-- stage_config.lua
-- Configure tape mode stage transformations
-- Provides screen UI and parameters for tape transform stages
-- Part of lib/modes/motif/types/tape/

local NornsUI = include("lib/ui/base/norns_ui")
local tape_transforms = include("lib/modes/motif/core/transforms")
local tape_transform = include("lib/modes/motif/types/tape/transform")
local Descriptions = include("lib/ui/component_descriptions")

local TapeStageConfig = {}

-- Use tape transform UI names for transform selector
local transform_types = tape_transforms.ui_names

-- Local state for stage configuration
local config_state = {
    selected_stage = 1
}

local function create_params()
    local LaneMap = include("lib/lanes/lane_map")
    for _, lane_idx in ipairs(LaneMap.lanes_for_mode("tape")) do
        params:add_group("lane_" .. lane_idx .. "_tape_transform_stage", "LANE " .. lane_idx .. " TAPE STAGE", 57)
        params:add_number("lane_" .. lane_idx .. "_tape_config_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_tape_config_stage", function(value)
            config_state.selected_stage = value
            if _seeker.tape and _seeker.tape.stage_config and _seeker.tape.stage_config.screen then
                _seeker.tape.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, function(value)
                _seeker.tape.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage volume provided by lane_infrastructure (lane_X_stage_Y_volume)

            -- Extend Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_extend_fidelity", "Fidelity", 0, 100, 30, function(param) return param:get() .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_extend_entropy", "Entropy", 0, 100, 0, function(param) return param:get() .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_extend_reseed", "Mutate Cycle", 0, 32, 0, function(param) local v = param:get(); return v == 0 and "off" or (v .. " loops") end)

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
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount", "Transpose Amount", -16, 16, 1)
        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "TAPE_STAGE_CONFIG",
        name = "Tape Stage Config",
        description = Descriptions.TAPE_STAGE_CONFIG,
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

        -- Jump cursor to first param when switching between stages
        if self._stage_on_last_rebuild ~= stage_idx then
            self.state.selected_index = 1
            self.state.scroll_offset = 0
            self._stage_on_last_rebuild = stage_idx
        end

        -- Update footer to show current stage
        self.name = "Stage " .. stage_idx .. " Config"

        -- Update description: stage overview + transform name header + transform details
        local transform_index = params:get("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)
        local transform_name = tape_transforms.ui_names[transform_index]
        local transform_desc = tape_transforms.get_description_by_ui_index(transform_index)
        local stage_desc = Descriptions.TAPE_STAGE_CONFIG
        if transform_desc and transform_name then
            self.description = stage_desc .. "\n\n" .. string.upper(transform_name) .. "\n" .. transform_desc
        else
            self.description = stage_desc
        end

        -- Rebuild params using tape transform module
        tape_transform.rebuild_params(self, lane_idx, stage_idx)
        self:filter_active_params()
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

-- stage_config.lua
-- Configure sampler mode stage transformations
-- Provides screen UI and parameters for sampler transform stages
-- Accessed via stage_nav buttons (no dedicated grid button)
-- Part of lib/modes/motif/sampler/

local NornsUI = include("lib/ui/base/norns_ui")

local SamplerStageConfig = {}

-- Transform types for sampler
local transform_types = {"None", "Scatter", "Slide", "Reverse", "Pan Spread", "Filter Sweep"}

-- Local state for stage configuration
local config_state = {
    config_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        -- 1 config_stage + 4 stages * 8 params per stage = 33
        params:add_group("lane_" .. lane_idx .. "_sampler_transform_stage", "LANE " .. lane_idx .. " SAMPLER STAGE", 33)
        params:add_number("lane_" .. lane_idx .. "_sampler_config_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_sampler_config_stage", function(value)
            config_state.config_stage = value
            _seeker.sampler_type.stage_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, function(value)
                _seeker.sampler_type.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage volume uses shared param from lane_infrastructure (lane_X_stage_Y_volume)

            -- Scatter Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_amount", "Scatter Amount",
                controlspec.new(0, 100, "lin", 1, 50, "%"))
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_size", "Scatter Size",
                controlspec.new(1, 100, "lin", 1, 100, "%"))

            -- Slide Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_amount", "Slide Amount",
                controlspec.new(0, 100, "lin", 1, 25, "%"))
            params:add_option("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_wrap", "Slide Wrap", {"Off", "On"}, 1)

            -- Reverse Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_reverse_prob", "Reverse Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))

            -- Pan Spread Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_prob", "Pan Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_range", "Pan Range",
                controlspec.new(0, 100, "lin", 1, 100, "%"))

        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "SAMPLER_STAGE_CONFIG",
        name = "Sampler Stage Config",
        description = "Transform chop parameters across stages. Primarily time and rate manipulation.",
        params = {
            { separator = true, title = "Sampler Stage Config" },
        }
    })

    local original_enter = norns_ui.enter

    norns_ui.enter = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.config_stage

        -- Sync the config stage param with local state
        params:set("lane_" .. lane_idx .. "_sampler_config_stage", config_state.config_stage)

        original_enter(self)
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.config_stage

        -- Update footer to show current stage
        self.name = "Stage " .. stage_idx .. " Config"

        -- Get the current transform type
        local transform_type = params:string("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx)

        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Settings" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
            { separator = true, title = "Transform" },
            { id = "lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx },
        }

        -- Add transform-specific parameters
        if transform_type == "Scatter" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_amount", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_size", arc_multi_float = {10, 5, 1} })
        elseif transform_type == "Slide" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_amount", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_wrap" })
        elseif transform_type == "Reverse" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_reverse_prob", arc_multi_float = {10, 5, 1} })
        elseif transform_type == "Pan Spread" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_prob", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_range", arc_multi_float = {10, 5, 1} })
        end

        -- Config section with reset and loop count
        table.insert(param_table, { separator = true, title = "Config" })
        table.insert(param_table, { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" })
        table.insert(param_table, { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" })

        -- Update the UI with the new parameter table
        self.params = param_table
    end

    return norns_ui
end

function SamplerStageConfig.enter(component)
    component.screen:enter()

    -- Initialize local config stage with current global focused stage
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    config_state.config_stage = current_global_stage

    -- Sync the config stage param with local state
    params:set("lane_" .. lane_idx .. "_sampler_config_stage", config_state.config_stage)
end

function SamplerStageConfig.init()
    local component = {
        screen = create_screen_ui()
        -- No grid button - stage config accessed via stage_nav buttons
    }
    create_params()

    return component
end

return SamplerStageConfig

-- stage_config.lua
-- Configure sampler mode stage transformations
-- Provides screen UI and parameters for sampler transform stages
-- Accessed via stage_nav buttons (no dedicated grid button)
-- Part of lib/modes/motif/types/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local Descriptions = include("lib/ui/component_descriptions")

local SamplerStageConfig = {}

-- Transform types for sampler
local transform_types = {"None", "Scatter", "Slide", "Reverse", "Pan Spread", "Filter Drift"}

-- Transform descriptions
local transform_descriptions = {
    ["None"] = "Pass-through with no changes.\n\nThe motif plays exactly as recorded.",
    ["Scatter"] = "Randomize chop timing within the loop.\n\nAmount: How much chops can shift from their original position.\nSize: Maximum shift distance as percentage of loop length.",
    ["Slide"] = "Shift all chops forward or backward in time.\n\nAmount: How far chops slide from their original position.\nWrap: When enabled, chops that slide past the end wrap to the beginning.",
    ["Reverse"] = "Randomly reverse individual chop playback.\n\nProbability: Chance each chop plays in reverse.",
    ["Pan Spread"] = "Randomize stereo position of chops.\n\nProbability: Chance each chop gets a new pan position.\nRange: How far from center chops can pan.",
    ["Filter Drift"] = "Gradually shift filter cutoff across chops.\n\nDirection: Darken lowers cutoff, Brighten raises it.\nAmount: How much the filter changes per chop."
}

-- Local state for stage configuration
local config_state = {
    config_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        -- 1 config_stage + 4 stages * 10 params per stage = 41
        params:add_group("lane_" .. lane_idx .. "_sampler_transform_stage", "LANE " .. lane_idx .. " SAMPLER STAGE", 41)
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
            params:add_binary("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_wrap", "Slide Wrap", "toggle", 0)

            -- Reverse Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_reverse_prob", "Reverse Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))

            -- Pan Spread Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_prob", "Pan Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_range", "Pan Range",
                controlspec.new(0, 100, "lin", 1, 100, "%"))

            -- Filter Drift Transform Params
            params:add_option("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_drift_direction", "Direction",
                {"Darken", "Brighten"}, 1)
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_drift_amount", "Amount",
                controlspec.new(0, 100, "lin", 1, 25, "%"))

        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "SAMPLER_STAGE_CONFIG",
        name = "Sampler Stage Config",
        description = Descriptions.SAMPLER_STAGE_CONFIG,
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

        -- Update description: stage overview + transform name header + transform details
        local transform_desc = transform_descriptions[transform_type]
        local stage_desc = Descriptions.SAMPLER_STAGE_CONFIG
        if transform_desc and transform_type then
            self.description = stage_desc .. "\n\n" .. string.upper(transform_type) .. "\n" .. transform_desc
        else
            self.description = stage_desc
        end

        local param_table = {
            { separator = true, title = "Settings" },
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
        elseif transform_type == "Filter Drift" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_drift_direction" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_drift_amount", arc_multi_float = {10, 5, 1} })
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

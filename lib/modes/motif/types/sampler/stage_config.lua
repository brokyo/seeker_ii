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
    ["Scatter"] = "Randomize chop timing within the loop.\n\nPreset: Dust (subtle), Grain (tight), Shatter (chaotic), Warp (bent).\nAmount: How much chops can shift from their original position.\nSize: Resulting chop duration as percentage of original.",
    ["Slide"] = "Shift all chops forward or backward in time.\n\nPreset: Nudge (subtle), Drift (moderate), Roam (wrap), Traverse (full).\nAmount: How far chops slide from their original position.\nWrap: When enabled, chops that slide past the end wrap to the beginning.",
    ["Reverse"] = "Randomly reverse individual chop playback.\n\nProbability: Chance each chop plays in reverse.",
    ["Pan Spread"] = "Randomize stereo position of chops.\n\nProbability: Chance each chop gets a new pan position.\nRange: How far from center chops can pan.",
    ["Filter Drift"] = "Gradually shift filter cutoff across chops.\n\nDirection: Darken lowers cutoff, Brighten raises it.\nAmount: How much the filter changes per chop."
}

-- Scatter presets: {amount, size}
local scatter_presets = {
    Custom = nil,  -- No values, used when manually adjusted
    Dust = {15, 85},   -- Subtle drift, mostly intact
    Grain = {10, 20},  -- Tight micro-grains
    Shatter = {80, 30}, -- Chaotic fragments
    Warp = {40, 90},   -- Bent but whole
}
local scatter_preset_names = {"Custom", "Dust", "Grain", "Shatter", "Warp"}

-- Find preset index for given values, or 1 (Custom) if no match
local function find_scatter_preset_for_values(amount, size)
    for i, name in ipairs(scatter_preset_names) do
        local preset = scatter_presets[name]
        if preset and preset[1] == amount and preset[2] == size then
            return i
        end
    end
    return 1  -- Custom
end

-- Slide presets: {amount, wrap}
local slide_presets = {
    Custom = nil,
    Nudge = {10, 0},    -- Subtle repositioning
    Drift = {30, 0},    -- Noticeable movement
    Roam = {60, 1},     -- Explores buffer with wrap
    Traverse = {90, 1}, -- Full buffer exploration
}
local slide_preset_names = {"Custom", "Nudge", "Drift", "Roam", "Traverse"}

local function find_slide_preset_for_values(amount, wrap)
    for i, name in ipairs(slide_preset_names) do
        local preset = slide_presets[name]
        if preset and preset[1] == amount and preset[2] == wrap then
            return i
        end
    end
    return 1  -- Custom
end

-- Local state for stage configuration
local config_state = {
    config_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        -- 1 config_stage + 4 stages * 12 params per stage = 49
        params:add_group("lane_" .. lane_idx .. "_sampler_transform_stage", "LANE " .. lane_idx .. " SAMPLER STAGE", 49)
        params:add_number("lane_" .. lane_idx .. "_sampler_config_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_sampler_config_stage", function(value)
            config_state.config_stage = value
            if _seeker.sampler_type and _seeker.sampler_type.stage_config and _seeker.sampler_type.stage_config.screen then
                _seeker.sampler_type.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, function(value)
                _seeker.sampler_type.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage volume uses shared param from lane_infrastructure (lane_X_stage_Y_volume)

            -- Scatter Transform Params
            local scatter_prefix = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_"

            params:add_option(scatter_prefix .. "preset", "Preset", scatter_preset_names, 2)  -- Default to Dust
            params:set_action(scatter_prefix .. "preset", function(value)
                local preset_name = scatter_preset_names[value]
                local preset = scatter_presets[preset_name]
                if preset then
                    -- Apply preset values to amount and size
                    params:set(scatter_prefix .. "amount", preset[1], true)
                    params:set(scatter_prefix .. "size", preset[2], true)
                end
            end)

            params:add_control(scatter_prefix .. "amount", "Amount",
                controlspec.new(0, 100, "lin", 1, 15, "%"))  -- Default matches Dust
            params:set_action(scatter_prefix .. "amount", function(value)
                local size = params:get(scatter_prefix .. "size")
                local matching_preset = find_scatter_preset_for_values(value, size)
                if params:get(scatter_prefix .. "preset") ~= matching_preset then
                    params:set(scatter_prefix .. "preset", matching_preset, true)
                end
            end)

            params:add_control(scatter_prefix .. "size", "Size",
                controlspec.new(1, 100, "lin", 1, 85, "%"))  -- Default matches Dust
            params:set_action(scatter_prefix .. "size", function(value)
                local amount = params:get(scatter_prefix .. "amount")
                local matching_preset = find_scatter_preset_for_values(amount, value)
                if params:get(scatter_prefix .. "preset") ~= matching_preset then
                    params:set(scatter_prefix .. "preset", matching_preset, true)
                end
            end)

            -- Slide Transform Params
            local slide_prefix = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_"

            params:add_option(slide_prefix .. "preset", "Preset", slide_preset_names, 2)  -- Default to Nudge
            params:set_action(slide_prefix .. "preset", function(value)
                local preset_name = slide_preset_names[value]
                local preset = slide_presets[preset_name]
                if preset then
                    params:set(slide_prefix .. "amount", preset[1], true)
                    params:set(slide_prefix .. "wrap", preset[2], true)
                end
            end)

            params:add_control(slide_prefix .. "amount", "Amount",
                controlspec.new(0, 100, "lin", 1, 10, "%"))  -- Default matches Nudge
            params:set_action(slide_prefix .. "amount", function(value)
                local wrap = params:get(slide_prefix .. "wrap")
                local matching_preset = find_slide_preset_for_values(value, wrap)
                if params:get(slide_prefix .. "preset") ~= matching_preset then
                    params:set(slide_prefix .. "preset", matching_preset, true)
                end
            end)

            params:add_binary(slide_prefix .. "wrap", "Wrap", "toggle", 0)
            params:set_action(slide_prefix .. "wrap", function(value)
                local amount = params:get(slide_prefix .. "amount")
                local matching_preset = find_slide_preset_for_values(amount, value)
                if params:get(slide_prefix .. "preset") ~= matching_preset then
                    params:set(slide_prefix .. "preset", matching_preset, true)
                end
            end)

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

        -- Jump cursor to first param when switching between stages
        if self._stage_on_last_rebuild ~= stage_idx then
            self.state.selected_index = 1
            self.state.scroll_offset = 0
            self._stage_on_last_rebuild = stage_idx
        end

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
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume", arc_multi_float = {0.1, 0.05, 0.01} },
            { separator = true, title = "Transform" },
            { id = "lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx },
        }

        -- Add transform-specific parameters
        if transform_type == "Scatter" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_preset" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_amount", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_size", arc_multi_float = {10, 5, 1} })
        elseif transform_type == "Slide" then
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_slide_preset" })
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
        self:filter_active_params()
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

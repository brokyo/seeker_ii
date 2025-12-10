-- stage_config.lua
-- Configure sampler mode stage transformations
-- Provides screen UI, grid button, and parameters for sampler transform stages
-- Part of lib/modes/motif/types/sampler/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local SamplerStageConfig = {}
SamplerStageConfig.__index = SamplerStageConfig

-- Motif type constants
local SAMPLER_MODE = 3

-- Transform types for sampler
local transform_types = {"None", "Scatter", "Reverse", "Pan Spread", "Filter Sweep"}

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
            _seeker.sampler_stage_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx, function(value)
                _seeker.sampler_stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage Volume Param
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_volume", "Stage Volume", controlspec.new(0, 1, "lin", 0.01, 1, ""))

            -- Scatter Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_amount", "Scatter Amount",
                controlspec.new(0, 100, "lin", 1, 10, "%"))

            -- Reverse Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_reverse_prob", "Reverse Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))

            -- Pan Spread Transform Params
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_prob", "Pan Probability",
                controlspec.new(0, 100, "lin", 1, 50, "%"))
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_range", "Pan Range",
                controlspec.new(0, 100, "lin", 1, 100, "%"))

            -- Filter Sweep Transform Params
            params:add_option("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_direction", "Filter Direction", {"Down", "Up"}, 1)
            params:add_control("lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_amount", "Filter Amount",
                controlspec.new(0, 100, "lin", 1, 25, "%"))
        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "SAMPLER_STAGE_CONFIG",
        name = "Sampler Stage Config",
        description = "Transform chop parameters across stages. Scatter randomizes start positions.",
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

        -- Get the current transform type
        local transform_type = params:string("lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx)

        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Settings" },
            { id = "lane_" .. lane_idx .. "_sampler_config_stage" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
            { id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_volume" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
            { separator = true, title = "Transform" },
            { id = "lane_" .. lane_idx .. "_sampler_transform_stage_" .. stage_idx },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif" }
        }

        -- Add transform-specific parameters
        if transform_type == "Scatter" then
            table.insert(param_table, { separator = true, title = "Scatter Config" })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_scatter_amount",
                arc_multi_float = {10, 5, 1}
            })
        elseif transform_type == "Reverse" then
            table.insert(param_table, { separator = true, title = "Reverse Config" })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_reverse_prob",
                arc_multi_float = {10, 5, 1}
            })
        elseif transform_type == "Pan Spread" then
            table.insert(param_table, { separator = true, title = "Pan Spread Config" })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_prob",
                arc_multi_float = {10, 5, 1}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_pan_range",
                arc_multi_float = {10, 5, 1}
            })
        elseif transform_type == "Filter Sweep" then
            table.insert(param_table, { separator = true, title = "Filter Sweep Config" })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_direction"
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_sampler_stage_" .. stage_idx .. "_filter_amount",
                arc_multi_float = {10, 5, 1}
            })
        end

        -- Update the UI with the new parameter table
        self.params = param_table
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "SAMPLER_STAGE_CONFIG",
        layout = {
            x = 4,
            y = 7,
            width = 1,
            height = 1
        }
    })

    -- Add blink state tracking
    grid_ui.blink_state = {
        blink_until = nil,
        stage_number = nil
    }

    -- Blink timing configuration
    grid_ui.blink_config = {
        on_duration = 0.1,
        off_duration = 0.1,
        inter_blink_pause = 0.1
    }

    -- Trigger blink from outside (called from lane loop starts)
    function grid_ui:trigger_stage_blink(stage_idx)
        local cycle_duration = self.blink_config.on_duration + self.blink_config.off_duration + self.blink_config.inter_blink_pause
        local total_duration = (stage_idx * cycle_duration) - self.blink_config.inter_blink_pause

        self.blink_state.blink_until = util.time() + total_duration
        self.blink_state.stage_number = stage_idx
        self.blink_state.start_time = util.time()
    end

    -- Draw method with blinking animation
    function grid_ui:draw(layers)
        local focused_lane_id = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

        -- Only draw in sampler mode
        if motif_type ~= SAMPLER_MODE then
            return
        end

        local x = self.layout.x
        local y = self.layout.y
        local brightness = GridConstants.BRIGHTNESS.LOW

        -- Check if we should blink
        if self.blink_state.blink_until and util.time() < self.blink_state.blink_until then
            local elapsed = util.time() - self.blink_state.start_time
            local stage_number = self.blink_state.stage_number or 1

            local blink_on_duration = self.blink_config.on_duration
            local blink_off_duration = self.blink_config.off_duration
            local inter_blink_pause = self.blink_config.inter_blink_pause
            local cycle_duration = blink_on_duration + blink_off_duration + inter_blink_pause

            local current_blink = math.floor(elapsed / cycle_duration) + 1

            if current_blink <= stage_number then
                local blink_position = elapsed % cycle_duration

                if blink_position < blink_on_duration then
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
            else
                brightness = GridConstants.BRIGHTNESS.LOW
            end
        else
            brightness = GridConstants.BRIGHTNESS.LOW
        end

        layers.ui[x][y] = brightness
    end

    -- Navigate to sampler stage config screen
    function grid_ui:handle_key(x, y, z)
        if z == 1 then
            local focused_lane_id = _seeker.ui_state.get_focused_lane()
            local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

            -- Only active in sampler mode
            if motif_type ~= SAMPLER_MODE then
                return
            end

            _seeker.ui_state.set_current_section("SAMPLER_STAGE_CONFIG")
        end
    end

    return grid_ui
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
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return SamplerStageConfig

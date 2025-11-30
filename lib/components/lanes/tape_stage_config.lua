-- tape_stage_config.lua
-- Configure tape mode stage transformations
-- Provides screen UI, grid button, and parameters for tape transform stages

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local tape_transforms = include("lib/motif_core/transforms")
local tape_transform = include("lib/components/lanes/stage_types/tape_transform")

local TapeStageConfig = {}
TapeStageConfig.__index = TapeStageConfig

-- Motif type constants
local TAPE_MODE = 1

-- Use tape transform UI names for transform selector
local transform_types = tape_transforms.ui_names

-- Local state for stage configuration
local config_state = {
    config_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_tape_transform_stage", "LANE " .. lane_idx .. " TAPE STAGE", 69)
        params:add_number("lane_" .. lane_idx .. "_tape_config_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_tape_config_stage", function(value)
            config_state.config_stage = value
            _seeker.tape_stage_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, "Transform", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, function(value)
                _seeker.tape_stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Stage Volume Param
            params:add_control("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume", "Stage Volume", controlspec.new(0, 1, "lin", 0.01, 1, ""))

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
        local stage_idx = config_state.config_stage

        -- Populate params using tape transform module
        tape_transform.populate_params(self, lane_idx, stage_idx)

        -- Sync the config stage param with local state
        params:set("lane_" .. lane_idx .. "_tape_config_stage", config_state.config_stage)

        original_enter(self)
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.config_stage

        -- Rebuild params using tape transform module
        tape_transform.rebuild_params(self, lane_idx, stage_idx)
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "TAPE_STAGE_CONFIG",
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

        -- Only draw in tape mode (arp_stage_config handles arpeggio mode)
        if motif_type ~= TAPE_MODE then
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

    -- Navigate to tape stage config screen
    function grid_ui:handle_key(x, y, z)
        if z == 1 then
            local focused_lane_id = _seeker.ui_state.get_focused_lane()
            local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

            -- Only active in tape mode
            if motif_type ~= TAPE_MODE then
                return
            end

            _seeker.ui_state.set_current_section("TAPE_STAGE_CONFIG")
        end
    end

    return grid_ui
end

function TapeStageConfig.enter(component)
    component.screen:enter()

    -- Initialize local config stage with current global focused stage
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    config_state.config_stage = current_global_stage

    -- Sync the config stage param with local state
    params:set("lane_" .. lane_idx .. "_tape_config_stage", config_state.config_stage)
end

function TapeStageConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return TapeStageConfig

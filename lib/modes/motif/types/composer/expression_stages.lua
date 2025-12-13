-- expression_stages.lua
-- Configure expression/performance parameters per stage
-- Creates all composer params (sequence structure + musical content per stage) and provides screen/grid UI
-- Part of lib/modes/motif/types/composer/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local composer_generator = include("lib/modes/motif/types/composer/generator")
local Descriptions = include("lib/ui/component_descriptions")

local ExpressionStages = {}
ExpressionStages.__index = ExpressionStages

-- Composer mode identifier value
local COMPOSER_MODE = 2

-- Module-level state tracks which stage is being edited (shared across UI components)
local editing_state = {
    selected_stage_index = 1
}

-- Create all composer parameters for a single lane
local function create_composer_params(lane_id)
    -- 58 params total: 2 lane-level (sequence structure) + (14 per stage x 4 stages)
    params:add_group("lane_" .. lane_id .. "_composer", "COMPOSER", 58)

    -- Lane-level params (sequence structure)
    params:add_number("lane_" .. lane_id .. "_composer_num_steps", "Number of Steps", 4, 24, 4)
    params:add_option("lane_" .. lane_id .. "_composer_step_length", "Step Length",
        {"1/32", "1/24", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "16", "24", "32"}, 14)

    -- Stage-level params (musical parameters per stage)
    for stage_idx = 1, 4 do
        -- Chord Definition
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_chord_root", "Root", {"I", "ii", "iii", "IV", "V", "vi", "vii°"}, 1)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_chord_type", "Type", {"Diatonic", "Major", "Minor", "Sus4", "Maj7", "Min7", "Dom7", "Dim", "Aug"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_chord_length", "Length", 1, 12, 4)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_chord_inversion", "Inversion", {"Root", "1st", "2nd"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_octave", "Octave", 1, 7, 3)

        -- Pattern
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_pattern", "Pattern", {"All", "Odds", "Evens", "Downbeats", "Upbeats", "Sparse"}, 1)

        -- Performance Parameters
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_note_duration", "Note Duration", 1, 300, 100, function(param) return param.value .. "%" end)

        -- Velocity Curve
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_velocity_curve", "Curve",
            {"Flat", "Crescendo", "Decrescendo", "Wave", "Alternating", "Accent First", "Accent Last", "Random"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_velocity_min", "Min", 1, 127, 60)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_velocity_max", "Max", 1, 127, 100)

        -- Strum Parameters
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_strum_amount", "Amount", 0, 100, 0, function(param) return param.value .. "%" end)
        params:add_binary("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_chord_phasing", "Chord Phasing", "toggle", 0)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_strum_curve", "Curve",
            {"None", "Linear", "Accelerating", "Decelerating", "Sweep"}, 1)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_strum_shape", "Shape",
            {"Forward", "Reverse", "Center Out", "Edges In", "Alternating", "Random"}, 1)
    end
end

local function create_params()
    -- Create composer params for all lanes
    for i = 1, _seeker.num_lanes do
        create_composer_params(i)
    end

    -- Create stage config params for all lanes
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_expression_stages", "LANE " .. lane_idx .. " EXPRESSION STAGE", 1)
        params:add_number("lane_" .. lane_idx .. "_expression_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_expression_stage", function(value)
            editing_state.selected_stage_index = value
            _seeker.composer.expression_stages.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "COMPOSER_EXPRESSION_STAGES",
        name = "Expression",
        description = Descriptions.COMPOSER_EXPRESSION_STAGES,
        params = {
            { separator = true, title = "Expression" },
        }
    })

    local original_enter = norns_ui.enter

    norns_ui.enter = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = editing_state.selected_stage_index

        -- Display current stage number to user
        self.name = "Stage " .. stage_idx .. " Expression"

        -- Populate params using composer generator module
        composer_generator.populate_params(self, lane_idx, stage_idx)

        -- Sync the stage param with local state
        params:set("lane_" .. lane_idx .. "_expression_stage", editing_state.selected_stage_index)

        original_enter(self)
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = editing_state.selected_stage_index

        -- Display current stage number to user
        self.name = "Stage " .. stage_idx .. " Expression"

        -- Rebuild params using composer generator module
        composer_generator.rebuild_params(self, lane_idx, stage_idx)
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "COMPOSER_EXPRESSION_STAGES",
        layout = {
            x = 1,
            y = 3,
            width = 4,
            height = 1
        }
    })

    -- Draw four stage buttons showing current stage
    grid_ui.draw = function(self, layers)
        local focused_lane_id = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

        -- Stage buttons only exist in composer mode
        if motif_type ~= COMPOSER_MODE then
            return
        end

        local focused_lane = _seeker.lanes[focused_lane_id]
        if not focused_lane then
            return
        end

        local current_stage_index = focused_lane.current_stage_index or 1
        local is_stage_config_section = (_seeker.ui_state.get_current_section() == "COMPOSER_EXPRESSION_STAGES")
        local selected_stage = editing_state.selected_stage_index

        for i = 0, self.layout.width - 1 do
            local x = self.layout.x + i
            local stage_num = i + 1
            local is_playing_stage = (stage_num == current_stage_index)
            local is_selected_stage = (stage_num == selected_stage)
            local brightness = GridConstants.BRIGHTNESS.LOW

            if is_stage_config_section then
                -- Show playing stage at full brightness, selected stage at medium brightness
                if is_playing_stage then
                    brightness = GridConstants.BRIGHTNESS.HIGH
                elseif is_selected_stage then
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
            else
                -- Outside stage config, show current playing stage
                if is_playing_stage then
                    brightness = GridConstants.BRIGHTNESS.HIGH
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
            end

            layers.ui[x][self.layout.y] = brightness
        end
    end

    -- Navigate to specific stage config
    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            local focused_lane_id = _seeker.ui_state.get_focused_lane()
            local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

            -- Only active in composer mode
            if motif_type ~= COMPOSER_MODE then
                return
            end

            local stage_index = (x - self.layout.x) + 1

            -- Set stage and navigate to section
            params:set("lane_" .. focused_lane_id .. "_expression_stage", stage_index)
            _seeker.ui_state.set_current_section("COMPOSER_EXPRESSION_STAGES")
        end
    end

    return grid_ui
end

function ExpressionStages.enter(component)
    component.screen:enter()

    -- Sync local editing state with global focused stage
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    editing_state.selected_stage_index = current_global_stage

    -- Sync the stage param with local state
    params:set("lane_" .. lane_idx .. "_expression_stage", editing_state.selected_stage_index)
end

function ExpressionStages.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return ExpressionStages

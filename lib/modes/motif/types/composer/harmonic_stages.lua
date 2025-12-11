-- harmonic_stages.lua
-- Configure chord progression per stage (harmonic/melodic content only)
-- Owns chord parameters and provides screen/grid UI
-- Part of lib/modes/motif/types/composer/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local HarmonicStages = {}
HarmonicStages.__index = HarmonicStages

-- Composer mode identifier value
local COMPOSER_MODE = 2

-- Module-level state tracks which stage is being edited
local editing_state = {
    selected_stage_index = 1
}

-- Create stage selection param for each lane
local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_harmonic_stages", "LANE " .. lane_idx .. " CHORD STAGE", 1)
        params:add_number("lane_" .. lane_idx .. "_harmonic_stage", "Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_harmonic_stage", function(value)
            editing_state.selected_stage_index = value
            _seeker.composer.harmonic_stages.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "COMPOSER_HARMONIC_STAGES",
        name = "Harmonic",
        description = "Configure pitch and harmonic content for each stage.",
        params = {
            { separator = true, title = "Harmonic" },
        }
    })

    local original_enter = norns_ui.enter

    norns_ui.enter = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = editing_state.selected_stage_index

        -- Update name to show current stage in footer
        self.name = "Stage " .. stage_idx .. " Harmonic"

        -- Populate harmonic params and stage controls for this stage
        self.params = {
            { separator = true, title = "Chord Base" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_root" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_type" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_length" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_inversion" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_octave" },
            { separator = true, title = "Stage Control" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
        }

        original_enter(self)
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = editing_state.selected_stage_index

        -- Update name to show current stage in footer
        self.name = "Stage " .. stage_idx .. " Harmonic"

        -- Rebuild harmonic params and stage controls for this stage
        self.params = {
            { separator = true, title = "Chord Definition" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_root" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_type" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_length" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_chord_inversion" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_composer_octave" },
            { separator = true, title = "Control" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_active" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_volume" },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_loops" },
        }
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "COMPOSER_HARMONIC_STAGES",
        layout = {
            x = 1,
            y = 2,
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
        local is_harmonic_section = (_seeker.ui_state.get_current_section() == "COMPOSER_HARMONIC_STAGES")
        local selected_stage = editing_state.selected_stage_index

        for i = 0, self.layout.width - 1 do
            local x = self.layout.x + i
            local stage_num = i + 1
            local is_playing_stage = (stage_num == current_stage_index)
            local is_selected_stage = (stage_num == selected_stage)
            local brightness = GridConstants.BRIGHTNESS.LOW

            if is_harmonic_section then
                -- Show playing stage at full brightness, selected stage at medium brightness
                if is_playing_stage then
                    brightness = GridConstants.BRIGHTNESS.HIGH
                elseif is_selected_stage then
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
            else
                -- Outside chord config, show current playing stage
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
            params:set("lane_" .. focused_lane_id .. "_harmonic_stage", stage_index)
            _seeker.ui_state.set_current_section("COMPOSER_HARMONIC_STAGES")
        end
    end

    return grid_ui
end

function HarmonicStages.enter(component)
    component.screen:enter()

    -- Sync local editing state with global focused stage
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    editing_state.selected_stage_index = current_global_stage
end

function HarmonicStages.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return HarmonicStages

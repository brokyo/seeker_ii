-- create.lua
-- Composer type: motif creation control
-- Generates motif from parameters on long press (instant, not recording)
-- Part of lib/modes/motif/types/composer/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local composer_generator = include("lib/modes/motif/types/composer/generator")
local Descriptions = include("lib/ui/component_descriptions")

local ComposerCreate = {}
ComposerCreate.__index = ComposerCreate

-- Configures sequence structure, performance, and harmonic parameters for all stages
local function apply_expression_preset(lane_id, preset_name)
    local presets = {
        Clockwork = {
            num_steps = 8,
            step_length = 12, -- 1/4
            pattern = 1, -- All
            note_duration = 100,
            velocity_curve = 1, -- Flat
            velocity_min = 90,
            velocity_max = 90,
            strum_amount = 0,
            chord_phasing = 0,
            strum_curve = 1, -- None
            strum_shape = 1, -- Forward
            chord_type = 1, -- Diatonic
            chord_length = 4,
            voice_rotation = 0,
            voicing_style = 1, -- Close
            octave = 2
        },
        Breath = {
            num_steps = 8,
            step_length = 15, -- 1 beat
            pattern = 1, -- All
            note_duration = 150,
            velocity_curve = 4, -- Wave
            velocity_min = 50,
            velocity_max = 100,
            strum_amount = 30,
            chord_phasing = 1,
            strum_curve = 5, -- Sweep
            strum_shape = 1, -- Forward
            chord_type = 5, -- Maj7
            chord_length = 4,
            voice_rotation = 0,
            voicing_style = 2, -- Open
            octave = 3
        },
        Whisper = {
            num_steps = 8,
            step_length = 15, -- 1 beat
            pattern = 1, -- All
            note_duration = 200,
            velocity_curve = 8, -- Random
            velocity_min = 40,
            velocity_max = 70,
            strum_amount = 60,
            chord_phasing = 1,
            strum_curve = 5, -- Sweep
            strum_shape = 5, -- Alternating
            chord_type = 4, -- Sus4
            chord_length = 3,
            voice_rotation = 0,
            voicing_style = 5, -- Spread
            octave = 3
        },
        Shimmer = {
            num_steps = 16,
            step_length = 14, -- 1/2 beat
            pattern = 1, -- All
            note_duration = 250,
            velocity_curve = 4, -- Wave
            velocity_min = 60,
            velocity_max = 90,
            strum_amount = 45,
            chord_phasing = 1,
            strum_curve = 5, -- Sweep
            strum_shape = 3, -- Center Out
            chord_type = 5, -- Maj7
            chord_length = 5,
            voice_rotation = 1,
            voicing_style = 8, -- Scatter
            octave = 3
        },
        Cascade = {
            num_steps = 8,
            step_length = 12, -- 1/4
            pattern = 1, -- All
            note_duration = 80,
            velocity_curve = 3, -- Decrescendo
            velocity_min = 60,
            velocity_max = 100,
            strum_amount = 70,
            chord_phasing = 0,
            strum_curve = 3, -- Accelerating
            strum_shape = 2, -- Reverse
            chord_type = 1, -- Diatonic
            chord_length = 5,
            voice_rotation = 0,
            voicing_style = 7, -- Falling
            octave = 3
        },
        Glass = {
            num_steps = 12,
            step_length = 12, -- 1/4
            pattern = 6, -- Sparse
            note_duration = 60,
            velocity_curve = 3, -- Decrescendo
            velocity_min = 40,
            velocity_max = 80,
            strum_amount = 25,
            chord_phasing = 1,
            strum_curve = 5, -- Sweep
            strum_shape = 3, -- Center Out
            chord_type = 5, -- Maj7
            chord_length = 4,
            voice_rotation = 0,
            voicing_style = 8, -- Scatter
            octave = 4
        },
        Swarm = {
            num_steps = 16,
            step_length = 8, -- 1/8
            pattern = 1, -- All
            note_duration = 50,
            velocity_curve = 8, -- Random
            velocity_min = 50,
            velocity_max = 100,
            strum_amount = 80,
            chord_phasing = 1,
            strum_curve = 2, -- Linear
            strum_shape = 6, -- Random
            chord_type = 6, -- Min7
            chord_length = 6,
            voice_rotation = 2,
            voicing_style = 8, -- Scatter
            octave = 2
        },
        Pluck = {
            num_steps = 6,
            step_length = 14, -- 1/2 beat
            pattern = 1, -- All
            note_duration = 40,
            velocity_curve = 6, -- Accent First
            velocity_min = 70,
            velocity_max = 100,
            strum_amount = 0,
            chord_phasing = 0,
            strum_curve = 1, -- None
            strum_shape = 1, -- Forward
            chord_type = 1, -- Diatonic
            chord_length = 4,
            voice_rotation = 0,
            voicing_style = 3, -- Drop 2
            octave = 3
        }
    }

    local preset = presets[preset_name]
    if preset then
        -- Apply structure params (lane-level)
        if preset.num_steps then
            params:set("lane_" .. lane_id .. "_composer_num_steps", preset.num_steps)
        end
        if preset.step_length then
            params:set("lane_" .. lane_id .. "_composer_step_length", preset.step_length)
        end

        -- Apply performance params to all 4 stages
        for stage_idx = 1, 4 do
            for param_name, value in pairs(preset) do
                -- Skip structure params (already set above)
                if param_name ~= "num_steps" and param_name ~= "step_length" then
                    params:set("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_composer_" .. param_name, value)
                end
            end
        end
    end
end

local function create_params()
    params:add_group("composer_create_group", "COMPOSER CREATE", 1)

    -- Expression preset selector for composer mode
    params:add_option("composer_create_expression_preset", "Preset",
        {"Clockwork", "Breath", "Whisper", "Shimmer", "Cascade", "Glass", "Swarm", "Pluck", "Custom"}, 1)
    params:set_action("composer_create_expression_preset", function(value)
        local preset_names = {"Clockwork", "Breath", "Whisper", "Shimmer", "Cascade", "Glass", "Swarm", "Pluck", "Custom"}
        local preset_name = preset_names[value]

        -- Custom preset is display-only, no parameter changes needed
        if preset_name ~= "Custom" then
            local focused_lane = _seeker.ui_state.get_focused_lane()
            apply_expression_preset(focused_lane, preset_name)

            -- Trigger screen redraw to show updated values
            if _seeker.screen_ui then
                _seeker.screen_ui.set_needs_redraw()
            end
        end
    end)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "COMPOSER_CREATE",
        name = "Create",
        description = Descriptions.COMPOSER_CREATE,
        params = {}
    })

    -- Dynamic parameter rebuilding based on focused lane
    norns_ui.rebuild_params = function(self)
        local focused_lane = _seeker.ui_state.get_focused_lane()

        self.params = {
            { separator = true, title = "Expression" },
            { id = "composer_create_expression_preset" },
            { separator = true, title = "Sequence Structure" },
            { id = "lane_" .. focused_lane .. "_composer_num_steps" },
            { id = "lane_" .. focused_lane .. "_composer_step_length" }
        }
    end

    -- Rebuild parameter list when entering the screen
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    -- Override draw to add help text
    norns_ui.draw_default = function(self)
        screen.clear()

        -- Check if showing description
        if self.state.showing_description then
            NornsUI.draw_default(self)
            return
        end

        -- Render help text in background layer beneath parameter display
        local help_text = "generate: hold"
        local width = screen.text_extents(help_text)

        -- Brighten text during long press
        if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "COMPOSER_CREATE" then
            screen.level(15)
        else
            screen.level(2)
        end

        screen.move(64 - width/2, 46)
        screen.text(help_text)

        -- Draw parameters on top of help text
        self:_draw_standard_ui()

        -- Draw footer
        self:draw_footer()

        screen.update()
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "COMPOSER_CREATE",
        layout = {
            x = 2,
            y = 7,
            width = 1,
            height = 1
        }
    })

    -- Override draw
    grid_ui.draw = function(self, layers)
        local x = self.layout.x
        local y = self.layout.y
        local brightness = (_seeker.ui_state.get_current_section() == "COMPOSER_CREATE") and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL

        -- Draw keyboard outline during long press
        if self:is_holding_long_press() then
            self:draw_keyboard_outline_highlight(layers)
        end

        layers.ui[x][y] = brightness
    end

    -- Helper function to generate motif from parameters
    local function handle_composer_generate()
        local focused_lane_idx = _seeker.ui_state.get_focused_lane()
        local current_lane = _seeker.lanes[focused_lane_idx]

        -- Always clear the current motif (no overdubbing in composer mode)
        current_lane:clear()

        -- Update parameter visibility based on motif state
        if _seeker.composer and _seeker.composer.create and _seeker.composer.create.screen then
            _seeker.composer.create.screen:rebuild_params()
        end

        -- Generate composer sequence from current step pattern using Stage 1 parameters
        local composer_motif = composer_generator.generate_motif(focused_lane_idx, 1)

        if composer_motif and composer_motif.events and #composer_motif.events > 0 then
            -- Set the motif and start playback
            current_lane:set_motif(composer_motif)
            current_lane:play()
        end

        -- Update parameter visibility based on motif state
        if _seeker.composer and _seeker.composer.create and _seeker.composer.create.screen then
            _seeker.composer.create.screen:rebuild_params()
        end

        _seeker.screen_ui.set_needs_redraw()
    end

    -- Override handle_key
    grid_ui.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then -- Key pressed
            self:key_down(key_id)
            _seeker.ui_state.set_current_section("COMPOSER_CREATE")
            _seeker.ui_state.set_long_press_state(true, "COMPOSER_CREATE")
            _seeker.screen_ui.set_needs_redraw()
        else -- Key released
            -- If it was a long press, generate the motif
            if self:is_long_press(key_id) then
                handle_composer_generate()
            end

            -- Always clear long press state on release
            _seeker.ui_state.set_long_press_state(false, nil)
            _seeker.screen_ui.set_needs_redraw()

            self:key_release(key_id)
        end
    end

    return grid_ui
end

function ComposerCreate.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return ComposerCreate

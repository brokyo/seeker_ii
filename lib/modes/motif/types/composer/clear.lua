-- clear.lua
-- Composer type: clear motif control
-- Long press to clear the current lane's motif
-- Part of lib/modes/motif/types/composer/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local ComposerClear = {}
ComposerClear.__index = ComposerClear

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "COMPOSER_CLEAR",
        name = "Clear",
        description = Descriptions.COMPOSER_CLEAR,
        params = {
            { separator = true, title = "Clear Motif" }
        }
    })

    norns_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        if not self.state.showing_description then
            local tooltip
            local focused_lane = _seeker.ui_state.get_focused_lane()
            local lane = _seeker.lanes[focused_lane]

            if lane and lane.motif and #lane.motif.events > 0 then
                tooltip = "clear: hold"
            else
                tooltip = "no motif to clear"
            end

            local width = screen.text_extents(tooltip)

            if _seeker.ui_state.is_long_press_active() and _seeker.ui_state.get_long_press_section() == "COMPOSER_CLEAR" then
                screen.level(15)
            else
                screen.level(2)
            end

            screen.move(64 - width/2, 46)
            screen.text(tooltip)
        end

        screen.update()
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "COMPOSER_CLEAR",
        layout = {
            x = 3,
            y = 7,
            width = 1,
            height = 1
        },
        long_press_threshold = 1.5  -- Longer threshold to prevent accidental clearing
    })

    -- Track button state for animation
    local button_pressed = false
    local button_press_time = nil

    -- Store original draw method
    local original_grid_draw = grid_ui.draw

    -- Draw visual feedback animation during button press
    grid_ui.draw = function(self, layers)
        -- Call original draw method
        original_grid_draw(self, layers)

        -- Draw visual indicator when button is pressed
        if button_pressed and button_press_time then
            local press_duration = util.time() - button_press_time
            local threshold_reached = press_duration >= self.long_press_threshold

            -- Determine keyboard brightness
            local keyboard_brightness
            if threshold_reached then
                -- Calculate time since threshold was reached
                local time_since_threshold = press_duration - self.long_press_threshold
                local pulse_rate = 4
                local pulse_duration = 1 / pulse_rate
                local pulses_completed = time_since_threshold / pulse_duration

                if pulses_completed < 3 then
                    -- Pulse 3 times to indicate ready to execute
                    local phase = (clock.get_beats() * pulse_rate) % 1
                    local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
                    keyboard_brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
                else
                    -- After 3 pulses, hold at full brightness
                    keyboard_brightness = GridConstants.BRIGHTNESS.FULL
                end
            else
                -- Lower illumination while holding (before threshold)
                keyboard_brightness = GridConstants.BRIGHTNESS.MEDIUM
            end

            -- Illuminate composer keyboard area
            local keyboard = {
                x = 6,
                y = 1,
                width = 6,
                height = 8
            }

            for x = keyboard.x, keyboard.x + keyboard.width - 1 do
                for y = keyboard.y, keyboard.y + keyboard.height - 1 do
                    layers.response[x][y] = keyboard_brightness
                end
            end
        end
    end

    -- Override handle_key to implement clearing functionality
    grid_ui.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then -- Key pressed
            self:key_down(key_id)
            button_pressed = true
            button_press_time = util.time()
            _seeker.ui_state.set_current_section("COMPOSER_CLEAR")
            _seeker.ui_state.set_long_press_state(true, "COMPOSER_CLEAR")
            _seeker.screen_ui.set_needs_redraw()
        else -- Key released
            button_pressed = false
            button_press_time = nil

            -- If it was a long press, clear the motif
            if self:is_long_press(key_id) then
                local focused_lane = _seeker.ui_state.get_focused_lane()
                local lane = _seeker.lanes[focused_lane]

                if lane and lane.motif and #lane.motif.events > 0 then
                    lane:clear()

                    -- Update create screen parameter visibility based on motif state
                    if _seeker.composer and _seeker.composer.create and _seeker.composer.create.screen then
                        _seeker.composer.create.screen:rebuild_params()
                    end
                end

                _seeker.screen_ui.set_needs_redraw()
            end

            -- Clear long press state on release
            _seeker.ui_state.set_long_press_state(false, nil)
            _seeker.screen_ui.set_needs_redraw()

            self:key_release(key_id)
        end
    end

    return grid_ui
end

function ComposerClear.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return ComposerClear

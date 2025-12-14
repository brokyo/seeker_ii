-- wtape_frippertronics.lua
-- Frippertronics: tape delay with layering and decay
-- Hold: start capture
-- Tap: close loop
-- From looped: tap stop, hold new capture

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeFrippertronics = {}
WTapeFrippertronics.__index = WTapeFrippertronics

-- Capture states
local STATE = {
    IDLE = "idle",
    CAPTURING = "capturing",
    LOOPED = "looped"
}

-- Module state
local capture_state = STATE.IDLE
local capture_start_time = nil
local capture_redraw_clock = nil

local function get_capture_state()
    return capture_state
end

-- Stop the redraw clock if running
local function stop_redraw_clock()
    if capture_redraw_clock then
        clock.cancel(capture_redraw_clock)
        capture_redraw_clock = nil
    end
end

-- Start a clock that redraws the screen while capturing
local function start_redraw_clock()
    stop_redraw_clock()
    capture_redraw_clock = clock.run(function()
        while capture_state == STATE.CAPTURING do
            if _seeker.screen_ui then
                _seeker.screen_ui.set_needs_redraw()
            end
            if _seeker.grid_ui then
                _seeker.grid_ui.redraw()
            end
            clock.sleep(0.1)
        end
    end)
end

local function set_capture_state(state)
    capture_state = state

    -- Start/stop redraw clock based on state
    if state == STATE.CAPTURING then
        start_redraw_clock()
    else
        stop_redraw_clock()
    end

    if _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
    end
    if _seeker.grid_ui then
        _seeker.grid_ui.redraw()
    end
end

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_FRIPPERTRONICS",
        name = "Frippertronics",
        description = Descriptions.WTAPE_FRIPPERTRONICS,
        params = {
            { separator = true, title = "Frippertronics" }
        }
    })

    screen_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        if not self.state.showing_description then
            local status_text
            local hint_text
            local brightness

            if capture_state == STATE.IDLE then
                status_text = "hold to begin"
                hint_text = nil
                brightness = 2
            elseif capture_state == STATE.CAPTURING then
                local elapsed = util.time() - (capture_start_time or util.time())
                status_text = string.format("%.1fs", elapsed)
                hint_text = "tap to close loop"
                brightness = 15
            elseif capture_state == STATE.LOOPED then
                local is_recording = params:get("wtape_toggle_recording") == 1
                status_text = is_recording and "LAYERING" or "DECAYING"
                hint_text = "tap stop / hold new"
                brightness = 15
            end

            local width = screen.text_extents(status_text)
            screen.level(brightness)
            screen.move(64 - width/2, 38)
            screen.text(status_text)

            if hint_text then
                local hint_width = screen.text_extents(hint_text)
                screen.level(4)
                screen.move(64 - hint_width/2, 48)
                screen.text(hint_text)
            end
        end

        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_FRIPPERTRONICS",
        layout = {
            x = 15,
            y = 6,
            width = 1,
            height = 1
        },
        long_press_threshold = 0.3
    })

    grid_ui.draw = function(self, layers)
        local brightness

        if capture_state == STATE.CAPTURING then
            -- Pulse while capturing
            local phase = (clock.get_beats() * 2) % 1
            local pulse = math.sin(phase * math.pi * 2) * 0.5 + 0.5
            brightness = math.floor(GridConstants.BRIGHTNESS.MEDIUM + pulse * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.MEDIUM))
        elseif capture_state == STATE.LOOPED then
            brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
        else
            brightness = GridConstants.BRIGHTNESS.UI.NORMAL
        end

        layers.ui[self.layout.x][self.layout.y] = brightness

        -- Show hold indicator while button is pressed or release animating
        if self:is_any_key_held() or self:is_release_animating() then
            self:draw_hold_indicator(layers)
        end
    end

    grid_ui.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then
            self:key_down(key_id)
            _seeker.ui_state.set_current_section("WTAPE_FRIPPERTRONICS")
        else
            local was_long_press = self:is_long_press(key_id)
            self:key_release(key_id)

            if capture_state == STATE.IDLE then
                -- Hold to start capture
                if was_long_press then
                    capture_start_time = util.time()

                    -- Start playback first (tape must be moving)
                    if params:get("wtape_toggle_playing") == 0 then
                        params:set("wtape_toggle_playing", 1)
                    end

                    -- Arm recording
                    if params:get("wtape_toggle_recording") == 0 then
                        params:set("wtape_toggle_recording", 1)
                    end

                    -- Mark loop start while tape is running
                    crow.ii.wtape.loop_start()

                    set_capture_state(STATE.CAPTURING)
                    _seeker.ui_state.trigger_activated("wtape_frippertronics_start")
                end

            elseif capture_state == STATE.CAPTURING then
                -- Tap to close loop
                if not was_long_press then
                    crow.ii.wtape.loop_end()
                    crow.ii.wtape.loop_active(1)
                    crow.ii.wtape.play(1)
                    params:set("wtape_loop_mode", 1, true)

                    set_capture_state(STATE.LOOPED)
                    _seeker.ui_state.trigger_activated("wtape_frippertronics_end")
                end

            elseif capture_state == STATE.LOOPED then
                if was_long_press then
                    -- Long press: start new capture
                    crow.ii.wtape.loop_active(0)
                    params:set("wtape_loop_mode", 0, true)

                    if params:get("wtape_toggle_playing") == 0 then
                        params:set("wtape_toggle_playing", 1)
                    end

                    if params:get("wtape_toggle_recording") == 0 then
                        params:set("wtape_toggle_recording", 1)
                    end

                    crow.ii.wtape.loop_start()
                    capture_start_time = util.time()

                    set_capture_state(STATE.CAPTURING)
                    _seeker.ui_state.trigger_activated("wtape_capture_start")
                else
                    -- Short press: stop and return to idle
                    crow.ii.wtape.loop_active(0)
                    params:set("wtape_loop_mode", 0, true)
                    set_capture_state(STATE.IDLE)
                    capture_start_time = nil
                end
            end
        end
    end

    return grid_ui
end

function WTapeFrippertronics.init()
    -- Reset state on init
    capture_state = STATE.IDLE
    capture_start_time = nil

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

-- Expose state getter for other components
WTapeFrippertronics.get_state = get_capture_state
WTapeFrippertronics.STATE = STATE

return WTapeFrippertronics

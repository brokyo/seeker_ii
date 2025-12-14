-- wtape_rewind.lua
-- Grid button and screen display for WTape rewind

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeRewind = {}
WTapeRewind.__index = WTapeRewind

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_REWIND",
        name = "Rewind",
        description = Descriptions.WTAPE_REWIND,
        params = {
            { separator = true, title = "Rewind" },
            { id = "wtape_rewind_time", arc_multi_float = {10, 1, 0.1} }
        }
    })

    screen_ui.draw_default = function(self)
        if self.state.showing_description then
            NornsUI.draw_default(self)
            return
        end

        screen.clear()
        self:draw_params(0)

        local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_rewind")
        if recently_triggered then
            local time = params:get("wtape_rewind_time")
            local status_text = string.format("<< %.1fs", time)

            local width = screen.text_extents(status_text)
            screen.level(15)
            screen.move(64 - width/2, 46)
            screen.text(status_text)
        end

        self:draw_footer()
        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_REWIND",
        layout = {
            x = 13,
            y = 7,
            width = 1,
            height = 1
        },
        long_press_threshold = 0.3
    })

    grid_ui.draw = function(self, layers)
        local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_rewind")
        local brightness = recently_triggered and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
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
            _seeker.ui_state.set_current_section("WTAPE_REWIND")
        else
            local was_long_press = self:is_long_press(key_id)
            self:key_release(key_id)

            if was_long_press then
                params:set("wtape_rewind", 1)
            end
        end
    end

    return grid_ui
end

function WTapeRewind.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeRewind

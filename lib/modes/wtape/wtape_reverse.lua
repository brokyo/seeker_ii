-- wtape_reverse.lua
-- Grid button and screen display for reversing WTape direction

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeReverse = {}
WTapeReverse.__index = WTapeReverse

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_REVERSE",
        name = "Reverse",
        description = Descriptions.WTAPE_REVERSE,
        params = {
            { separator = true, title = "Direction" }
        }
    })

    screen_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        if not self.state.showing_description then
            local is_forward = _seeker.wtape.direction == 1
            local status_text = is_forward and "FORWARD" or "REVERSE"

            local width = screen.text_extents(status_text)
            screen.level(15)
            screen.move(64 - width/2, 46)
            screen.text(status_text)
        end

        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_REVERSE",
        layout = {
            x = 13,
            y = 6,
            width = 1,
            height = 1
        },
        long_press_threshold = 0.3
    })

    grid_ui.draw = function(self, layers)
        local is_reverse = _seeker.wtape.direction == -1
        local brightness = is_reverse and
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
            _seeker.ui_state.set_current_section("WTAPE_REVERSE")
        else
            local was_long_press = self:is_long_press(key_id)
            self:key_release(key_id)

            if was_long_press then
                params:set("wtape_reverse", 1)
            end
        end
    end

    return grid_ui
end

function WTapeReverse.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeReverse

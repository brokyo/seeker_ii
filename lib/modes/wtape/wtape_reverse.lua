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
        params = {}
    })

    screen_ui.draw_default = function(self)
        if self.state.showing_description then
            NornsUI.draw_default(self)
            return
        end

        screen.clear()

        local is_forward = _seeker.wtape.direction == 1
        local status_text = is_forward and "FWD" or "REV"

        screen.font_size(16)
        screen.level(15)
        local text_width = screen.text_extents(status_text)
        screen.move((128 - text_width) / 2, 30)
        screen.text(status_text)

        screen.font_size(8)
        self:draw_footer()
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
        }
    })

    grid_ui.draw = function(self, layers)
        local is_reverse = _seeker.wtape.direction == -1
        local brightness = is_reverse and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_reverse", 1)
            _seeker.ui_state.set_current_section("WTAPE_REVERSE")
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

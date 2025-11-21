-- wtape_rewind.lua
-- Grid button and screen display for WTape rewind

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local WTapeRewind = {}
WTapeRewind.__index = WTapeRewind

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_REWIND",
        name = "Rewind",
        params = {}
    })

    screen_ui.draw = function(self)
        screen.clear()

        local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_rewind")
        local status_text = recently_triggered and "<< 10s" or "RWD"

        screen.font_size(16)
        screen.level(15)
        local text_width = screen.text_extents(status_text)
        screen.move((128 - text_width) / 2, 30)
        screen.text(status_text)

        screen.font_size(8)
        screen.level(8)
        screen.rect(0, 52, 128, 12)
        screen.fill()
        screen.level(0)
        screen.move(2, 60)
        screen.text("Rewind")

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
        }
    })

    grid_ui.draw = function(self, layers)
        local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_rewind")
        local brightness = recently_triggered and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_rewind", 1)
            _seeker.ui_state.set_current_section("WTAPE_REWIND")
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

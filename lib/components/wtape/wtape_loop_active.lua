-- wtape_loop_active.lua
-- Grid button and screen display for toggling WTape loop activation

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local WTapeLoopActive = {}
WTapeLoopActive.__index = WTapeLoopActive

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_LOOP_ACTIVE",
        name = "Loop Active",
        params = {}
    })

    screen_ui.draw = function(self)
        screen.clear()

        local is_active = params:get("wtape_loop_mode") == 1
        local status_text = is_active and "LOOP ON" or "LOOP OFF"

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
        screen.text("Loop Active")

        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_LOOP_ACTIVE",
        layout = {
            x = 14,
            y = 6,
            width = 1,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local brightness = params:get("wtape_loop_mode") == 1 and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_loop_mode", 1 - params:get("wtape_loop_mode"))
            _seeker.ui_state.set_current_section("WTAPE_LOOP_ACTIVE")
        end
    end

    return grid_ui
end

function WTapeLoopActive.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeLoopActive

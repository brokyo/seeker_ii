-- wtape_loop_end.lua
-- Grid button and screen display for setting WTape loop end point

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeLoopEnd = {}
WTapeLoopEnd.__index = WTapeLoopEnd

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_LOOP_END",
        name = "Loop End",
        description = Descriptions.WTAPE_LOOP_END,
        params = {
            { separator = true, title = "Set Loop End" }
        }
    })

    screen_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        if not self.state.showing_description then
            local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_loop_end")
            local status_text = recently_triggered and "SET" or "press grid to set"

            local width = screen.text_extents(status_text)
            screen.level(recently_triggered and 15 or 2)
            screen.move(64 - width/2, 46)
            screen.text(status_text)
        end

        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_LOOP_END",
        layout = {
            x = 16,
            y = 6,
            width = 1,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local recently_triggered = _seeker.ui_state.is_recently_triggered("wtape_loop_end")
        local brightness = recently_triggered and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_loop_end", 1)
            _seeker.ui_state.set_current_section("WTAPE_LOOP_END")
        end
    end

    return grid_ui
end

function WTapeLoopEnd.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeLoopEnd

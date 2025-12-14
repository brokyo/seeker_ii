-- wtape_loop_active.lua
-- Grid button and screen display for toggling WTape loop activation

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeLoopActive = {}
WTapeLoopActive.__index = WTapeLoopActive

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_LOOP_ACTIVE",
        name = "Loop Active",
        description = Descriptions.WTAPE_LOOP_ACTIVE,
        params = {
            { separator = true, title = "Loop Mode" }
        }
    })

    screen_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        if not self.state.showing_description then
            local is_active = params:get("wtape_loop_mode") == 1
            local status_text = is_active and "LOOP ON" or "LOOP OFF"

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
        id = "WTAPE_LOOP_ACTIVE",
        layout = {
            x = 14,
            y = 6,
            width = 1,
            height = 1
        },
        long_press_threshold = 0.3
    })

    grid_ui.draw = function(self, layers)
        local brightness = params:get("wtape_loop_mode") == 1 and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness

        if self:is_any_key_held() or self:is_release_animating() then
            self:draw_hold_indicator(layers)
        end
    end

    grid_ui.handle_key = function(self, x, y, z)
        local key_id = string.format("%d,%d", x, y)

        if z == 1 then
            self:key_down(key_id)
            _seeker.ui_state.set_current_section("WTAPE_LOOP_ACTIVE")
        else
            local was_long_press = self:is_long_press(key_id)
            self:key_release(key_id)

            if was_long_press then
                params:set("wtape_loop_mode", 1 - params:get("wtape_loop_mode"))
            end
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

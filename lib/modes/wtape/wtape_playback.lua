-- wtape_playback.lua
-- Grid button and screen display for toggling WTape playback

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapePlayback = {}
WTapePlayback.__index = WTapePlayback

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_PLAYBACK",
        name = "Play",
        description = Descriptions.WTAPE_PLAYBACK,
        params = {
            { separator = true, title = "Playback" },
            { id = "wtape_speed", arc_multi_float = {0.5, 0.1, 0.01} }
        }
    })

    -- Display playback status below parameters
    screen_ui.draw_default = function(self)
        if self.state.showing_description then
            NornsUI.draw_default(self)
            return
        end

        screen.clear()
        self:draw_params(0)

        local is_playing = params:get("wtape_toggle_playing") == 1
        local status_text = is_playing and "> PLAYING" or "[] STOPPED"

        local width = screen.text_extents(status_text)
        screen.level(is_playing and 15 or 6)
        screen.move(64 - width/2, 46)
        screen.text(status_text)

        self:draw_footer()
        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_PLAYBACK",
        layout = {
            x = 16,
            y = 7,
            width = 1,
            height = 1
        },
        long_press_threshold = 0.3
    })

    grid_ui.draw = function(self, layers)
        local brightness = params:get("wtape_toggle_playing") == 1 and
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
            _seeker.ui_state.set_current_section("WTAPE_PLAYBACK")
        else
            local was_long_press = self:is_long_press(key_id)
            self:key_release(key_id)

            if was_long_press then
                params:set("wtape_toggle_playing", 1 - params:get("wtape_toggle_playing"))
            end
        end
    end

    return grid_ui
end

function WTapePlayback.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapePlayback

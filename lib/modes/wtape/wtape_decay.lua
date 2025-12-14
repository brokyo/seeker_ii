-- wtape_decay.lua
-- Dedicated screen for Decay param - the key performable Frippertronics control

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeDecay = {}
WTapeDecay.__index = WTapeDecay

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_DECAY",
        name = "Decay",
        description = Descriptions.WTAPE_DECAY,
        params = {
            { separator = true, title = "Decay" },
            { id = "wtape_erase_strength", arc_multi_float = {0.1, 0.01, 0.001} }
        }
    })

    screen_ui.draw_default = function(self)
        if self.state.showing_description then
            NornsUI.draw_default(self)
            return
        end

        screen.clear()
        self:draw_params(0)

        -- Show decay character hint
        local decay = params:get("wtape_erase_strength")
        local hint
        if decay < 0.1 then
            hint = "full overdub"
        elseif decay < 0.5 then
            hint = "frippertronics"
        elseif decay < 0.9 then
            hint = "fast fade"
        else
            hint = "full replace"
        end

        local width = screen.text_extents(hint)
        screen.level(4)
        screen.move(64 - width/2, 46)
        screen.text(hint)

        self:draw_footer()
        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_DECAY",
        layout = {
            x = 16,
            y = 6,
            width = 1,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        -- Brightness reflects decay amount (brighter = more decay/faster fade)
        local decay = params:get("wtape_erase_strength")
        local brightness = math.floor(GridConstants.BRIGHTNESS.LOW + decay * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            _seeker.ui_state.set_current_section("WTAPE_DECAY")
        end
    end

    return grid_ui
end

function WTapeDecay.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeDecay

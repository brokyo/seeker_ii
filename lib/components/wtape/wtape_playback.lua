-- wtape_playback.lua
-- Grid button component for toggling WTape playback

local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local WTapePlayback = {}
WTapePlayback.__index = WTapePlayback

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_PLAYBACK",
        layout = {
            x = 16,
            y = 7,
            width = 1,
            height = 1
        }
    })

    -- Draw with focus based on playing state
    grid_ui.draw = function(self, layers)
        local brightness = params:get("wtape_toggle_playing") == 1 and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    -- Toggle playing on press
    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_toggle_playing", 1 - params:get("wtape_toggle_playing"))
        end
    end

    return grid_ui
end

function WTapePlayback.init()
    local component = {
        grid = create_grid_ui()
    }

    return component
end

return WTapePlayback

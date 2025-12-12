-- wtape_record.lua
-- Grid button and screen display for toggling WTape recording

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local WTapeRecord = {}
WTapeRecord.__index = WTapeRecord

local function create_screen_ui()
    local screen_ui = NornsUI.new({
        id = "WTAPE_RECORD",
        name = "Record",
        description = Descriptions.WTAPE_RECORD,
        params = {
            { separator = true, title = "Recording" },
            { id = "wtape_rec_level", arc_multi_float = {0.1, 0.05, 0.01} },
            { id = "wtape_erase_strength", arc_multi_float = {0.1, 0.05, 0.01} },
            { id = "wtape_echo_mode" }
        }
    })

    -- Display recording status below parameters
    screen_ui.draw_default = function(self)
        NornsUI.draw_default(self)

        local is_recording = params:get("wtape_toggle_recording") == 1
        local status_text = is_recording and "REC ON" or "REC OFF"

        local width = screen.text_extents(status_text)
        screen.level(is_recording and 15 or 6)
        screen.move(64 - width/2, 46)
        screen.text(status_text)

        screen.update()
    end

    return screen_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE_RECORD",
        layout = {
            x = 15,
            y = 7,
            width = 1,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local brightness = params:get("wtape_toggle_recording") == 1 and
            GridConstants.BRIGHTNESS.UI.FOCUSED or
            GridConstants.BRIGHTNESS.UI.NORMAL
        layers.ui[self.layout.x][self.layout.y] = brightness
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            params:set("wtape_toggle_recording", 1 - params:get("wtape_toggle_recording"))
            _seeker.ui_state.set_current_section("WTAPE_RECORD")
        end
    end

    return grid_ui
end

function WTapeRecord.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }

    return component
end

return WTapeRecord

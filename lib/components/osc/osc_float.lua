-- osc_float.lua
-- Component for OSC float outputs (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")

local OscFloat = {}
OscFloat.__index = OscFloat

-- Track which float is currently selected (1-4)
local selected_float = 1

-- Send float value via shared OSC infrastructure
local function send_float_value(index, value)
    local path = "/float/" .. index .. "/value"
    _seeker.osc_config.send_message(path, {value})
    return value
end

-- Send float multiplier via shared OSC infrastructure
local function send_float_multiplier(index)
    local multiplier = params:get("osc_float_" .. index .. "_multiplier")
    local path = "/float/" .. index .. "/multiplier"
    _seeker.osc_config.send_message(path, {multiplier})
    return multiplier
end

local function create_params()
    for i = 1, 4 do
        params:add_control("osc_float_" .. i .. "_value", "Float " .. i .. " Value", controlspec.new(-50.0, 50.0, 'lin', 0.01, 0.0))
        params:set_action("osc_float_" .. i .. "_value", function(value)
            send_float_value(i, value)
        end)

        params:add_number("osc_float_" .. i .. "_multiplier", "Float " .. i .. " Multiplier", -100, 100, 1)
        params:set_action("osc_float_" .. i .. "_multiplier", function(value)
            send_float_multiplier(i)
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "OSC_FLOAT",
        name = "Float 1",
        description = "OSC float output configuration",
        params = {}
    })

    -- Populate params before parent enter so Arc controller receives data
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    -- Dynamic parameter rebuilding based on selected float
    norns_ui.rebuild_params = function(self)
        -- Update section name with current float
        self.name = string.format("Float %d", selected_float)

        local param_table = {
            { separator = true, title = "Float " .. selected_float },
            { id = "osc_float_" .. selected_float .. "_value", name = "Value", arc_multi_float = {1.0, 0.1, 0.01} },
            { id = "osc_float_" .. selected_float .. "_multiplier", name = "Multiplier" }
        }

        self.params = param_table
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "OSC_FLOAT",
        layout = {
            x = 13,
            y = 5,
            width = 4,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local current_section = _seeker.ui_state.get_current_section()
        local is_on_float_screen = current_section == "OSC_FLOAT"

        -- Draw all 4 float buttons
        for i = 0, 3 do
            local float_num = i + 1
            local is_selected = (float_num == selected_float)

            local brightness
            if is_selected and is_on_float_screen then
                brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
            elseif is_selected then
                brightness = GridConstants.BRIGHTNESS.MEDIUM
            else
                brightness = GridConstants.BRIGHTNESS.UI.NORMAL
            end

            layers.ui[self.layout.x + i][self.layout.y] = brightness
        end
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then -- Key down only
            local float_num = (x - self.layout.x) + 1

            if float_num >= 1 and float_num <= 4 then
                -- Switch focus to this float
                selected_float = float_num

                -- Switch screen section to show this float's parameters
                _seeker.ui_state.set_current_section("OSC_FLOAT")

                -- Rebuild screen params
                if _seeker.osc_float and _seeker.osc_float.screen then
                    _seeker.osc_float.screen:rebuild_params()
                    _seeker.screen_ui.set_needs_redraw()
                end

                return true
            end
        end

        return false
    end

    return grid_ui
end

function OscFloat.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return OscFloat

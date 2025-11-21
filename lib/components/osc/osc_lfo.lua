-- osc_lfo.lua
-- Component for OSC LFO outputs (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local OscUtils = include("lib/components/osc/osc_utils")

local OscLfo = {}
OscLfo.__index = OscLfo

-- Track which LFO is currently selected (1-4)
local selected_lfo = 1

-- Track active LFO sync clocks for pulse mode
local active_lfo_sync_clocks = {}

-- Send LFO frequency
local function send_lfo_frequency(lfo_index)
    local sync_div = params:string("osc_lfo_" .. lfo_index .. "_sync")
    local frequency = OscUtils.sync_to_frequency(sync_div)

    -- Stop existing LFO sync clock if any
    if active_lfo_sync_clocks["lfo_" .. lfo_index] then
        clock.cancel(active_lfo_sync_clocks["lfo_" .. lfo_index])
        active_lfo_sync_clocks["lfo_" .. lfo_index] = nil
    end

    if frequency > 0 then
        local path = "/lfo/" .. lfo_index .. "/freq"
        _seeker.osc_config.send_message(path, {frequency})

        -- Send sync pulse on next beat boundary
        local beats = OscUtils.division_to_beats(sync_div)
        local function send_single_sync_pulse()
            clock.sync(beats)
            local sync_path = "/lfo/" .. lfo_index .. "/sync"

            _seeker.osc_config.send_message(sync_path, {1})

            clock.sleep(0.25)
            _seeker.osc_config.send_message(sync_path, {0})
        end

        active_lfo_sync_clocks["lfo_" .. lfo_index] = clock.run(send_single_sync_pulse)

        return frequency
    else
        local path = "/lfo/" .. lfo_index .. "/freq"
        _seeker.osc_config.send_message(path, {0})
        return 0
    end
end

-- Send LFO min/max range
local function send_lfo_range(lfo_index)
    local min_val = params:get("osc_lfo_" .. lfo_index .. "_min")
    local max_val = params:get("osc_lfo_" .. lfo_index .. "_max")

    local min_path = "/lfo/" .. lfo_index .. "/min"
    local max_path = "/lfo/" .. lfo_index .. "/max"

    _seeker.osc_config.send_message(min_path, {min_val})
    _seeker.osc_config.send_message(max_path, {max_val})
end

-- Send LFO shape type (as integer: 0=Sine, 1=Gaussian, 2=Triangle, 3=Ramp, 4=Square, 5=Pulse)
local function send_lfo_shape(lfo_index)
    local shape_index = params:get("osc_lfo_" .. lfo_index .. "_shape") - 1
    local path = "/lfo/" .. lfo_index .. "/shape"
    _seeker.osc_config.send_message(path, {shape_index})
end

local function create_params()
    for i = 1, 4 do
        params:add_option("osc_lfo_" .. i .. "_sync", "LFO " .. i .. " Sync", OscUtils.sync_options, 1)
        params:set_action("osc_lfo_" .. i .. "_sync", function(value)
            send_lfo_frequency(i)
        end)

        params:add_option("osc_lfo_" .. i .. "_shape", "LFO " .. i .. " Shape", OscUtils.lfo_shape_options, 1)
        params:set_action("osc_lfo_" .. i .. "_shape", function(value)
            send_lfo_shape(i)
        end)

        params:add_control("osc_lfo_" .. i .. "_min", "LFO " .. i .. " Min", controlspec.new(-10.0, 10.0, 'lin', 0.01, 0.0))
        params:set_action("osc_lfo_" .. i .. "_min", function(value)
            send_lfo_range(i)
        end)

        params:add_control("osc_lfo_" .. i .. "_max", "LFO " .. i .. " Max", controlspec.new(-10.0, 10.0, 'lin', 0.01, 10.0))
        params:set_action("osc_lfo_" .. i .. "_max", function(value)
            send_lfo_range(i)
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "OSC_LFO",
        name = "LFO 1",
        description = "OSC LFO output configuration",
        params = {}
    })

    -- Populate params before parent enter so Arc controller receives data
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    norns_ui.rebuild_params = function(self)
        self.name = string.format("LFO %d", selected_lfo)

        local param_table = {
            { separator = true, title = "LFO " .. selected_lfo },
            { id = "osc_lfo_" .. selected_lfo .. "_sync", name = "Sync" },
            { id = "osc_lfo_" .. selected_lfo .. "_shape", name = "Shape" },
            { id = "osc_lfo_" .. selected_lfo .. "_min", name = "Min", arc_multi_float = {1.0, 0.1, 0.01} },
            { id = "osc_lfo_" .. selected_lfo .. "_max", name = "Max", arc_multi_float = {1.0, 0.1, 0.01} }
        }

        self.params = param_table
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "OSC_LFO",
        layout = {
            x = 13,
            y = 6,
            width = 4,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local current_section = _seeker.ui_state.get_current_section()
        local is_on_lfo_screen = current_section == "OSC_LFO"

        for i = 0, 3 do
            local lfo_num = i + 1
            local is_selected = (lfo_num == selected_lfo)

            local brightness
            if is_selected and is_on_lfo_screen then
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
        if z == 1 then
            local lfo_num = (x - self.layout.x) + 1

            if lfo_num >= 1 and lfo_num <= 4 then
                selected_lfo = lfo_num

                _seeker.ui_state.set_current_section("OSC_LFO")

                if _seeker.osc_lfo and _seeker.osc_lfo.screen then
                    _seeker.osc_lfo.screen:rebuild_params()
                    _seeker.screen_ui.set_needs_redraw()
                end

                return true
            end
        end

        return false
    end

    return grid_ui
end

-- Sync all LFOs by restarting their clocks
function OscLfo.sync()
    for clock_id, _ in pairs(active_lfo_sync_clocks) do
        if active_lfo_sync_clocks[clock_id] then
            clock.cancel(active_lfo_sync_clocks[clock_id])
            active_lfo_sync_clocks[clock_id] = nil
        end
    end

    for i = 1, 4 do
        send_lfo_frequency(i)
    end
end

function OscLfo.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = OscLfo.sync
    }
    create_params()

    -- Update LFO frequencies when tempo changes
    params:set_action("clock_tempo", function(value)
        for i = 1, 4 do
            send_lfo_frequency(i)
        end
    end)

    return component
end

return OscLfo

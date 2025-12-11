-- config.lua
-- Self-contained component for global configuration settings

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local theory = include('lib/motif_core/theory')
local musicutil = require('musicutil')

local Config = {}
Config.__index = Config

-- Tap tempo state
local tap_times = {}
local tap_timer = nil
local INACTIVITY_TIMEOUT = 2.0
local MAX_TAPS = 6

local function calculate_tap_tempo()
    if #tap_times < 2 then
        return nil
    end
    
    local intervals = {}
    for i = 2, #tap_times do
        local interval = tap_times[i] - tap_times[i-1]
        table.insert(intervals, interval)
    end
    
    local total_interval = 0
    for _, interval in ipairs(intervals) do
        total_interval = total_interval + interval
    end
    
    local avg_interval = total_interval / #intervals
    local bpm = 60 / avg_interval
    
    bpm = math.max(20, math.min(300, bpm))
    
    return math.floor(bpm)
end

local function tap_tempo()
    local current_time = util.time()
    
    -- Add current tap time
    table.insert(tap_times, current_time)
    
    -- Keep only the last MAX_TAPS
    if #tap_times > MAX_TAPS then
        table.remove(tap_times, 1)
    end
    
    -- Cancel existing timer
    if tap_timer then
        tap_timer:stop()
    end
    
    -- Set new timer for inactivity
    tap_timer = metro.init(function()
        local bpm = calculate_tap_tempo()
        if bpm then
            params:set("clock_tempo", bpm)
            params:set("seeker_clock_tempo", bpm) -- Also update our wrapper parameter

            -- Directly set the internal clock tempo (this actually updates the clock engine)
            if clock.internal and clock.internal.set_tempo then
                clock.internal.set_tempo(bpm)
            end

            -- Manually trigger tempo change handler
            if clock.tempo_change_handler then
                clock.tempo_change_handler(bpm)
            end

            _seeker.screen_ui.set_needs_redraw()
        end
        tap_times = {}
        tap_timer:stop()
    end, INACTIVITY_TIMEOUT, 1)
    tap_timer:start()
end

local function create_params()
    params:add_group("config", "CONFIG", 5)

    -- Clock - create wrapper parameter that controls system clock_tempo
    params:add_number("seeker_clock_tempo", "BPM", 40, 300, 120, function(param) return param.value .. " BPM" end)
    params:set_action("seeker_clock_tempo", function(value)
        -- Update the system clock_tempo parameter
        params:set("clock_tempo", value)

        -- Directly set the internal clock tempo (this actually updates the clock engine)
        if clock.internal and clock.internal.set_tempo then
            clock.internal.set_tempo(value)
        end

        -- Manually trigger tempo change handler since params:set() doesn't always trigger it
        if clock.tempo_change_handler then
            clock.tempo_change_handler(value)
        end
    end)

    params:add_binary("tap_tempo", "Tap Tempo", "trigger", 0)
    params:set_action("tap_tempo", function(value)
        if value == 1 then
            tap_tempo()
        end
    end)

    params:add_binary("sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("sync_all_clocks", function(value)
        if value == 1 then
            if _seeker and _seeker.conductor then
                _seeker.conductor.sync_all()
            end
            _seeker.ui_state.trigger_activated("sync_all_clocks")
        end
    end)

    -- Visuals
    params:add_control("background_brightness", "Background Brightness", controlspec.new(0, 15, 'lin', 1, 4), function(param) return params:get(param.id) end)
    params:add_binary("screensaver_enabled", "Screensaver", "toggle", 1)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CONFIG",
        name = "Seeker II Config",
        description = "Settings that affect all modes",
        params = {
            { separator = true, title = "Clock" },
            { id = "seeker_clock_tempo", arc_multi_float = {10, 5, 1} },
            { id = "tap_tempo", is_action = true },
            { id = "sync_all_clocks", is_action = true },
            { separator = true, title = "Visuals" },
            { id = "background_brightness" },
            { id = "screensaver_enabled" }
        }
    })

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "CONFIG",
        layout = {
            x = 16,
            y = 1,
            width = 1,
            height = 1
        }
    })

    -- Draw normally (visible button)
    -- Uses default GridUI draw behavior

    -- Override handle_key to switch to CONFIG section
    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            _seeker.ui_state.set_current_section("CONFIG")
        end
    end

    return grid_ui
end

function Config.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return Config 
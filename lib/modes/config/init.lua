-- config.lua
-- Self-contained component for global configuration settings

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local theory = include('lib/modes/motif/core/theory')
local Descriptions = include("lib/ui/component_descriptions")
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

local function apply_tempo(bpm)
    params:set("clock_tempo", bpm)
    params:set("seeker_clock_tempo", bpm)

    -- Update the clock engine directly
    if clock.internal and clock.internal.set_tempo then
        clock.internal.set_tempo(bpm)
    end

    -- Propagate tempo change to listeners
    if clock.tempo_change_handler then
        clock.tempo_change_handler(bpm)
    end

    _seeker.screen_ui.set_needs_redraw()
end

local function tap_tempo()
    local current_time = util.time()
    table.insert(tap_times, current_time)

    -- Keep only the last MAX_TAPS
    if #tap_times > MAX_TAPS then
        table.remove(tap_times, 1)
    end

    _seeker.ui_state.trigger_activated("tap_tempo")

    -- Calculate and apply tempo from current tap sequence
    local bpm = calculate_tap_tempo()
    if bpm then
        apply_tempo(bpm)
    end

    -- Cancel existing timer
    if tap_timer then
        tap_timer:stop()
    end

    -- Reset tap buffer after inactivity
    tap_timer = metro.init(function()
        tap_times = {}
        tap_timer:stop()
    end, INACTIVITY_TIMEOUT, 1)
    tap_timer:start()
end

local function midi_note_formatter(param)
    if param:get() == -1 then return "Off" end
    return param:get()
end

local function create_params()
    params:add_group("config", "CONFIG", 9)

    -- Clock - create wrapper parameter that controls system clock_tempo
    params:add_number("seeker_clock_tempo", "BPM", 40, 300, 80, function(param) return param.value .. " BPM" end)
    params:set_action("seeker_clock_tempo", function(value)
        -- Update the system clock_tempo parameter
        params:set("clock_tempo", value)

        -- Update the clock engine directly
        if clock.internal and clock.internal.set_tempo then
            clock.internal.set_tempo(value)
        end

        -- Propagate tempo change to listeners
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
    params:add_option("screensaver_timeout", "Screensaver Timing", {"Off", "15s", "30s", "45s", "1m", "1m 15s", "1m 30s", "1m 45s", "2m"}, 5)

    -- Hardware
    params:add_binary("shield_encoder_fix", "Shield Encoder Fix", "toggle", 0)

    -- MIDI
    params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 1)
    params:add_number("record_midi_note", "Record Toggle Note", -1, 127, -1, midi_note_formatter)
    params:add_number("overdub_midi_note", "Overdub Toggle Note", -1, 127, -1, midi_note_formatter)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CONFIG",
        name = "Seeker II Config",
        description = Descriptions.CONFIG,
        params = {
            { separator = true, title = "Clock" },
            { id = "seeker_clock_tempo", arc_multi_float = {10, 5, 1} },
            { id = "tap_tempo", is_action = true },
            { id = "sync_all_clocks", is_action = true },
            { separator = true, title = "Visuals" },
            { id = "background_brightness" },
            { id = "screensaver_timeout" },
            { separator = true, title = "Hardware" },
            { id = "shield_encoder_fix" },
            { separator = true, title = "MIDI" },
            { id = "snap_midi_to_scale" },
            { id = "record_midi_note", arc_multi_float = {10, 5, 1} },
            { id = "overdub_midi_note", arc_multi_float = {10, 5, 1} }
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
-- w_tape.lua
-- Self-contained component for WTape functionality.

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
-- local GridConstants = include("lib/grid/constants") -- Not needed for minimal version

local WTape = {}
WTape.__index = WTape

-- wtape api here: https://github.com/monome/crow/blob/main/lua/ii/wtape.lua
local function create_params()
    params:add_group("wtape", "WTAPE", 12)

    -- Playback
    params:add_binary("wtape_toggle_playing", "Toggle Playing", "toggle", 0)
    params:set_action("wtape_toggle_playing", function(value)
        crow.ii.wtape.play(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("wtape_speed", "Speed", controlspec.new(-2, 2, 'lin', 0.01, 1))
    params:set_action("wtape_speed", function(value)
        crow.ii.wtape.speed(value)
    end)

    -- Direction state: 1 = forward, -1 = reverse (tracked locally since reverse() is stateless)
    _seeker.wtape_direction = 1

    params:add_binary("wtape_reverse", "Play Direction", "trigger", 0)
    params:set_action("wtape_reverse", function(value)
        if value == 1 then
            crow.ii.wtape.reverse()
            _seeker.wtape_direction = _seeker.wtape_direction * -1
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Recording
    params:add_binary("wtape_toggle_recording", "Arm Recording", "toggle", 0)
    params:set_action("wtape_toggle_recording", function(value)
        crow.ii.wtape.record(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("wtape_erase_strength", "Overdub Strength", controlspec.new(0, 1, 'lin', 0.01, 0.25))
    params:set_action("wtape_erase_strength", function(value)
        crow.ii.wtape.erase_strength(value)
    end)

    params:add_control("wtape_monitor_level", "Monitor Level", controlspec.new(0, 1, 'lin', 0.01, 0.9))
    params:set_action("wtape_monitor_level", function(value)
        crow.ii.wtape.monitor_level(value)
    end)

    params:add_control("wtape_rec_level", "Recording Level", controlspec.new(0, 1, 'lin', 0.01, 0.9))
    params:set_action("wtape_rec_level", function(value)
        crow.ii.wtape.rec_level(value)
    end)
    
    -- Seek
    params:add_binary("wtape_rewind", "Rewind 10 seconds", "trigger", 0)
    params:set_action("wtape_rewind", function(value)
        if value == 1 then
            crow.ii.wtape.seek(-10)
            _seeker.ui_state.trigger_activated("wtape_rewind")
        end
    end)
    
    params:add_binary("wtape_fast_forward", "Fast Forward 10 seconds", "trigger", 0)
    params:set_action("wtape_fast_forward", function(value)
        if value == 1 then
            crow.ii.wtape.seek(10)
            _seeker.ui_state.trigger_activated("wtape_fast_forward")
        end
    end)

    -- Loop Functions
    params:add_binary("wtape_loop_mode", "Loop Active", "toggle", 0)
    params:set_action("wtape_loop_mode", function(value)
        crow.ii.wtape.loop_active(value)
        _seeker.screen_ui.set_needs_redraw()
    end)
    
    params:add_binary("wtape_loop_start", "Set Loop Start", "trigger", 0)
    params:set_action("wtape_loop_start", function(value)
        if value == 1 then
            crow.ii.wtape.loop_start()
            _seeker.ui_state.trigger_activated("wtape_loop_start")
        end
    end)

    params:add_binary("wtape_loop_end", "Set Loop End", "trigger", 0)
    params:set_action("wtape_loop_end", function(value)
        if value == 1 then
            crow.ii.wtape.loop_end()
            _seeker.ui_state.trigger_activated("wtape_loop_end")
        end
    end)
    
    
end

local function create_screen_ui()
    return NornsUI.new({
        id = "WTAPE",
        name = "WTape Config",
        description = "WTape settings. Most documented features implemented via grid buttons.",
        params = {
            { separator = true, title = "Playback" },
            { id = "wtape_speed", arc_multi_float = {1.0, 0.1, 0.01}},
            { separator = true, title = "Recording"},
            { id = "wtape_erase_strength", arc_multi_float = {0.1, 0.01, 0.001}},
            { id = "wtape_monitor_level", arc_multi_float = {0.1, 0.01, 0.001}},
            { id = "wtape_rec_level", arc_multi_float = {0.1, 0.01, 0.001}},
        }
    })
end

local function create_grid_ui()
    -- No grid button - the WTAPE mode button at (13, 2) serves as virtual navigation
    -- ModeSwitcher handles switching to WTAPE mode and setting default section
    -- This pattern allows mode buttons to serve dual purpose: mode switching + component access
    return nil
end

function WTape.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return WTape 
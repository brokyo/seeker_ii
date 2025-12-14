-- WTape configuration: speed, recording levels, and navigation

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local Descriptions = include("lib/ui/component_descriptions")

local WTape = {}
WTape.__index = WTape

-- wtape api here: https://github.com/monome/crow/blob/main/lua/ii/wtape.lua

-- Sync W/Tape to known defaults on boot
local function sync_to_hardware()
    -- Stop everything
    crow.ii.wtape.play(0)
    crow.ii.wtape.record(0)
    crow.ii.wtape.loop_active(0)

    -- Go to tape start
    crow.ii.wtape.timestamp(0, 0)

    -- Set known defaults
    crow.ii.wtape.speed(1)
    crow.ii.wtape.erase_strength(0.3)
    crow.ii.wtape.monitor_level(0.9)
    crow.ii.wtape.rec_level(0.9)
    crow.ii.wtape.echo_mode(0)
end

local function create_params()
    params:add_group("wtape", "WTAPE", 17)

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

    -- Direction state: 1 = forward, -1 = reverse
    _seeker.wtape.direction = 1

    params:add_binary("wtape_reverse", "Play Direction", "trigger", 0)
    params:set_action("wtape_reverse", function(value)
        if value == 1 then
            crow.ii.wtape.reverse()
            _seeker.wtape.direction = _seeker.wtape.direction * -1
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Recording
    params:add_binary("wtape_toggle_recording", "Arm Recording", "toggle", 0)
    params:set_action("wtape_toggle_recording", function(value)
        crow.ii.wtape.record(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("wtape_erase_strength", "Decay", controlspec.new(0, 1, 'lin', 0.01, 0.3))
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

    params:add_binary("wtape_echo_mode", "Echo Mode", "toggle", 0)
    params:set_action("wtape_echo_mode", function(value)
        crow.ii.wtape.echo_mode(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    -- Seek
    params:add_control("wtape_rewind_time", "Rewind Time", controlspec.new(0.1, 60, 'lin', 0.1, 10))

    params:add_binary("wtape_rewind", "Rewind", "trigger", 0)
    params:set_action("wtape_rewind", function(value)
        if value == 1 then
            local time = params:get("wtape_rewind_time")
            crow.ii.wtape.seek(-time)
            _seeker.ui_state.trigger_activated("wtape_rewind")
        end
    end)

    params:add_control("wtape_ff_time", "Fast Forward Time", controlspec.new(0.1, 60, 'lin', 0.1, 10))

    params:add_binary("wtape_fast_forward", "Fast Forward", "trigger", 0)
    params:set_action("wtape_fast_forward", function(value)
        if value == 1 then
            local time = params:get("wtape_ff_time")
            crow.ii.wtape.seek(time)
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

    -- Jump to tape start (timestamp 0)
    params:add_binary("wtape_goto_start", "Go To Start", "trigger", 0)
    params:set_action("wtape_goto_start", function(value)
        if value == 1 then
            crow.ii.wtape.timestamp(0, 0)
            _seeker.ui_state.trigger_activated("wtape_goto_start")
        end
    end)

    -- Full W/Tape reset: clear tape, reset params to defaults, sync to hardware
    params:add_binary("wtape_init", "Init W/Tape", "trigger", 0)
    params:set_action("wtape_init", function(value)
        if value == 1 then
            -- Stop everything
            crow.ii.wtape.play(0)
            crow.ii.wtape.record(0)
            crow.ii.wtape.loop_active(0)
            params:set("wtape_toggle_playing", 0, true)
            params:set("wtape_toggle_recording", 0, true)
            params:set("wtape_loop_mode", 0, true)

            -- Clear all tape audio
            crow.ii.wtape.WARNING_clear_tape()

            -- Go to tape start
            crow.ii.wtape.timestamp(0, 0)

            -- Reset params to defaults
            params:set("wtape_speed", 1, true)
            params:set("wtape_erase_strength", 0.3, true)
            params:set("wtape_monitor_level", 0.9, true)
            params:set("wtape_rec_level", 0.9, true)
            params:set("wtape_echo_mode", 0, true)

            -- Sync all to hardware
            sync_to_hardware()

            _seeker.ui_state.trigger_activated("wtape_init")
            _seeker.screen_ui.set_needs_redraw()
        end
    end)
end

local function create_screen_ui()
    return NornsUI.new({
        id = "WTAPE",
        name = "WTape Config",
        description = Descriptions.WTAPE,
        params = {
            { separator = true, title = "Levels" },
            { id = "wtape_monitor_level", arc_multi_float = {0.1, 0.01, 0.001} },
            { separator = true, title = "Navigation" },
            { id = "wtape_goto_start", is_action = true },
            { separator = true, title = "Reset" },
            { id = "wtape_init", is_action = true },
        }
    })
end

local function create_grid_ui()
    -- Grid UI managed by mode switcher
    return nil
end

function WTape.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    sync_to_hardware()

    return component
end

return WTape 
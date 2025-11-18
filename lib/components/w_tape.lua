-- w_tape.lua
-- Self-contained component for WTape functionality.

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
-- local GridConstants = include("lib/grid_constants") -- Not needed for minimal version

local WTape = {}
WTape.__index = WTape

-- wtape api here: https://github.com/monome/crow/blob/main/lua/ii/wtape.lua
local function create_params()
    params:add_group("wtape", "WTAPE", 11)

    -- Playback
    params:add_binary("wtape_toggle_playing", "Toggle Playing", "toggle", 0)
    params:set_action("wtape_toggle_playing", function(value)
        crow.ii.wtape.play(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("wtape_speed", "Speed", controlspec.new(-2, 2, 'lin', 0.05, 1))
    params:set_action("wtape_speed", function(value)
        crow.ii.wtape.speed(value)
    end)

    -- Recording
    params:add_binary("wtape_toggle_recording", "Arm Recording", "toggle", 0)
    params:set_action("wtape_toggle_recording", function(value)
        crow.ii.wtape.record(value)
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("wtape_erase_strength", "Overdub Strength", controlspec.new(0, 1, 'lin', 0.02, 0.25))
    params:set_action("wtape_erase_strength", function(value)
        crow.ii.wtape.erase_strength(value)
    end)

    params:add_control("wtape_monitor_level", "Monitor Level", controlspec.new(0, 1, 'lin', 0.02, 0.9))
    params:set_action("wtape_monitor_level", function(value)
        crow.ii.wtape.monitor_level(value)
    end)

    params:add_control("wtape_rec_level", "Recording Level", controlspec.new(0, 1, 'lin', 0.02, 0.9))
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
    params:add_binary("wtape_loop_mode", "Reactivate Loop", "toggle", 0)
    params:set_action("wtape_loop_mode", function(value)
        crow.ii.wtape.loop_active(value)
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
        name = "WTape",
        description = "WTape test component.",
        params = {
            { separator = true, title = "WTape" },
            { id = "wtape_toggle_playing", is_action = true},
            { id = "wtape_speed"},
            { separator = true, title = "Record"},
            { id ="wtape_toggle_recording", is_action = true},
            { id = "wtape_erase_strength"},
            { id = "wtape_monitor_level"},
            { id = "wtape_rec_level"},
            { separator = true, title = "Seek"},
            { id = "wtape_rewind", is_action = true},
            { id = "wtape_fast_forward", is_action = true},
            { separator = true, title = "Loop"},
            { id = "wtape_loop_mode", is_action = true},
            { id = "wtape_loop_start", is_action = true},
            { id = "wtape_loop_end", is_action = true}
            -- { separator = true, title = "Recording", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_is_recording", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"} 
            -- }},
            -- { id = "wtape_monitor_level", name = "Monitor Level", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_rec_level", name = "Recording Level", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { separator = true, title = "Playback", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_is_playing", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_play_direction", name = "Play Direction", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_speed", name = "Speed", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { separator = true, title = "Loop Config", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_loop_mode", name = "Loop Mode", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_loop_start", name = "Loop Start", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }},
            -- { id = "wtape_loop_end", name = "Loop End", view_conditions = {
            --     { id = "wtape_active", operator = "=", value = "True"}
            -- }}
        }
    })
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "WTAPE",
        layout = {
            x = 13,
            y = 2,
            width = 1,
            height = 1
        }
    })

    -- Override handle_key to switch to WTAPE section
    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            _seeker.ui_state.set_current_section("WTAPE")
        end
    end

    return grid_ui
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
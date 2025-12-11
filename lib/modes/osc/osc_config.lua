-- osc_config.lua
-- Global OSC configuration: connection settings and sync orchestration

local NornsUI = include("lib/ui/base/norns_ui")

local OscConfig = {}
OscConfig.__index = OscConfig

-- Get formatted destination IP
local function get_dest_ip()
    return params:get("osc_dest_octet_1") .. "." ..
           params:get("osc_dest_octet_2") .. "." ..
           params:get("osc_dest_octet_3") .. "." ..
           params:get("osc_dest_octet_4")
end

-- Send OSC message
local function send_osc_message(path, args)
    local dest = {get_dest_ip(), params:get("osc_dest_port")}
    osc.send(dest, path, args)
    return true
end

-- Test connection
local function test_osc_connection()
    local success = send_osc_message("/open_the_next", {"lets all love lain"})
    if success then
        print("Test message sent to " .. get_dest_ip() .. ":" .. params:get("osc_dest_port"))
    end
end

local function create_params()
    params:add_group("osc_config", "OSC CONFIG", 7)

    -- Sync all OSC clocks and lanes
    params:add_binary("osc_sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("osc_sync_all_clocks", function()
        -- Delegate to conductor for unified global sync
        if _seeker and _seeker.conductor then
            _seeker.conductor.sync_all()
        end
    end)

    -- Connection configuration
    params:add_separator("osc_connection", "Connection")
    params:add_number("osc_dest_octet_1", "Dest IP Octet 1", 0, 255, 192)
    params:add_number("osc_dest_octet_2", "Dest IP Octet 2", 0, 255, 168)
    params:add_number("osc_dest_octet_3", "Dest IP Octet 3", 0, 255, 0)
    params:add_number("osc_dest_octet_4", "Dest IP Octet 4", 0, 255, 230)
    params:add_number("osc_dest_port", "Dest Port", 1000, 65535, 10000)

    params:add_binary("osc_test_trigger", "Send Test Message", "trigger", 0)
    params:set_action("osc_test_trigger", function(value)
        if value == 1 then
            test_osc_connection()
            _seeker.ui_state.trigger_activated("osc_test_trigger")
        end
    end)
end

local function create_screen_ui()
    return NornsUI.new({
        id = "OSC_CONFIG",
        name = "OSC Config",
        description = "OSC connection and settings. Tuned for TouchDesigner.",
        params = {
            { separator = true, title = "Actions" },
            { id = "osc_sync_all_clocks", is_action = true },
            { separator = true, title = "Connection" },
            { id = "osc_dest_octet_1", arc_multi_float = {10, 5, 1} },
            { id = "osc_dest_octet_2", arc_multi_float = {10, 5, 1} },
            { id = "osc_dest_octet_3", arc_multi_float = {10, 5, 1} },
            { id = "osc_dest_octet_4", arc_multi_float = {10, 5, 1} },
            { id = "osc_dest_port", arc_multi_float = {1000, 100, 10} },
            { separator = true, title = "Test" },
            { id = "osc_test_trigger", is_action = true }
        }
    })
end

local function create_grid_ui()
    -- No grid button - the OSC_CONFIG mode button at (14, 2) serves as virtual navigation
    -- ModeSwitcher handles switching to OSC_CONFIG mode and setting default section
    -- This pattern allows mode buttons to serve dual purpose: mode switching + component access
    return nil
end

-- Sync all OSC outputs by calling type components' sync methods
function OscConfig.sync()
    if _seeker.osc and _seeker.osc.lfo and _seeker.osc.lfo.sync then
        _seeker.osc.lfo.sync()
    end

    if _seeker.osc and _seeker.osc.trigger and _seeker.osc.trigger.sync then
        _seeker.osc.trigger.sync()
    end
end

function OscConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = OscConfig.sync,
        send_message = send_osc_message,
        get_dest_ip = get_dest_ip,
        test_connection = test_osc_connection
    }
    create_params()

    return component
end

return OscConfig

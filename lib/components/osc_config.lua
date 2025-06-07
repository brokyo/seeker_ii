-- osc_config.lua
-- Support OpenSoundControl configuration and integration into other app_on_screen

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local OscConfig = {}
OscConfig.__index = OscConfig

-- Track active trigger clocks
local active_trigger_clocks = {}

-- Track binary trigger states (true = high, false = low)
local binary_trigger_states = {false, false, false, false}

-- Configuration constants (same as eurorack_output.lua)
local sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}

local function create_params()
    params:add_group("osc_config", "OSC CONFIG", 43)
    params:add_number("osc_dest_octet_1", "Dest IP Octet 1", 0, 255, 192)
    params:add_number("osc_dest_octet_2", "Dest IP Octet 2", 0, 255, 168)
    params:add_number("osc_dest_octet_3", "Dest IP Octet 3", 0, 255, 0)
    params:add_number("osc_dest_octet_4", "Dest IP Octet 4", 0, 255, 230)
    params:add_number("osc_dest_port", "Dest Port", 1000, 65535, 10101)
    
    params:add_binary("osc_test_trigger", "Send Test Message", "trigger", 0)
    params:set_action("osc_test_trigger", function(value)
        if value == 1 then
            test_osc_connection()
            _seeker.ui_state.trigger_activated("osc_test_trigger")
        end
    end)
    
    -- Integer parameters (-100 to 100)
    params:add_number("osc_int_1", "Integer 1", -100, 100, 0)
    params:set_action("osc_int_1", function(value)
        send_integer_value(1, value)
    end)
    
    params:add_number("osc_int_2", "Integer 2", -100, 100, 0)
    params:set_action("osc_int_2", function(value)
        send_integer_value(2, value)
    end)
    
    -- Decimal parameters (-5.0 to 5.0)
    params:add_control("osc_float_1", "Float 1", controlspec.new(-5.0, 5.0, 'lin', 0.01, 0.0))
    params:set_action("osc_float_1", function(value)
        send_float_value(1, value)
    end)
    
    params:add_control("osc_float_2", "Float 2", controlspec.new(-5.0, 5.0, 'lin', 0.01, 0.0))
    params:set_action("osc_float_2", function(value)
        send_float_value(2, value)
    end)
    
    -- LFO Frequency parameters (4 LFOs)
    for i = 1, 4 do
        params:add_option("osc_lfo_" .. i .. "_sync", "LFO " .. i .. " Sync", sync_options, 1) -- Default to "Off"
        params:set_action("osc_lfo_" .. i .. "_sync", function(value)
            send_lfo_frequency(i)
        end)
    end
    
    -- Clock parameters (4 clocks)
    for i = 1, 4 do
        params:add_option("osc_clock_" .. i .. "_sync", "Clock " .. i .. " Sync", sync_options, 1) -- Default to "Off"
        params:set_action("osc_clock_" .. i .. "_sync", function(value)
            send_clock_frequency(i)
        end)
    end
    
    -- Trigger parameters (4 triggers)
    for i = 1, 4 do
        params:add_option("osc_trigger_" .. i .. "_sync", "Trigger " .. i .. " Sync", sync_options, 1) -- Default to "Off"
        params:set_action("osc_trigger_" .. i .. "_sync", function(value)
            update_trigger_clock(i)
        end)
        
        params:add_option("osc_trigger_" .. i .. "_type", "Trigger " .. i .. " Type", {"Random", "Binary"}, 1) -- Default to "Random"
        params:set_action("osc_trigger_" .. i .. "_type", function(value)
            -- Reset binary state when switching types
            binary_trigger_states[i] = false
            -- Restart trigger if it's running
            if active_trigger_clocks["trigger_" .. i] then
                update_trigger_clock(i)
            end
        end)
        
        -- Random trigger parameters
        params:add_number("osc_trigger_" .. i .. "_min", "Trigger " .. i .. " Min", 0, 100, 0)
        params:add_number("osc_trigger_" .. i .. "_max", "Trigger " .. i .. " Max", 0, 100, 100)
        
        -- Binary trigger parameters
        params:add_number("osc_trigger_" .. i .. "_low", "Trigger " .. i .. " Low", 0, 100, 0)
        params:add_number("osc_trigger_" .. i .. "_high", "Trigger " .. i .. " High", 0, 100, 100)
    end
end

-- Helper function to convert division string to beats (same as eurorack_output.lua)
local function division_to_beats(div)
    -- Handle "Off" as off
    if div == "Off" then
        return 0
    end
    
    -- Handle integer values (1, 2, 3, etc)
    if tonumber(div) then
        return tonumber(div)
    end
    
    -- Handle fraction values (1/4, 1/16, etc)
    local num, den = div:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num)/tonumber(den)
    end
    
    return 1 -- default to quarter note
end

-- Convert sync division to frequency in Hz
local function sync_to_frequency(sync_div)
    local beats = division_to_beats(sync_div)
    
    if beats <= 0 then
        return 0
    end
    
    -- Get current tempo in BPM and convert to frequency
    local beat_sec = clock.get_beat_sec() -- seconds per beat
    local freq_hz = 1 / (beat_sec * beats) -- cycles per second
    
    return freq_hz
end

-- Get formatted destination IP
local function get_dest_ip()
    return params:get("osc_dest_octet_1") .. "." .. 
           params:get("osc_dest_octet_2") .. "." .. 
           params:get("osc_dest_octet_3") .. "." .. 
           params:get("osc_dest_octet_4")
end

-- Send OSC message
function send_osc_message(path, args)
    local dest = {get_dest_ip(), params:get("osc_dest_port")}
    print("OSC Send: " .. path .. " to " .. dest[1] .. ":" .. dest[2])
    
    osc.send(dest, path, args)
    return true
end

-- Send LFO frequency
function send_lfo_frequency(lfo_index)
    local sync_div = params:string("osc_lfo_" .. lfo_index .. "_sync")
    local frequency = sync_to_frequency(sync_div)
    
    if frequency > 0 then
        local path = "/lfo/" .. lfo_index
        local success = send_osc_message(path, {frequency})
        if success then
            print("LFO Frequency sent: " .. frequency .. " Hz (sync: " .. sync_div .. ")")
        end
        return frequency
    else
        print("LFO disabled (sync: " .. sync_div .. ")")
        -- Send 0 to stop TouchDesigner LFO when "Off"
        local path = "/lfo/" .. lfo_index
        send_osc_message(path, {0})
        return 0
    end
end

-- Send integer value
function send_integer_value(index, value)
    local path = "/integer/" .. index
    local success = send_osc_message(path, {value})
    if success then
        print("Integer " .. index .. " sent: " .. value)
    end
    return value
end

-- Send float value
function send_float_value(index, value)
    local path = "/float/" .. index
    local success = send_osc_message(path, {value})
    if success then
        print("Float " .. index .. " sent: " .. string.format("%.2f", value))
    end
    return value
end

-- Send clock frequency
function send_clock_frequency(clock_index)
    local sync_div = params:string("osc_clock_" .. clock_index .. "_sync")
    local beats = division_to_beats(sync_div)
    
    if beats > 0 then
        local path = "/clock/" .. clock_index
        local success = send_osc_message(path, {beats})
        if success then
            print("Clock Period sent: " .. beats .. " beats (sync: " .. sync_div .. ")")
        end
        return beats
    else
        print("Clock disabled (sync: " .. sync_div .. ")")
        -- Send 1 to set a default period when "Off"
        local path = "/clock/" .. clock_index
        send_osc_message(path, {1})
        return 0
    end
end

-- Send trigger pulse
function send_trigger_pulse(trigger_index)
    local trigger_type = params:string("osc_trigger_" .. trigger_index .. "_type")
    local trigger_value
    
    if trigger_type == "Binary" then
        -- Binary mode: alternate between low and high
        local low_val = params:get("osc_trigger_" .. trigger_index .. "_low")
        local high_val = params:get("osc_trigger_" .. trigger_index .. "_high")
        
        -- Toggle state
        binary_trigger_states[trigger_index] = not binary_trigger_states[trigger_index]
        
        -- Send appropriate value
        if binary_trigger_states[trigger_index] then
            trigger_value = high_val
        else
            trigger_value = low_val
        end
    else
        -- Random mode: generate random value between min and max
        local min_val = params:get("osc_trigger_" .. trigger_index .. "_min")
        local max_val = params:get("osc_trigger_" .. trigger_index .. "_max")
        trigger_value = min_val + math.random() * (max_val - min_val)
    end
    
    local path = "/trigger/" .. trigger_index
    local success = send_osc_message(path, {trigger_value})
    if success then
        local mode_str = trigger_type == "Binary" and (binary_trigger_states[trigger_index] and "HIGH" or "LOW") or "RANDOM"
        print("Trigger " .. trigger_index .. " (" .. mode_str .. ") pulse sent: " .. string.format("%.2f", trigger_value))
    end
    return success
end

-- Update trigger clock (start/stop trigger pulses)
function update_trigger_clock(trigger_index)
    -- Stop existing clock if any
    if active_trigger_clocks["trigger_" .. trigger_index] then
        clock.cancel(active_trigger_clocks["trigger_" .. trigger_index])
        active_trigger_clocks["trigger_" .. trigger_index] = nil
    end
    
    local sync_div = params:string("osc_trigger_" .. trigger_index .. "_sync")
    local beats = division_to_beats(sync_div)
    
    -- If division is 0 or "Off", just stop the clock
    if beats <= 0 or sync_div == "Off" then
        print("Trigger " .. trigger_index .. " disabled (sync: " .. sync_div .. ")")
        return
    end
    
    -- Create clock function for trigger pulses
    local function trigger_clock_function()
        while true do
            -- Send trigger pulse
            send_trigger_pulse(trigger_index)
            
            -- Wait for next interval
            clock.sync(beats)
        end
    end
    
    -- Start the trigger clock
    active_trigger_clocks["trigger_" .. trigger_index] = clock.run(trigger_clock_function)
    print("Trigger " .. trigger_index .. " started (sync: " .. sync_div .. ", beats: " .. beats .. ")")
end

-- Test connection
function test_osc_connection()
    local success = send_osc_message("/open_the_next", {"lets all love lain"})
    if success then
        print("Test message sent to " .. get_dest_ip() .. ":" .. params:get("osc_dest_port"))
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "OSC_CONFIG",
        name = "OSC Config",
        description = "Configure OSC send parameters",
        params = {
            { separator = true, title = "OSC Send Config" },
            { id = "osc_dest_octet_1" },
            { id = "osc_dest_octet_2" },
            { id = "osc_dest_octet_3" },
            { id = "osc_dest_octet_4" },
            { id = "osc_dest_port" },
            { separator = true, title = "Integer Values" },
            { id = "osc_int_1" },
            { id = "osc_int_2" },
            { separator = true, title = "Float Values" },
            { id = "osc_float_1" },
            { id = "osc_float_2" },
            { separator = true, title = "LFO Frequency" },
            { id = "osc_lfo_1_sync" },
            { id = "osc_lfo_2_sync" },
            { id = "osc_lfo_3_sync" },
            { id = "osc_lfo_4_sync" },
            { separator = true, title = "Clock" },
            { id = "osc_clock_1_sync" },
            { id = "osc_clock_2_sync" },
            { id = "osc_clock_3_sync" },
            { id = "osc_clock_4_sync" },
            { separator = true, title = "Triggers" },
            { id = "osc_trigger_1_sync" },
            { id = "osc_trigger_1_type" },
            { id = "osc_trigger_1_min" },
            { id = "osc_trigger_1_max" },
            { id = "osc_trigger_1_low" },
            { id = "osc_trigger_1_high" },
            { id = "osc_trigger_2_sync" },
            { id = "osc_trigger_2_type" },
            { id = "osc_trigger_2_min" },
            { id = "osc_trigger_2_max" },
            { id = "osc_trigger_2_low" },
            { id = "osc_trigger_2_high" },
            { id = "osc_trigger_3_sync" },
            { id = "osc_trigger_3_type" },
            { id = "osc_trigger_3_min" },
            { id = "osc_trigger_3_max" },
            { id = "osc_trigger_3_low" },
            { id = "osc_trigger_3_high" },
            { id = "osc_trigger_4_sync" },
            { id = "osc_trigger_4_type" },
            { id = "osc_trigger_4_min" },
            { id = "osc_trigger_4_max" },
            { id = "osc_trigger_4_low" },
            { id = "osc_trigger_4_high" },
            { separator = true, title = "OSC Test" },
            { id = "osc_test_trigger", is_action = true }
        }
    })

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "OSC_CONFIG",
        layout = {
            x = 13,
            y = 2,
            width = 1,
            height = 1
        }
    })

    return grid_ui
end

function OscConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        send_message = send_osc_message,
        test_connection = test_osc_connection,
        send_lfo_frequency = send_lfo_frequency,
        send_clock_frequency = send_clock_frequency,
        send_integer_value = send_integer_value,
        send_float_value = send_float_value,
        send_trigger_pulse = send_trigger_pulse,
        update_trigger_clock = update_trigger_clock
    }
    create_params()
    
    return component
end

return OscConfig
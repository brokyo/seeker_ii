-- osc_config.lua
-- Support OpenSoundControl configuration and integration into other app_on_screen

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local OscConfig = {}
OscConfig.__index = OscConfig

-- Track active trigger clocks
local active_trigger_clocks = {}

-- Track active LFO sync clocks for pulse mode
local active_lfo_sync_clocks = {}



-- Configuration constants
local sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}
local lfo_shape_options = {"Sine", "Gaussian", "Triangle", "Ramp", "Square", "Pulse"}

-- Flag to prevent recursive normalization
local normalizing = false

-- Normalize envelope percentages if they exceed 100%
local function normalize_envelope_if_needed(trigger_index)
    if normalizing then return end

    local attack = params:get("osc_trigger_" .. trigger_index .. "_attack")
    local decay = params:get("osc_trigger_" .. trigger_index .. "_decay")
    local min_sustain = params:get("osc_trigger_" .. trigger_index .. "_min_sustain")
    local release = params:get("osc_trigger_" .. trigger_index .. "_release")

    local total = attack + decay + min_sustain + release

    -- If total exceeds 100%, normalize all values back to 100%
    if total > 100 then
        normalizing = true

        local scale = 100 / total
        params:set("osc_trigger_" .. trigger_index .. "_attack", attack * scale)
        params:set("osc_trigger_" .. trigger_index .. "_decay", decay * scale)
        params:set("osc_trigger_" .. trigger_index .. "_min_sustain", min_sustain * scale)
        params:set("osc_trigger_" .. trigger_index .. "_release", release * scale)

        normalizing = false
    end
end

-- Function to update all LFO frequencies when tempo changes
local function update_all_lfo_frequencies()
    for i = 1, 4 do
        send_lfo_frequency(i)
    end
end

local function create_params()
    params:add_group("osc_config", "OSC CONFIG", 69)

    -- Sync all OSC clocks and lanes
    params:add_binary("osc_sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("osc_sync_all_clocks", function()
        clock.run(function()
            -- Cancel all existing OSC clocks
            for clock_id, _ in pairs(active_trigger_clocks) do
                if active_trigger_clocks[clock_id] then
                    clock.cancel(active_trigger_clocks[clock_id])
                    active_trigger_clocks[clock_id] = nil
                end
            end

            for clock_id, _ in pairs(active_lfo_sync_clocks) do
                if active_lfo_sync_clocks[clock_id] then
                    clock.cancel(active_lfo_sync_clocks[clock_id])
                    active_lfo_sync_clocks[clock_id] = nil
                end
            end



            -- Sync to next whole beat
            local current_beat = math.floor(clock.get_beats())
            local next_beat = current_beat + 1
            local beats_to_wait = next_beat - clock.get_beats()
            clock.sync(beats_to_wait)

            -- Restart all OSC clocks fresh
            for i = 1, 4 do
                send_lfo_frequency(i)
                update_trigger_clock(i)
            end

            -- Sync all lanes to ensure they're aligned with the global sync
            if _seeker and _seeker.conductor then
                _seeker.conductor.sync_lanes()
            end
        end)
    end)

    -- Output Selection params
    params:add_separator("osc_output_selection", "Output Selection")
    params:add_option("osc_selected_type", "Type", {"Float", "LFO", "Trigger"}, 1)
    params:set_action("osc_selected_type", function(value)
        if _seeker and _seeker.osc_config then
            _seeker.osc_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    params:add_option("osc_selected_number", "Number", {"1", "2", "3", "4"}, 1)
    params:set_action("osc_selected_number", function(value)
        if _seeker and _seeker.osc_config then
            _seeker.osc_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
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

    -- Float outputs (1-4)
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
    
    -- LFO parameters (4 LFOs)
    for i = 1, 4 do
        params:add_option("osc_lfo_" .. i .. "_sync", "LFO " .. i .. " Sync", sync_options, 1)
        params:set_action("osc_lfo_" .. i .. "_sync", function(value)
            send_lfo_frequency(i)
        end)

        params:add_option("osc_lfo_" .. i .. "_shape", "LFO " .. i .. " Shape", lfo_shape_options, 1)
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
    
    -- Trigger parameters (4 triggers)
    for i = 1, 4 do
        params:add_option("osc_trigger_" .. i .. "_sync", "Trigger " .. i .. " Sync", sync_options, 1)
        params:set_action("osc_trigger_" .. i .. "_sync", function(value)
            update_trigger_clock(i)
        end)

        -- Envelope parameters (percentages)
        params:add_control("osc_trigger_" .. i .. "_env_gate_length", "Trigger " .. i .. " Gate Length", controlspec.new(1.0, 99.0, 'lin', 0.1, 50.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_env_gate_length", function(value)
            -- Restart trigger if it's running to apply new gate length
            if active_trigger_clocks["trigger_" .. i] then
                update_trigger_clock(i)
            end
        end)

        params:add_control("osc_trigger_" .. i .. "_attack", "Trigger " .. i .. " Attack", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_attack", function(value)
            normalize_envelope_if_needed(i)
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_decay", "Trigger " .. i .. " Decay", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_decay", function(value)
            normalize_envelope_if_needed(i)
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_min_sustain", "Trigger " .. i .. " Min Sustain", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_min_sustain", function(value)
            normalize_envelope_if_needed(i)
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_env_min", "Trigger " .. i .. " Min", controlspec.new(-10.0, 10.0, 'lin', 0.01, 0.0))
        params:set_action("osc_trigger_" .. i .. "_env_min", function(value)
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_env_max", "Trigger " .. i .. " Max", controlspec.new(-10.0, 10.0, 'lin', 0.01, 10.0))
        params:set_action("osc_trigger_" .. i .. "_env_max", function(value)
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_release", "Trigger " .. i .. " Release", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_release", function(value)
            normalize_envelope_if_needed(i)
            send_trigger_envelope(i)
        end)

        params:add_number("osc_trigger_" .. i .. "_env_multiplier", "Trigger " .. i .. " Multiplier", -100, 100, 1)
        params:set_action("osc_trigger_" .. i .. "_env_multiplier", function(value)
            send_trigger_envelope(i)
        end)
    end
end

-- Helper function to convert division string to beats (same as eurorack_output.lua)
local function division_to_beats(div)
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
    
    return 1
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
    osc.send(dest, path, args)
    return true
end

-- Send LFO frequency
function send_lfo_frequency(lfo_index)
    local sync_div = params:string("osc_lfo_" .. lfo_index .. "_sync")
    local frequency = sync_to_frequency(sync_div)

    -- Stop existing LFO sync clock if any
    if active_lfo_sync_clocks["lfo_" .. lfo_index] then
        clock.cancel(active_lfo_sync_clocks["lfo_" .. lfo_index])
        active_lfo_sync_clocks["lfo_" .. lfo_index] = nil
    end

    if frequency > 0 then
        -- Send frequency for TouchDesigner LFO rate
        local path = "/lfo/" .. lfo_index .. "/freq"
        send_osc_message(path, {frequency})

        -- Send sync pulse on next beat boundary
        local beats = division_to_beats(sync_div)
        local function send_single_sync_pulse()
            clock.sync(beats)  -- Wait for next sync point
            local sync_path = "/lfo/" .. lfo_index .. "/sync"

            -- Send pulse high
            send_osc_message(sync_path, {1})

            -- Wait 250ms then send pulse low
            clock.sleep(0.25)
            send_osc_message(sync_path, {0})
        end

        -- Start single-shot sync pulse
        active_lfo_sync_clocks["lfo_" .. lfo_index] = clock.run(send_single_sync_pulse)

        return frequency
    else
        -- Send 0 to stop TouchDesigner LFO when "Off"
        local path = "/lfo/" .. lfo_index .. "/freq"
        send_osc_message(path, {0})
        return 0
    end
end

-- Send LFO min/max range
function send_lfo_range(lfo_index)
    local min_val = params:get("osc_lfo_" .. lfo_index .. "_min")
    local max_val = params:get("osc_lfo_" .. lfo_index .. "_max")

    local min_path = "/lfo/" .. lfo_index .. "/min"
    local max_path = "/lfo/" .. lfo_index .. "/max"

    send_osc_message(min_path, {min_val})
    send_osc_message(max_path, {max_val})
end

-- Send LFO shape type (as integer: 0=Sine, 1=Gaussian, 2=Triangle, 3=Ramp, 4=Square, 5=Pulse)
function send_lfo_shape(lfo_index)
    local shape_index = params:get("osc_lfo_" .. lfo_index .. "_shape") - 1  -- Convert to 0-indexed
    local path = "/lfo/" .. lfo_index .. "/shape"
    send_osc_message(path, {shape_index})
end

-- Send float value
function send_float_value(index, value)
    local path = "/float/" .. index .. "/value"
    send_osc_message(path, {value})
    return value
end

-- Send float multiplier
function send_float_multiplier(index)
    local multiplier = params:get("osc_float_" .. index .. "_multiplier")
    local path = "/float/" .. index .. "/multiplier"
    send_osc_message(path, {multiplier})
    return multiplier
end

-- Send trigger envelope parameters
function send_trigger_envelope(trigger_index)
    local attack_pct = params:get("osc_trigger_" .. trigger_index .. "_attack")
    local decay_pct = params:get("osc_trigger_" .. trigger_index .. "_decay")
    local min_sustain_pct = params:get("osc_trigger_" .. trigger_index .. "_min_sustain")
    local release_pct = params:get("osc_trigger_" .. trigger_index .. "_release")
    local env_min = params:get("osc_trigger_" .. trigger_index .. "_env_min")
    local env_max = params:get("osc_trigger_" .. trigger_index .. "_env_max")
    local multiplier = params:get("osc_trigger_" .. trigger_index .. "_env_multiplier")

    -- Normalize percentages to fractions that sum to 1.0
    local total = attack_pct + decay_pct + min_sustain_pct + release_pct
    local attack_frac = total > 0 and (attack_pct / total) or 0.25
    local decay_frac = total > 0 and (decay_pct / total) or 0.25
    local min_sustain_frac = total > 0 and (min_sustain_pct / total) or 0.25
    local release_frac = total > 0 and (release_pct / total) or 0.25

    send_osc_message("/trigger/" .. trigger_index .. "/attack", {attack_frac})
    send_osc_message("/trigger/" .. trigger_index .. "/decay", {decay_frac})
    send_osc_message("/trigger/" .. trigger_index .. "/min_sustain", {min_sustain_frac})
    send_osc_message("/trigger/" .. trigger_index .. "/release", {release_frac})
    send_osc_message("/trigger/" .. trigger_index .. "/min", {env_min})
    send_osc_message("/trigger/" .. trigger_index .. "/max", {env_max})
    send_osc_message("/trigger/" .. trigger_index .. "/multiplier", {multiplier})
end

-- Send trigger pulse with explicit value
function send_trigger_pulse(trigger_index, value)
    local path = "/trigger/" .. trigger_index .. "/pulse"
    send_osc_message(path, {value})
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
        return
    end
    
    -- Create clock function for trigger pulses (Envelope mode only)
    local function trigger_clock_function()
        -- Track tempo for sub-beat gate timing
        local current_beat_sec = clock.get_beat_sec()

        while true do
            -- Sync to beat boundary (tempo-tracked automatically)
            clock.sync(beats)

            -- Poll for tempo changes each iteration
            local new_beat_sec = clock.get_beat_sec()
            if new_beat_sec ~= current_beat_sec then
                current_beat_sec = new_beat_sec
            end

            -- Get current gate length parameter
            local gate_length = params:get("osc_trigger_" .. trigger_index .. "_env_gate_length") / 100

            -- Send high pulse
            send_trigger_pulse(trigger_index, 1)

            -- Sub-beat gate timing using current tempo
            local gate_time_sec = beats * gate_length * current_beat_sec
            clock.sleep(gate_time_sec)

            -- Send low pulse
            send_trigger_pulse(trigger_index, 0)

            -- Loop continues - next sync will align to next beat boundary
        end
    end
    
    -- Start the trigger clock
    active_trigger_clocks["trigger_" .. trigger_index] = clock.run(trigger_clock_function)
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
            { separator = true, title = "Actions" },
            { id = "osc_sync_all_clocks", is_action = true },
            { separator = true, title = "Output Selection" },
            { id = "osc_selected_type" },
            { id = "osc_selected_number" }
        }
    })

    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        original_enter(self)
        self:rebuild_params()
    end

    -- Dynamic parameter rebuilding based on selected type and number
    norns_ui.rebuild_params = function(self)
        local selected_type = params:string("osc_selected_type")
        local selected_number = params:get("osc_selected_number")

        local param_table = {
            { separator = true, title = "Actions" },
            { id = "osc_sync_all_clocks", is_action = true },
            { separator = true, title = "Output Selection" },
            { id = "osc_selected_type" },
            { id = "osc_selected_number" }
        }

        -- Build type-specific parameters
        if selected_type == "Float" then
            table.insert(param_table, { id = "osc_float_" .. selected_number .. "_value", name = "Value", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_float_" .. selected_number .. "_multiplier", name = "Multiplier" })
        elseif selected_type == "LFO" then
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_sync", name = "Sync" })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_shape", name = "Shape" })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_min", name = "Min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_max", name = "Max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif selected_type == "Trigger" then
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_sync", name = "Sync" })
            table.insert(param_table, { separator = true, title = "Shape" })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_env_gate_length", name = "Gate Length", arc_multi_float = {10.0, 1.0, 0.1} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_attack", name = "Attack", arc_multi_float = {10.0, 1.0, 0.1} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_decay", name = "Decay", arc_multi_float = {10.0, 1.0, 0.1} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_min_sustain", name = "Min Sustain", arc_multi_float = {10.0, 1.0, 0.1} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_release", name = "Release", arc_multi_float = {10.0, 1.0, 0.1} })
            table.insert(param_table, { separator = true, title = "Range" })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_env_min", name = "Min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_env_max", name = "Max", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_env_multiplier", name = "Multiplier" })
        end

        -- Add connection configuration at the end
        table.insert(param_table, { separator = true, title = "Connection" })
        table.insert(param_table, { id = "osc_dest_octet_1" })
        table.insert(param_table, { id = "osc_dest_octet_2" })
        table.insert(param_table, { id = "osc_dest_octet_3" })
        table.insert(param_table, { id = "osc_dest_octet_4" })
        table.insert(param_table, { id = "osc_dest_port" })
        table.insert(param_table, { separator = true, title = "Test" })
        table.insert(param_table, { id = "osc_test_trigger", is_action = true })

        self.params = param_table
    end

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
        send_lfo_range = send_lfo_range,
        send_lfo_shape = send_lfo_shape,
        send_float_value = send_float_value,
        send_float_multiplier = send_float_multiplier,
        send_trigger_envelope = send_trigger_envelope,
        send_trigger_pulse = send_trigger_pulse,
        update_trigger_clock = update_trigger_clock
    }
    create_params()

    -- Listen for tempo changes and update LFO frequencies
    params:set_action("clock_tempo", function(value)
        update_all_lfo_frequencies()
    end)

    return component
end

return OscConfig
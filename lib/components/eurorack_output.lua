-- eurorack_output.lua
-- Self-contained component for Eurorack Output functionality following stage_config.lua pattern

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local EurorackOutput = {}
EurorackOutput.__index = EurorackOutput

-- Configuration constants
local sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}
local shape_options = {"sine", "linear", "now", "wait", "over", "under", "rebound"}

-- Store active clock IDs globally
local active_clocks = {}

-- Store envelope states globally
local envelope_states = {}

-- Store knob recording state for each output locally to this component
local recording_states = {}

-- Initialize recording states for all 4 crow outputs
for i = 1, 4 do
    recording_states[i] = {
        active = false,
        voltage = 0,
        data = {},
        sensitivity = 0.1,
        interpolation_steps = 5,
        clock_interval = 0.05,
        capture_clock = nil
    }
end

-- Initialize envelope states for all 4 crow outputs
for i = 1, 4 do
    envelope_states[i] = {
        active = false,
        clock = nil
    }
end

-- Helper function to reset recording state for a specific output
local function reset_recording_state(output_num)
    recording_states[output_num] = {
        active = false,
        voltage = 0,
        data = {},
        sensitivity = 0.1,
        interpolation_steps = 5,
        clock_interval = 0.05,
        capture_clock = nil
    }
end

local function create_params()
    -- TODO: Count the params.
    params:add_group("eurorack_output", "EURORACK OUTPUT", 161)
    
    -- Output Selection
    params:add_option("selected_output", "Output", {
        "Crow 1", "Crow 2", "Crow 3", "Crow 4",
        "TXO TR 1", "TXO TR 2", "TXO TR 3", "TXO TR 4",
        "TXO CV 1", "TXO CV 2", "TXO CV 3", "TXO CV 4"
    }, 1)
    params:set_action("selected_output", function(value)
        if _seeker and _seeker.eurorack_output then
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end
    end)

    -- Crow outputs (1-4)
    for i = 1, 4 do
        params:add_option("crow_" .. i .. "_type", "Type", {"Gate", "Burst", "LFO", "Envelope", "Knob Recorder", "Looped Random", "Clocked Random"}, 1)
        params:set_action("crow_" .. i .. "_type", function(value)
            EurorackOutput.update_crow(i)
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        params:add_option("crow_" .. i .. "_clock_div", "Clock Mod", sync_options, 1)
        params:set_action("crow_" .. i .. "_clock_div", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- Burst parameters
        params:add_control("crow_" .. i .. "_burst_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.1, 0))
        params:set_action("crow_" .. i .. "_burst_voltage", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_burst_count", "Burst Count", 1, 16, 1)
        params:set_action("crow_" .. i .. "_burst_count", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_burst_time", "Burst Window", controlspec.new(0.01, 1, 'lin', 0.01, 0.1))
        params:set_action("crow_" .. i .. "_burst_time", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- Gate parameters
        params:add_control("crow_" .. i .. "_gate_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.1, 0))
        params:set_action("crow_" .. i .. "_gate_voltage", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_gate_length", "Gate Length %", 1, 100, 50)
        params:set_action("crow_" .. i .. "_gate_length", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- LFO parameters
        params:add_option("crow_" .. i .. "_lfo_shape", "CV Shape", shape_options, 1)
        params:set_action("crow_" .. i .. "_lfo_shape", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_lfo_min", "CV Min", controlspec.new(-10, 10, 'lin', 0.1, -5))
        params:set_action("crow_" .. i .. "_lfo_min", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_lfo_max", "CV Max", controlspec.new(-10, 10, 'lin', 0.1, 5))
        params:set_action("crow_" .. i .. "_lfo_max", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- Looped Random parameters
        params:add_option("crow_" .. i .. "_looped_random_shape", "Shape", shape_options, 3)
        params:set_action("crow_" .. i .. "_looped_random_shape", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_option("crow_" .. i .. "_looped_random_quantize", "Quantize", {"On", "Off"}, 2)
        params:set_action("crow_" .. i .. "_looped_random_quantize", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_looped_random_steps", "Steps", 1, 32, 1)
        params:set_action("crow_" .. i .. "_looped_random_steps", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_looped_random_loops", "Loops", 1, 32, 1)
        params:set_action("crow_" .. i .. "_looped_random_loops", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_looped_random_min", "Min Value", controlspec.new(-10, 10, 'lin', 0.1, -5))
        params:set_action("crow_" .. i .. "_looped_random_min", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_looped_random_max", "Max Value", controlspec.new(-10, 10, 'lin', 0.1, 5))
        params:set_action("crow_" .. i .. "_looped_random_max", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- Clocked Random parameters
        params:add_number("crow_" .. i .. "_clocked_random_trigger", "Crow Input", 0, 2, 0)
        params:set_action("crow_" .. i .. "_clocked_random_trigger", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_option("crow_" .. i .. "_clocked_random_shape", "Shape", shape_options, 3)
        params:set_action("crow_" .. i .. "_clocked_random_shape", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_option("crow_" .. i .. "_clocked_random_quantize", "Quantize", {"On", "Off"}, 2)
        params:set_action("crow_" .. i .. "_clocked_random_quantize", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_clocked_random_min", "Min Value", controlspec.new(-10, 10, 'lin', 0.1, -5))
        params:set_action("crow_" .. i .. "_clocked_random_min", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_clocked_random_max", "Max Value", controlspec.new(-10, 10, 'lin', 0.1, 5))
        params:set_action("crow_" .. i .. "_clocked_random_max", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        -- Knob Recorder parameters
        params:add_control("crow_" .. i .. "_knob_sensitivity", "Sensitivity", controlspec.new(0.01, 1.0, 'lin', 0.01, 0.1))
        params:set_action("crow_" .. i .. "_knob_sensitivity", function(value)
            recording_states[i].sensitivity = value
        end)
        
        params:add_binary("crow_" .. i .. "_knob_recording", "Record", "toggle", 0)
        params:set_action("crow_" .. i .. "_knob_recording", function(value)
            if value == 1 then
                EurorackOutput.record_knob(i)
            else
                EurorackOutput.stop_recording_knob(i)
            end
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        params:add_binary("crow_" .. i .. "_knob_clear", "Clear", "trigger", 0)
        params:set_action("crow_" .. i .. "_knob_clear", function(value)
            EurorackOutput.clear_knob(i)
            _seeker.screen_ui.set_needs_redraw()
        end)

        -- Envelope parameters
        params:add_option("crow_" .. i .. "_envelope_mode", "Envelope Mode", {"ADSR", "AR"}, 1)
        params:set_action("crow_" .. i .. "_envelope_mode", function(value)
            EurorackOutput.update_crow(i)
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        params:add_control("crow_" .. i .. "_envelope_voltage", "Max Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5))
        params:set_action("crow_" .. i .. "_envelope_voltage", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_envelope_duration", "Duration", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_duration", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_envelope_attack", "Attack", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_attack", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_envelope_decay", "Decay", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_decay", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_control("crow_" .. i .. "_envelope_sustain", "Sustain Level", controlspec.new(0, 100, 'lin', 1, 50, '%'))
        params:set_action("crow_" .. i .. "_envelope_sustain", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_number("crow_" .. i .. "_envelope_release", "Release", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_release", function(value)
            EurorackOutput.update_crow(i)
        end)
        
        params:add_option("crow_" .. i .. "_envelope_shape", "Envelope Shape", shape_options, 2)
        params:set_action("crow_" .. i .. "_envelope_shape", function(value)
            EurorackOutput.update_crow(i)
        end)
    end

    -- TXO TR outputs (1-4)
    for i = 1, 4 do
        params:add_option("txo_tr_" .. i .. "_type", "Type", {"Gate", "Burst", "Stepped Random"}, 1)
        params:set_action("txo_tr_" .. i .. "_type", function(value)
            EurorackOutput.update_txo_tr(i)
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        params:add_option("txo_tr_" .. i .. "_clock_div", "Beat Div/Mult", sync_options, 1)
        params:set_action("txo_tr_" .. i .. "_clock_div", function(value)
            EurorackOutput.update_txo_tr(i)
        end)
        
        -- Burst parameters
        params:add_number("txo_tr_" .. i .. "_burst_count", "Burst Count", 1, 16, 1)
        params:set_action("txo_tr_" .. i .. "_burst_count", function(value)
            EurorackOutput.update_txo_tr(i)
        end)
        
        params:add_control("txo_tr_" .. i .. "_burst_time", "Burst Time", controlspec.new(0.01, 1, 'lin', 0.01, 0.1))
        params:set_action("txo_tr_" .. i .. "_burst_time", function(value)
            EurorackOutput.update_txo_tr(i)
        end)
        
        -- Gate parameters
        params:add_number("txo_tr_" .. i .. "_gate_length", "Gate Length %", 1, 100, 50)
        params:set_action("txo_tr_" .. i .. "_gate_length", function(value)
            EurorackOutput.update_txo_tr(i)
        end)
    end

    -- TXO CV outputs (1-4)
    for i = 1, 4 do
        params:add_option("txo_cv_" .. i .. "_type", "Type", {"LFO", "Stepped Random"}, 1)
        params:set_action("txo_cv_" .. i .. "_type", function(value)
            EurorackOutput.update_txo_cv(i)
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        -- LFO parameters
        params:add_option("txo_cv_" .. i .. "_sync", "Clock Mod", sync_options, 1)
        params:set_action("txo_cv_" .. i .. "_sync", function(value)
            EurorackOutput.update_txo_cv(i)
            _seeker.eurorack_output.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)
        
        params:add_option("txo_cv_" .. i .. "_shape", "Shape", {"Sine", "Triangle", "Saw", "Pulse", "Noise"}, 1)
        params:set_action("txo_cv_" .. i .. "_shape", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_number("txo_cv_" .. i .. "_morph", "Morph", -50, 50, 0)
        params:set_action("txo_cv_" .. i .. "_morph", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_control("txo_cv_" .. i .. "_depth", "Dep th", controlspec.new(0, 10, 'lin', 0.1, 2.5))
        params:set_action("txo_cv_" .. i .. "_depth", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_control("txo_cv_" .. i .. "_offset", "Offset", controlspec.new(-5, 5, 'lin', 0.1, 0))
        params:set_action("txo_cv_" .. i .. "_offset", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_number("txo_cv_" .. i .. "_phase", "Phase", 0, 360, 0)
        params:set_action("txo_cv_" .. i .. "_phase", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_option("txo_cv_" .. i .. "_rect", "Rect", {"Negative Half", "Negative Clipped", "Full Range", "Positive Clipped", "Positive Half"}, 3)
        params:set_action("txo_cv_" .. i .. "_rect", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        -- Stepped Random parameters
        params:add_control("txo_cv_" .. i .. "_random_min", "Min Value", controlspec.new(-10, 10, 'lin', 0.1, -5))
        params:set_action("txo_cv_" .. i .. "_random_min", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_control("txo_cv_" .. i .. "_random_max", "Max Value", controlspec.new(-10, 10, 'lin', 0.1, 5))
        params:set_action("txo_cv_" .. i .. "_random_max", function(value)
            EurorackOutput.update_txo_cv(i)
        end)
        
        params:add_binary("txo_cv_" .. i .. "_restart", "Restart", "trigger", 0)
        params:set_action("txo_cv_" .. i .. "_restart", function(value)
            -- Restart all TXO CV LFOs
            for j = 1, 4 do
                EurorackOutput.update_txo_cv(j)
            end
            print("⚡ Restarted all LFOs")
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "EURORACK_OUTPUT",
        name = "Eurorack Output",
        description = "Configure Crow outputs for clock pulses and LFOs",
        params = {
            { separator = true, title = "Output Selection" },
            { id = "selected_output" }
        }
    })
    
    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        original_enter(self)
        self:rebuild_params()
    end
    
    -- Dynamic parameter rebuilding based on selected output and type
    norns_ui.rebuild_params = function(self)
        local selected_output = params:string("selected_output")
        
        local param_table = {
            { separator = true, title = "Output Selection" },
            { id = "selected_output" }
        }
        
        if selected_output:match("^Crow") then
            -- Get the output number (1-4)
            local output_num = tonumber(selected_output:match("%d+"))
            local type = params:string("crow_" .. output_num .. "_type")
            
            -- Add type parameter
            table.insert(param_table, { id = "crow_" .. output_num .. "_type" })
            
            -- Add clock mod parameter for all types except Clocked Random and Knob Recorder
            if type ~= "Clocked Random" and type ~= "Knob Recorder" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_clock_div" })
            end
            
            -- Add type-specific parameters
            if type == "Burst" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_burst_voltage" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_burst_count" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_burst_time" })
            elseif type == "Gate" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_gate_voltage" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_gate_length" })
            elseif type == "LFO" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_shape" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_min" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_max" })
            elseif type == "Looped Random" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_shape" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_quantize" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_steps" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_loops" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_min" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_max" })
            elseif type == "Clocked Random" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_trigger" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_shape" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_quantize" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_min" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_max" })
            elseif type == "Knob Recorder" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_knob_sensitivity" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_knob_recording",  is_action = true})
                table.insert(param_table, { id = "crow_" .. output_num .. "_knob_clear", is_action = true})
            elseif type == "Envelope" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_mode" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_voltage", arc_multi_float = true })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_duration" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_attack" })
                
                -- Only show decay and sustain for ADSR mode
                local mode = params:string("crow_" .. output_num .. "_envelope_mode")
                if mode == "ADSR" then
                    table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_decay" })
                    table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_sustain" })
                end
                
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_release" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_shape" })
            end
            
        elseif selected_output:match("^TXO TR") then
            -- Extract the output number (1-4)
            local output_num = tonumber(selected_output:match("%d+"))
            local type = params:string("txo_tr_" .. output_num .. "_type")
            
            -- Add type parameter
            table.insert(param_table, { id = "txo_tr_" .. output_num .. "_type" })
            
            -- Add type-specific parameters
            if type == "Burst" then
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_div" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_count" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_burst_time" })
            elseif type == "Gate" then
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_clock_div" })
                table.insert(param_table, { id = "txo_tr_" .. output_num .. "_gate_length" })
            end
            
        elseif selected_output:match("^TXO CV") then
            -- Extract the output number (1-4)
            local output_num = tonumber(selected_output:match("%d+"))
            local type = params:string("txo_cv_" .. output_num .. "_type")
            
            -- Add type parameter
            table.insert(param_table, { id = "txo_cv_" .. output_num .. "_type" })
            
            if type == "LFO" then
                local sync = params:string("txo_cv_" .. output_num .. "_sync")
                
                -- Add sync parameter
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_sync" })
                
                -- Add shape and morph
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_shape" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_morph" })
                
                -- Add depth
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_depth" })
                
                -- Add remaining LFO parameters
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_offset" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_phase" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_rect" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
            elseif type == "Stepped Random" then
                -- Stepped Random mode parameters
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_sync" })
                
                -- Enforce that Stepped Random mode must be synced to clock
                if params:string("txo_cv_" .. output_num .. "_sync") == "Off" then
                    params:set("txo_cv_" .. output_num .. "_sync", 9) -- Set to "1/8"
                end
                
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_min" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_random_max" })
                table.insert(param_table, { id = "txo_cv_" .. output_num .. "_restart" })
            end
        end
        
        -- Update the UI with the new parameter table
        self.params = param_table
    end
    
    return norns_ui
end

local function create_grid_ui()
    return GridUI.new({
        id = "EURORACK_OUTPUT",
        layout = {
            x = 15,
            y = 2,
            width = 1,
            height = 1
        }
    })
end

function EurorackOutput.handle_encoder_input(delta)
    -- Check if any output is currently recording
    for output_num = 1, 4 do
        local state = recording_states[output_num]
        if state.active then
            -- Get sensitivity from parameter
            local sensitivity = params:get("crow_" .. output_num .. "_knob_sensitivity")
            
            -- Update voltage based on encoder delta
            state.voltage = state.voltage + (delta * sensitivity)
            
            -- Clamp voltage to ±10V
            state.voltage = util.clamp(state.voltage, -10, 10)
            
            -- Send voltage to Crow immediately
            crow.output[output_num].volts = state.voltage
        end
    end
end

function EurorackOutput.record_knob(output_num)
    -- Stop any existing playback for this output
    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end
    
    -- Get the recording state for this output
    local state = recording_states[output_num]
    
    -- Set up recording state for this output
    state.active = true
    state.voltage = 0 
    state.data = {}
    
    -- Set global flag for UI interception (if any output is recording)
    _seeker.ui_state.state.knob_recording_active = true
    
    -- Start 50ms capture timer for this output
    state.capture_clock = clock.run(function()
        while state.active do
            -- Capture current voltage
            table.insert(state.data, state.voltage)
            
            -- Live output to crow
            crow.output[output_num].volts = state.voltage

            -- Wait 50ms
            clock.sleep(state.clock_interval)
        end
    end)
end

function EurorackOutput.stop_recording_knob(output_num)
    -- Get the recording state for this output
    local state = recording_states[output_num]
    
    -- Stop recording for this output
    state.active = false
    
    -- Check if any other outputs are still recording
    local any_recording = false
    for i = 1, 4 do
        if recording_states[i].active then
            any_recording = true
            break
        end
    end
    
    -- Only clear global flag if no outputs are recording
    if not any_recording then
        _seeker.ui_state.state.knob_recording_active = false
    end
    
    -- Stop capture timer for this output
    if state.capture_clock then
        clock.cancel(state.capture_clock)
        state.capture_clock = nil
    end
    
    -- Get the recorded data
    local data = state.data
    
    -- Kick off clock to play back the recorded data
    if #data > 0 then
        active_clocks["knob_playback_" .. output_num] = clock.run(function()
            local step = 1
            local substep = 0
            local interpolation_steps = state.interpolation_steps
            
            -- TODO: Investigate performance implications of this
            while true do
                -- Get current and next voltage values
                local current_voltage = data[step]
                local next_step = (step % #data) + 1
                local next_voltage = data[next_step]
                
                -- Linear interpolation between current and next
                local interpolated_voltage = current_voltage + 
                    (next_voltage - current_voltage) * (substep / interpolation_steps)
                
                -- Set interpolated voltage
                crow.output[output_num].volts = interpolated_voltage
                
                -- Advance substep
                substep = substep + 1
                if substep >= interpolation_steps then
                    substep = 0
                    step = next_step
                end
                
                -- Wait 10ms (50ms / 5 substeps)
                clock.sleep(0.01)
            end
        end)
    end
    
    -- Clear recording state for this output
    reset_recording_state(output_num)
end

function EurorackOutput.clear_knob(output_num)
    -- Stop any existing playback for this output
    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end
    
    -- Clear the recorded data for this output
    recording_states[output_num].data = {}
    
    -- Set the voltage to 0
    crow.output[output_num].volts = 0
    
    -- Clear the UI
    _seeker.screen_ui.set_needs_redraw()
end

-- Helper function to convert division string to beats
function EurorackOutput.division_to_beats(div)
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

-- Update crow output when a parameter changes
function EurorackOutput.update_crow(output_num)
    -- Stop existing clock if any
    if active_clocks["crow_" .. output_num] then
        clock.cancel(active_clocks["crow_" .. output_num])
        active_clocks["crow_" .. output_num] = nil
    end
    
    -- Stop any knob playback for this output
    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end

    -- Get clock parameters
    local type = params:string("crow_" .. output_num .. "_type")
    
    -- Handle LFO mode
    if type == "LFO" then
        local clock_mod = params:string("crow_" .. output_num .. "_clock_div")
        local shape = params:string("crow_" .. output_num .. "_lfo_shape")
        local min = params:get("crow_" .. output_num .. "_lfo_min")
        local max = params:get("crow_" .. output_num .. "_lfo_max")
        
        -- Convert clock division to beats
        local beats = EurorackOutput.division_to_beats(clock_mod)
        
        -- If division is 0 or invalid, turn off the LFO
        if beats <= 0 or clock_mod == "Off" then
            crow.output[output_num].volts = 0
            return
        end
        
        -- Convert beats to seconds based on current tempo
        local beat_sec = clock.get_beat_sec()
        local time = beat_sec * beats
        
        -- Construct ASL string with dynamic values
        local asl_string = string.format("loop( { to(%f,%f,'%s'), to(%f,%f,'%s') } )", 
            min, time, shape, 
            max, time, shape)
        
        -- Set up LFO using Crow's ASL system
        crow.output[output_num].action = asl_string
        
        -- Start the LFO
        crow.output[output_num]()
        return
    end

    -- Handle Looped Random mode
    if type == "Looped Random" then
        local trigger = params:string("crow_" .. output_num .. "_clock_div")
        local shape = params:string("crow_" .. output_num .. "_looped_random_shape")
        local quantize = params:string("crow_" .. output_num .. "_looped_random_quantize")
        local steps = params:get("crow_" .. output_num .. "_looped_random_steps")
        local loops = params:get("crow_" .. output_num .. "_looped_random_loops")
        local min = params:get("crow_" .. output_num .. "_looped_random_min")
        local max = params:get("crow_" .. output_num .. "_looped_random_max")
        
        -- If division is "off", turn off the output
        if trigger == "Off" then
            crow.output[output_num].volts = 0
            return
        end

        -- Convert trigger division to beats
        local trigger_beats = EurorackOutput.division_to_beats(trigger)
        local beat_sec = clock.get_beat_sec()
        local time = beat_sec * trigger_beats

        -- Set up scale quantization if enabled
        if quantize == "On" then
            -- Get scale from params
            local scale = params:get("scale_type")
            local root = params:get("root_note")
            -- Apply scale quantization to the output
            crow.output[output_num].scale(scale) -- 12TET, 1V/octave
        else
            -- Disable scale quantization
            crow.output[output_num].scale('none')
        end

        -- Function to generate and set new ASL pattern
        local function generate_asl_pattern()
            local asl_steps = {}
            for i = 1, steps do
                -- Generate a random value between min and max
                local random_value = min + math.random() * (max - min)
                -- Construct an asl string
                local asl_step = string.format("to(%f, %f, '%s')", random_value, time, shape)
                table.insert(asl_steps, asl_step)
            end

            -- Create the final ASL loop string
            local asl_loop = string.format("loop( { %s } )", table.concat(asl_steps, ", "))

            -- Set action on Crow
            crow.output[output_num].action = asl_loop
            crow.output[output_num]()
        end
        
        -- Create clock function that regenerates pattern
        local function clock_function()
            while true do
                -- Generate initial pattern
                generate_asl_pattern()
                
                -- Wait for complete cycle (steps * loops * trigger_beats)
                local cycle_beats = steps * loops * trigger_beats
                clock.sync(cycle_beats)
            end
        end
        
        -- Start the clock
        active_clocks["crow_" .. output_num] = clock.run(clock_function)
        return
    end
    
    -- Handle Clocked Random mode
    if type == "Clocked Random" then
        local input_number = params:get("crow_" .. output_num .. "_clocked_random_trigger")
        local min_value = params:get("crow_" .. output_num .. "_clocked_random_min")
        local max_value = params:get("crow_" .. output_num .. "_clocked_random_max")
        local shape = params:string("crow_" .. output_num .. "_clocked_random_shape")
        local quantize = params:string("crow_" .. output_num .. "_clocked_random_quantize")
        
        -- Function to generate and set new random value
        local function generate_random_value()
            local random_value
            if quantize == "On" then
                random_value = math.random(min_value, max_value)
            else
                random_value = min_value + math.random() * (max_value - min_value)
            end
            
            -- Create ASL string for the transition
            local asl_string = string.format("to(%f,0.1,'%s')", random_value, shape)
            crow.output[output_num].action = asl_string
            crow.output[output_num]()
        end
        
        -- Stop any existing clock or input handler
        if active_clocks["crow_" .. output_num] then
            clock.cancel(active_clocks["crow_" .. output_num])
            active_clocks["crow_" .. output_num] = nil
        end
        
        -- Set up input handlers for Crow 1 and 2
        if input_number == 1 or input_number == 2 then
            -- Configure input to trigger on rising edge
            crow.input[input_number].mode('change', 1.0, 0.1, 'rising')
            
            -- Set up the change handler
            crow.input[input_number].change = function(state)
                if state then
                    generate_random_value()
                end
            end
            
            -- Generate initial value
            generate_random_value()
        end
        return
    end

    if type == "Burst" then
        local div = params:string("crow_" .. output_num .. "_clock_div")
        local beats = EurorackOutput.division_to_beats(div)
        
        if beats == 0 then
            crow.output[output_num].volts = 0
            return
        end

        -- Create clock function for burst mode
        local clock_fn = function()
            while true do
                local burst_voltage = params:get("crow_" .. output_num .. "_burst_voltage")
                local burst_count = params:get("crow_" .. output_num .. "_burst_count")
                local burst_time = params:get("crow_" .. output_num .. "_burst_time")
                
                -- Send burst of pulses
                for i = 1, burst_count do
                    crow.output[output_num].volts = burst_voltage
                    clock.sleep(burst_time / burst_count)
                    crow.output[output_num].volts = 0
                    clock.sleep(burst_time / burst_count)
                end
                
                -- Wait for next interval
                clock.sync(beats)
            end
        end
        
        -- Start the clock
        active_clocks["crow_" .. output_num] = clock.run(clock_fn)
        return
    end

    if type == "Gate" then
        local div = params:string("crow_" .. output_num .. "_clock_div")
        local beats = EurorackOutput.division_to_beats(div)
        
        if beats == 0 then
            crow.output[output_num].volts = 0
            return
        end

        -- Create clock function for gate mode
        local clock_fn = function()
            while true do
                local gate_voltage = params:get("crow_" .. output_num .. "_gate_voltage")
                local gate_length = params:get("crow_" .. output_num .. "_gate_length") / 100
                local beat_sec = clock.get_beat_sec()
                local gate_time = beat_sec * beats * gate_length
                
                -- Send gate pulse
                crow.output[output_num].volts = gate_voltage
                clock.sleep(gate_time)
                crow.output[output_num].volts = 0
                
                -- Wait for next interval
                clock.sync(beats)
            end
        end
        
        -- Start the clock
        active_clocks["crow_" .. output_num] = clock.run(clock_fn)
        return
    end

    if type == "Envelope" then
        -- Get envelope parameters
        local div = params:string("crow_" .. output_num .. "_clock_div")
        local beats = EurorackOutput.division_to_beats(div)
        
        if beats == 0 then
            crow.output[output_num].volts = 0
            return
        end

        local mode = params:string("crow_" .. output_num .. "_envelope_mode")
        local max_voltage = params:get("crow_" .. output_num .. "_envelope_voltage")
        local duration_percent = params:get("crow_" .. output_num .. "_envelope_duration")
        local attack_percent = params:get("crow_" .. output_num .. "_envelope_attack")
        local decay_percent = params:get("crow_" .. output_num .. "_envelope_decay")
        local sustain_level = params:get("crow_" .. output_num .. "_envelope_sustain") / 100
        local release_percent = params:get("crow_" .. output_num .. "_envelope_release")
        local shape = params:string("crow_" .. output_num .. "_envelope_shape")
        
        -- Reset envelope state
        envelope_states[output_num] = {
            active = false,
            clock = nil
        }
        
        -- Function to generate ASL string based on mode
        local function generate_envelope_asl()
            local sustain_voltage = max_voltage * sustain_level
            local beat_sec = clock.get_beat_sec()
            local cycle_time = beat_sec * beats
            
            -- Calculate the actual duration of the envelope within the cycle
            local envelope_time = cycle_time * (duration_percent / 100)
            
            if mode == "ADSR" then
                -- Calculate stage times as percentages of the envelope duration
                local total_percent = attack_percent + decay_percent + release_percent
                local sustain_percent = math.max(0, 100 - total_percent)
                
                -- Convert percentages to actual times
                local attack_time = envelope_time * (attack_percent / 100)
                local decay_time = envelope_time * (decay_percent / 100)
                local sustain_time = envelope_time * (sustain_percent / 100)
                local release_time = envelope_time * (release_percent / 100)
                
                -- Create ADSR envelope that fits within duration_percent of cycle
                local envelope = string.format(
                    "to(%f,%f,'%s'), to(%f,%f,'%s'), to(%f,%f,'%s'), to(0,%f,'%s')",
                    max_voltage, attack_time, shape,
                    sustain_voltage, decay_time, shape,
                    sustain_voltage, sustain_time, shape,
                    release_time, shape
                )
                
                -- Add wait time to complete the cycle
                local wait_time = cycle_time - envelope_time
                if wait_time > 0 then
                    envelope = envelope .. string.format(", to(0,%f,'now')", wait_time)
                end
                
                return "loop({ " .. envelope .. " })"
                
            else -- AR mode
                -- In AR mode, split the envelope time between attack and release
                local total_percent = attack_percent + release_percent
                local scale_factor = 100 / total_percent
                
                -- Calculate scaled times
                local attack_time = envelope_time * ((attack_percent * scale_factor) / 100)
                local release_time = envelope_time * ((release_percent * scale_factor) / 100)
                
                -- Create AR envelope
                local envelope = string.format(
                    "to(%f,%f,'%s'), to(0,%f,'%s')",
                    max_voltage, attack_time, shape,
                    release_time, shape
                )
                
                -- Add wait time to complete the cycle
                local wait_time = cycle_time - envelope_time
                if wait_time > 0 then
                    envelope = envelope .. string.format(", to(0,%f,'now')", wait_time)
                end
                
                return "loop({ " .. envelope .. " })"
            end
        end
        
        -- Stop any existing clock
        if active_clocks["crow_" .. output_num] then
            clock.cancel(active_clocks["crow_" .. output_num])
            active_clocks["crow_" .. output_num] = nil
        end
        
        -- Set up the envelope with ASL
        local asl_string = generate_envelope_asl()
        crow.output[output_num].action = asl_string
        crow.output[output_num]()
        
        -- Update envelope state
        envelope_states[output_num].active = true
        
        return
    end
end

-- Function to start/stop clock for a specific TXO TR output
function EurorackOutput.update_txo_tr(output_num)
    -- Stop existing clock if any
    if active_clocks["txo_tr_" .. output_num] then
        clock.cancel(active_clocks["txo_tr_" .. output_num])
        active_clocks["txo_tr_" .. output_num] = nil
    end

    -- Get clock parameters
    local type = params:string("txo_tr_" .. output_num .. "_type")
    if type ~= "Burst" and type ~= "Gate" then return end

    local div = params:string("txo_tr_" .. output_num .. "_clock_div")
    local beats = EurorackOutput.division_to_beats(div)
    
    -- If division is 0, just stop the clock
    if beats == 0 then
        crow.ii.txo.tr(output_num, 0)
        return
    end
    
    -- Create clock function
    local function clock_function()
        while true do
            if type == "Burst" then
                -- Burst mode
                local burst_count = params:get("txo_tr_" .. output_num .. "_burst_count")
                local burst_time = params:get("txo_tr_" .. output_num .. "_burst_time")
                
                -- Send burst of pulses using TXO TR commands
                for i = 1, burst_count do
                    crow.ii.txo.tr(output_num, 1) -- Set high
                    clock.sleep(burst_time / burst_count)
                    crow.ii.txo.tr(output_num, 0) -- Set low
                    clock.sleep(burst_time / burst_count)
                end
            else
                -- Gate mode
                local gate_length = params:get("txo_tr_" .. output_num .. "_gate_length") / 100
                local beat_sec = clock.get_beat_sec()
                local gate_time = beat_sec * beats * gate_length
                
                crow.ii.txo.tr(output_num, 1) -- Set high
                clock.sleep(gate_time)
                crow.ii.txo.tr(output_num, 0) -- Set low
            end
            
            -- Wait for next interval
            clock.sync(beats)
        end
    end
    
    -- Start the clock
    active_clocks["txo_tr_" .. output_num] = clock.run(clock_function)
end

-- Function to update TXO CV LFO settings
function EurorackOutput.update_txo_cv(output_num)
    -- Stop existing clock if any
    if active_clocks["txo_cv_" .. output_num] then
        clock.cancel(active_clocks["txo_cv_" .. output_num])
        active_clocks["txo_cv_" .. output_num] = nil
    end

    -- Get the output type
    local type = params:string("txo_cv_" .. output_num .. "_type")
    local sync = params:string("txo_cv_" .. output_num .. "_sync")
    
    -- If sync is Off, disable the output and return early
    if sync == "Off" then
        -- Stop the oscillator by setting amplitude to 0
        crow.ii.txo.cv(output_num, 0)
        return
    end
    
    -- Handle Stepped Random type
    if type == "Stepped Random" then
        local min_value = params:get("txo_cv_" .. output_num .. "_random_min")
        local max_value = params:get("txo_cv_" .. output_num .. "_random_max")
        
        -- Initialize the CV output
        crow.ii.txo.cv_init(output_num)
        
        -- Set initial random value
        local random_value = min_value + math.random() * (max_value - min_value)
        crow.ii.txo.cv(output_num, random_value)
        
        -- Setup clock for stepped random changes
        local function random_step_function()
            while true do
                -- Generate new random value
                local random_value = min_value + math.random() * (max_value - min_value)
                crow.ii.txo.cv(output_num, random_value)
                
                -- Wait for next step
                local beats = EurorackOutput.division_to_beats(sync)
                clock.sync(beats)
            end
        end
        
        -- Start the clock
        active_clocks["txo_cv_" .. output_num] = clock.run(random_step_function)
        return
    end

    -- Handle LFO type (default)
    
    -- Get LFO parameters
    local shape = params:string("txo_cv_" .. output_num .. "_shape")
    local morph = params:get("txo_cv_" .. output_num .. "_morph")
    local depth = params:get("txo_cv_" .. output_num .. "_depth")
    local offset = params:get("txo_cv_" .. output_num .. "_offset")
    local phase = params:get("txo_cv_" .. output_num .. "_phase")
    local rect = params:string("txo_cv_" .. output_num .. "_rect")

    -- Convert rect name to TXO rect value
    local rect_value = 0  -- Default to Full Range
    if rect == "Negative Half" then rect_value = -2
    elseif rect == "Negative Clipped" then rect_value = -1
    elseif rect == "Positive Clipped" then rect_value = 1
    elseif rect == "Positive Half" then rect_value = 2
    end

    -- Convert shape to TXO wave type and apply morphing
    local base_wave_type = 0  -- Default to sine
    if shape == "Triangle" then base_wave_type = 100
    elseif shape == "Saw" then base_wave_type = 200
    elseif shape == "Pulse" then base_wave_type = 300
    elseif shape == "Noise" then base_wave_type = 400
    end

    -- Calculate morphing wave types in both directions
    local prev_wave_type = base_wave_type
    local next_wave_type = base_wave_type
    
    if shape == "Sine" then
        prev_wave_type = 400  -- Morph towards noise
        next_wave_type = 100  -- Morph towards triangle
    elseif shape == "Triangle" then
        prev_wave_type = 0    -- Morph towards sine
        next_wave_type = 200  -- Morph towards saw
    elseif shape == "Saw" then
        prev_wave_type = 100  -- Morph towards triangle
        next_wave_type = 300  -- Morph towards pulse
    elseif shape == "Pulse" then
        prev_wave_type = 200  -- Morph towards saw
        next_wave_type = 400  -- Morph towards noise
    elseif shape == "Noise" then
        prev_wave_type = 300  -- Morph towards pulse
        next_wave_type = 0    -- Morph towards sine
    end

    -- Interpolate between wave types based on morph value
    local wave_type
    if morph < 0 then
        -- Morph towards previous shape
        wave_type = base_wave_type + ((prev_wave_type - base_wave_type) * (math.abs(morph) / 50))
    else
        -- Morph towards next shape
        wave_type = base_wave_type + ((next_wave_type - base_wave_type) * (morph / 50))
    end

    -- Initialize the CV output
    crow.ii.txo.cv_init(output_num)

    -- Set up the oscillator parameters
    crow.ii.txo.osc_wave(output_num, wave_type)
    
    -- TODO: Sync mode doesn't actually sync with clock. Investigate this later
    -- TODO: Consider using AR rather than LFO
    -- Set sync mode
    local beats = EurorackOutput.division_to_beats(sync)
    local beat_sec = clock.get_beat_sec()
    local cycle_time = beat_sec * beats * 1000  -- Convert to milliseconds
    crow.ii.txo.osc_cyc(output_num, cycle_time)
    
    crow.ii.txo.cv(output_num, depth)       -- Set amplitude
    crow.ii.txo.osc_ctr(output_num, math.floor((offset/10) * 16384))  -- Set offset (convert to raw value)
    crow.ii.txo.osc_rect(output_num, rect_value)  -- Set rectification
    
    -- Set phase offset (convert degrees to raw value, 0-16384)
    local phase_raw = math.floor((phase / 360) * 16384)
    crow.ii.txo.osc_phase(output_num, phase_raw)
end

function EurorackOutput.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        handle_encoder_input = EurorackOutput.handle_encoder_input
    }
    create_params()
    
    -- Start outputs with default settings (all outputs off by default since clock_div defaults to "Off")
    for i = 1, 4 do
        EurorackOutput.update_crow(i)
        EurorackOutput.update_txo_tr(i)
        EurorackOutput.update_txo_cv(i)
    end
    
    return component
end

return EurorackOutput 
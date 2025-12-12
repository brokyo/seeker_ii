-- crow_output.lua
-- Component for individual Crow output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")

local CrowOutput = {}
CrowOutput.__index = CrowOutput

-- Store active clock IDs globally
local active_clocks = {}

-- Store envelope states globally
local envelope_states = {}

-- Store pattern states globally for rhythmic patterns
local pattern_states = {}

-- Store random walk states globally
local random_walk_states = {}

-- Store knob recording state for each output
local recording_states = {}

-- Clamp envelope param if total exceeds 100%
local function clamp_envelope_if_needed(output_num, changed_param)
    local attack = params:get("crow_" .. output_num .. "_envelope_attack")
    local decay = params:get("crow_" .. output_num .. "_envelope_decay")
    local release = params:get("crow_" .. output_num .. "_envelope_release")

    local total = attack + decay + release

    if total > 100 then
        local excess = total - 100
        local current_value = params:get(changed_param)
        local clamped_value = math.max(1, current_value - excess)
        params:set(changed_param, clamped_value)
    end
end

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

-- Initialize random walk states for all 4 crow outputs
for i = 1, 4 do
    random_walk_states[i] = {
        current_value = 0,
        initialized = false
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


-- Get clock timing parameters
local function get_clock_timing(interval, modifier, offset)
    if interval == "Off" then return nil end

    local interval_beats = tonumber(interval)
    local modifier_value = EurorackUtils.modifier_to_value(modifier)
    local offset_value = tonumber(offset)

    local beats = interval_beats * modifier_value
    if beats <= 0 then return nil end

    local beat_sec = clock.get_beat_sec()
    return {
        beats = beats,
        beat_sec = beat_sec,
        total_sec = beats * beat_sec,
        offset = offset_value
    }
end

-- Calculate burst timing intervals based on shape
local function get_burst_intervals(count, total_time, shape)
    local intervals = {}

    if shape == "Linear" then
        local interval = total_time / count
        for i = 1, count do
            intervals[i] = interval
        end
    elseif shape == "Accelerating" then
        -- Bursts get faster: longer gaps at start, shorter at end
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * (count - i + 1) / sum
        end
    elseif shape == "Decelerating" then
        -- Bursts get slower: shorter gaps at start, longer at end
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * i / sum
        end
    elseif shape == "Random" then
        -- Random distribution
        local remaining = total_time
        for i = 1, count - 1 do
            local max_for_this = remaining - (count - i) * 0.01
            intervals[i] = math.random() * max_for_this * 0.5 + 0.01
            remaining = remaining - intervals[i]
        end
        intervals[count] = remaining
    end

    return intervals
end

-- Setup clock helper
local function setup_clock(output_id, clock_fn)
    if active_clocks[output_id] then
        clock.cancel(active_clocks[output_id])
        active_clocks[output_id] = nil
    end

    if clock_fn then
        active_clocks[output_id] = clock.run(clock_fn)
    end
end

-- Pattern generation and management

function CrowOutput.generate_pattern(output_num)
    local pattern_length = params:get("crow_" .. output_num .. "_gate_pattern_length")
    local pattern_hits = params:get("crow_" .. output_num .. "_gate_pattern_hits")

    if not pattern_states[output_num] then
        pattern_states[output_num] = {
            pattern = {},
            current_step = 1
        }
    end

    local pattern = {}
    local hits_placed = 0

    while hits_placed < pattern_hits do
        local position = math.random(1, pattern_length)
        if not pattern[position] then
            pattern[position] = true
            hits_placed = hits_placed + 1
        end
    end

    for i = 1, pattern_length do
        if not pattern[i] then
            pattern[i] = false
        end
    end

    pattern_states[output_num].pattern = pattern
    pattern_states[output_num].current_step = 1

    return pattern
end

function CrowOutput.reroll_pattern(output_num)
    CrowOutput.generate_pattern(output_num)
    CrowOutput.update_crow(output_num)
    _seeker.screen_ui.set_needs_redraw()
end

-- Knob Recorder functions

function CrowOutput.handle_encoder_input(delta)
    for output_num = 1, 4 do
        local state = recording_states[output_num]
        if state.active then
            local sensitivity = params:get("crow_" .. output_num .. "_knob_sensitivity")

            state.voltage = state.voltage + (delta * sensitivity)
            state.voltage = util.clamp(state.voltage, -10, 10)

            crow.output[output_num].volts = state.voltage
        end
    end
end

function CrowOutput.record_knob(output_num)
    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end

    local state = recording_states[output_num]

    state.active = true
    state.voltage = 0
    state.data = {}

    _seeker.ui_state.state.knob_recording_active = true

    state.capture_clock = clock.run(function()
        while state.active do
            table.insert(state.data, state.voltage)
            crow.output[output_num].volts = state.voltage
            clock.sleep(state.clock_interval)
        end
    end)
end

function CrowOutput.stop_recording_knob(output_num)
    local state = recording_states[output_num]

    state.active = false

    local any_recording = false
    for i = 1, 4 do
        if recording_states[i].active then
            any_recording = true
            break
        end
    end

    if not any_recording then
        _seeker.ui_state.state.knob_recording_active = false
    end

    if state.capture_clock then
        clock.cancel(state.capture_clock)
        state.capture_clock = nil
    end

    local data = state.data

    if #data > 0 then
        active_clocks["knob_playback_" .. output_num] = clock.run(function()
            local step = 1
            local substep = 0
            local interpolation_steps = state.interpolation_steps

            while true do
                local current_voltage = data[step]
                local next_step = (step % #data) + 1
                local next_voltage = data[next_step]

                local interpolated_voltage = current_voltage +
                    (next_voltage - current_voltage) * (substep / interpolation_steps)

                crow.output[output_num].volts = interpolated_voltage

                substep = substep + 1
                if substep >= interpolation_steps then
                    substep = 0
                    step = next_step
                end

                clock.sleep(0.01)
            end
        end)
    end

    reset_recording_state(output_num)
end

function CrowOutput.clear_knob(output_num)
    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end

    recording_states[output_num].data = {}
    crow.output[output_num].volts = 0
    _seeker.screen_ui.set_needs_redraw()
end

-- Main Crow update function

function CrowOutput.update_crow(output_num)
    if active_clocks["crow_" .. output_num] then
        clock.cancel(active_clocks["crow_" .. output_num])
        active_clocks["crow_" .. output_num] = nil
    end

    if active_clocks["knob_playback_" .. output_num] then
        clock.cancel(active_clocks["knob_playback_" .. output_num])
        active_clocks["knob_playback_" .. output_num] = nil
    end

    random_walk_states[output_num].initialized = false

    local type = params:string("crow_" .. output_num .. "_type")

    if type == "LFO" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
            crow.output[output_num].volts = 0
            return
        end

        local shape = params:string("crow_" .. output_num .. "_lfo_shape")
        local min = params:get("crow_" .. output_num .. "_lfo_min")
        local max = params:get("crow_" .. output_num .. "_lfo_max")

        local asl_string = string.format("loop( { to(%f,%f,'%s'), to(%f,%f,'%s') } )",
            min, timing.total_sec/2, shape,
            max, timing.total_sec/2, shape)

        crow.output[output_num].action = asl_string
        crow.output[output_num]()
        return
    end

    if type == "Looped Random" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local shape = params:string("crow_" .. output_num .. "_looped_random_shape")
        local quantize = params:string("crow_" .. output_num .. "_looped_random_quantize")
        local steps = params:get("crow_" .. output_num .. "_looped_random_steps")
        local loops = params:get("crow_" .. output_num .. "_looped_random_loops")
        local min = params:get("crow_" .. output_num .. "_looped_random_min")
        local max = params:get("crow_" .. output_num .. "_looped_random_max")

        if clock_interval == "Off" then
            crow.output[output_num].volts = 0
            return
        end

        local trigger_beats = EurorackUtils.interval_to_beats(clock_interval)
        local modifier_value = EurorackUtils.modifier_to_value(clock_modifier)
        local final_beats = trigger_beats * modifier_value
        local beat_sec = clock.get_beat_sec()
        local time = beat_sec * final_beats

        if quantize == "On" then
            local scale = params:get("scale_type")
            local root = params:get("root_note")
            crow.output[output_num].scale(scale)
        else
            crow.output[output_num].scale('none')
        end

        local function generate_asl_pattern()
            local asl_steps = {}
            for i = 1, steps do
                local random_value = min + math.random() * (max - min)
                local asl_step = string.format("to(%f, %f, '%s')", random_value, time, shape)
                table.insert(asl_steps, asl_step)
            end

            local asl_loop = string.format("loop( { %s } )", table.concat(asl_steps, ", "))

            crow.output[output_num].action = asl_loop
            crow.output[output_num]()
        end

        local function clock_function()
            while true do
                generate_asl_pattern()

                local cycle_beats = steps * loops * trigger_beats
                clock.sync(cycle_beats)
            end
        end

        active_clocks["crow_" .. output_num] = clock.run(clock_function)
        return
    end

    if type == "Clocked Random" then
        local input_number = params:get("crow_" .. output_num .. "_clocked_random_trigger")
        local min_value = params:get("crow_" .. output_num .. "_clocked_random_min")
        local max_value = params:get("crow_" .. output_num .. "_clocked_random_max")
        local shape = params:string("crow_" .. output_num .. "_clocked_random_shape")
        local quantize = params:string("crow_" .. output_num .. "_clocked_random_quantize")

        local function generate_random_value()
            local random_value
            if quantize == "On" then
                random_value = math.random(min_value, max_value)
            else
                random_value = min_value + math.random() * (max_value - min_value)
            end

            local asl_string = string.format("to(%f,0.1,'%s')", random_value, shape)
            crow.output[output_num].action = asl_string
            crow.output[output_num]()
        end

        if active_clocks["crow_" .. output_num] then
            clock.cancel(active_clocks["crow_" .. output_num])
            active_clocks["crow_" .. output_num] = nil
        end

        if input_number == 1 or input_number == 2 then
            crow.input[input_number].mode('change', 1.0, 0.1, 'rising')

            crow.input[input_number].change = function(state)
                if state then
                    generate_random_value()
                end
            end

            generate_random_value()
        end
        return
    end

    if type == "Burst" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
            crow.output[output_num].volts = 0
            return
        end

        local clock_fn = function()
            while true do
                local burst_voltage = params:get("crow_" .. output_num .. "_burst_voltage")
                local burst_count = params:get("crow_" .. output_num .. "_burst_count")
                local burst_time = params:get("crow_" .. output_num .. "_burst_time")
                local burst_shape = params:string("crow_" .. output_num .. "_burst_shape")

                local intervals = get_burst_intervals(burst_count, burst_time, burst_shape)

                for i = 1, burst_count do
                    crow.output[output_num].volts = burst_voltage
                    clock.sleep(intervals[i] / 2)
                    crow.output[output_num].volts = 0
                    clock.sleep(intervals[i] / 2)
                end

                clock.sync(timing.beats, timing.offset)
            end
        end

        setup_clock("crow_" .. output_num, clock_fn)
        return
    end

    if type == "Gate" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
            crow.output[output_num].volts = 0
            return
        end

        local gate_mode = params:string("crow_" .. output_num .. "_gate_mode")

        if gate_mode == "Clock" then
            local clock_fn = function()
                while true do
                    local gate_voltage = params:get("crow_" .. output_num .. "_gate_voltage")
                    local gate_length = params:get("crow_" .. output_num .. "_gate_length") / 100
                    local gate_time = timing.total_sec * gate_length

                    crow.output[output_num].volts = gate_voltage
                    clock.sleep(gate_time)
                    crow.output[output_num].volts = 0

                    clock.sync(timing.beats, timing.offset)
                end
            end

            setup_clock("crow_" .. output_num, clock_fn)
        else
            if not pattern_states[output_num] or not pattern_states[output_num].pattern then
                CrowOutput.generate_pattern(output_num)
            end

            local clock_fn = function()
                while true do
                    local gate_voltage = params:get("crow_" .. output_num .. "_gate_voltage")
                    local gate_length = params:get("crow_" .. output_num .. "_gate_length") / 100
                    local gate_time = timing.total_sec * gate_length
                    local pattern = pattern_states[output_num].pattern
                    local current_step = pattern_states[output_num].current_step

                    if pattern[current_step] then
                        crow.output[output_num].volts = gate_voltage
                        clock.sleep(gate_time)
                        crow.output[output_num].volts = 0
                    end

                    current_step = current_step + 1
                    if current_step > #pattern then
                        current_step = 1
                    end
                    pattern_states[output_num].current_step = current_step

                    clock.sync(timing.beats, timing.offset)
                end
            end

            setup_clock("crow_" .. output_num, clock_fn)
        end

        return
    end

    if type == "Envelope" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
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

        envelope_states[output_num] = {
            active = false,
            clock = nil
        }

        local function generate_envelope_asl()
            local sustain_voltage = max_voltage * sustain_level
            local beat_sec = clock.get_beat_sec()
            local cycle_time = beat_sec * timing.beats

            local envelope_time = cycle_time * (duration_percent / 100)

            if mode == "ADSR" then
                local total_percent = attack_percent + decay_percent + release_percent
                local sustain_percent = math.max(0, 100 - total_percent)

                local attack_time = envelope_time * (attack_percent / 100)
                local decay_time = envelope_time * (decay_percent / 100)
                local sustain_time = envelope_time * (sustain_percent / 100)
                local release_time = envelope_time * (release_percent / 100)

                local envelope = string.format(
                    "to(%f,%f,'%s'), to(%f,%f,'%s'), to(%f,%f,'%s'), to(0,%f,'%s')",
                    max_voltage, attack_time, shape,
                    sustain_voltage, decay_time, shape,
                    sustain_voltage, sustain_time, shape,
                    release_time, shape
                )

                local wait_time = cycle_time - envelope_time
                if wait_time > 0 then
                    envelope = envelope .. string.format(", to(0,%f,'now')", wait_time)
                end

                return "loop({ " .. envelope .. " })"

            else
                local total_percent = attack_percent + release_percent
                local scale_factor = 100 / total_percent

                local attack_time = envelope_time * ((attack_percent * scale_factor) / 100)
                local release_time = envelope_time * ((release_percent * scale_factor) / 100)

                local envelope = string.format(
                    "to(%f,%f,'%s'), to(0,%f,'%s')",
                    max_voltage, attack_time, shape,
                    release_time, shape
                )

                local wait_time = cycle_time - envelope_time
                if wait_time > 0 then
                    envelope = envelope .. string.format(", to(0,%f,'now')", wait_time)
                end

                return "loop({ " .. envelope .. " })"
            end
        end

        if active_clocks["crow_" .. output_num] then
            clock.cancel(active_clocks["crow_" .. output_num])
            active_clocks["crow_" .. output_num] = nil
        end

        local asl_string = generate_envelope_asl()
        crow.output[output_num].action = asl_string
        crow.output[output_num]()

        envelope_states[output_num].active = true

        return
    end

    if type == "Random Walk" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
            crow.output[output_num].volts = 0
            return
        end

        local mode = params:string("crow_" .. output_num .. "_random_walk_mode")
        local slew = params:get("crow_" .. output_num .. "_random_walk_slew") / 100
        local shape = params:string("crow_" .. output_num .. "_random_walk_shape")
        local min_value = params:get("crow_" .. output_num .. "_random_walk_min")
        local max_value = params:get("crow_" .. output_num .. "_random_walk_max")

        if not random_walk_states[output_num].initialized then
            if mode == "Accumulate" then
                local offset = params:get("crow_" .. output_num .. "_random_walk_offset")
                random_walk_states[output_num].current_value = offset
            else
                random_walk_states[output_num].current_value = min_value + math.random() * (max_value - min_value)
            end
            random_walk_states[output_num].initialized = true
            crow.output[output_num].volts = random_walk_states[output_num].current_value
        end

        local clock_fn = function()
            while true do
                local new_value

                if mode == "Jump" then
                    new_value = min_value + math.random() * (max_value - min_value)
                else
                    local step_size = params:get("crow_" .. output_num .. "_random_walk_step_size")
                    local step = (math.random() - 0.5) * 2 * step_size
                    new_value = random_walk_states[output_num].current_value + step

                    if new_value > max_value then
                        new_value = 2 * max_value - new_value
                    elseif new_value < min_value then
                        new_value = 2 * min_value - new_value
                    end

                    new_value = util.clamp(new_value, min_value, max_value)
                end

                random_walk_states[output_num].current_value = new_value

                local slew_time = timing.total_sec * slew

                if slew_time > 0 then
                    local asl_string = string.format("to(%f, %f, '%s')", new_value, slew_time, shape)
                    crow.output[output_num].action = asl_string
                    crow.output[output_num]()
                else
                    crow.output[output_num].volts = new_value
                end

                clock.sync(timing.beats, timing.offset)
            end
        end

        setup_clock("crow_" .. output_num, clock_fn)
        return
    end
end

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CROW_OUTPUT",
        name = "Crow Output",
        description = Descriptions.CROW_OUTPUT,
        params = {}
    })

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()  -- Rebuild params BEFORE entering (so arc.new_section gets valid params)
        original_enter(self)
    end

    -- Override key handler to stop recording with K2/K3
    norns_ui.handle_key = function(self, n, z)
        if _seeker.ui_state.state.knob_recording_active and (n == 2 or n == 3) and z == 1 then
            local output_num = params:get("eurorack_selected_number")
            CrowOutput.stop_recording_knob(output_num)
            return
        end

        -- Call parent handler for normal behavior
        NornsUI.handle_key(self, n, z)
    end

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")
        self.name = string.format("Crow %d", selected_number)

        local param_table = {}
        local output_num = selected_number
        local type = params:string("crow_" .. output_num .. "_type")

        table.insert(param_table, { separator = true, title = "Crow " .. output_num })
        table.insert(param_table, { id = "crow_" .. output_num .. "_type" })

        if type ~= "Clocked Random" and type ~= "Knob Recorder" then
            table.insert(param_table, { separator = true, title = "Clock" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_interval" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_modifier" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_offset" })
        end

        if type == "Burst" then
            table.insert(param_table, { separator = true, title = "Burst" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_count" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_time", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_shape" })
        elseif type == "Gate" then
            table.insert(param_table, { separator = true, title = "Gate" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_gate_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_gate_mode" })

            local gate_mode = params:string("crow_" .. output_num .. "_gate_mode")
            if gate_mode == "Pattern" then
                table.insert(param_table, { separator = true, title = "Pattern" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_gate_pattern_length" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_gate_pattern_hits" })
                table.insert(param_table, { id = "crow_" .. output_num .. "_gate_pattern_reroll", is_action = true })
            end
        elseif type == "LFO" then
            table.insert(param_table, { separator = true, title = "LFO" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif type == "Looped Random" then
            table.insert(param_table, { separator = true, title = "Looped Random" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_quantize" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_steps" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_loops" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif type == "Clocked Random" then
            table.insert(param_table, { separator = true, title = "Clocked Random" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_trigger" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_quantize" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif type == "Knob Recorder" then
            table.insert(param_table, { separator = true, title = "Knob Recorder" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_sensitivity", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_start_recording", is_action = true })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_clear", is_action = true })
        elseif type == "Envelope" then
            table.insert(param_table, { separator = true, title = "Envelope" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_mode" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_duration", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_attack", arc_multi_float = {10, 5, 1} })

            local mode = params:string("crow_" .. output_num .. "_envelope_mode")
            if mode == "ADSR" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_decay", arc_multi_float = {10, 5, 1} })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_sustain", arc_multi_float = {10, 5, 1} })
            end

            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_release", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_shape" })
        elseif type == "Random Walk" then
            table.insert(param_table, { separator = true, title = "Random Walk" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_mode" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_slew", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_max", arc_multi_float = {1.0, 0.1, 0.01} })

            local mode = params:string("crow_" .. output_num .. "_random_walk_mode")
            if mode == "Accumulate" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_step_size", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_offset", arc_multi_float = {1.0, 0.1, 0.01} })
            end
        end

        self.params = param_table
    end

    return norns_ui
end

-- Grid UI

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "CROW_OUTPUT",
    layout = {
      x = 13,
      y = 5,
      width = 4,
      height = 1
    }
  })

  -- Override draw to show selected output with dynamic brightness
  grid_ui.draw = function(self, layers)
    local is_crow_section = (_seeker.ui_state.get_current_section() == "CROW_OUTPUT")
    local selected_type = params:get("eurorack_selected_type")
    local selected_number = params:get("eurorack_selected_number")

    for i = 0, 3 do
      local x = self.layout.x + i
      local output_num = i + 1
      local is_selected = (selected_type == 1 and output_num == selected_number)

      -- Check if output is enabled based on type
      local type = params:string("crow_" .. output_num .. "_type")
      local is_enabled = false
      if type == "Clocked Random" then
        is_enabled = params:get("crow_" .. output_num .. "_clocked_random_trigger") > 0
      elseif type ~= "Knob Recorder" then
        is_enabled = params:string("crow_" .. output_num .. "_clock_interval") ~= "Off"
      end

      local brightness

      if is_selected then
        if is_crow_section then
          brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
        else
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        end
      elseif is_enabled then
        brightness = GridConstants.BRIGHTNESS.UI.UNFOCUSED
      else
        brightness = GridConstants.BRIGHTNESS.UI.NORMAL
      end

      layers.ui[x][self.layout.y] = brightness
    end
  end

  -- Override handle_key to select output and switch to CROW_OUTPUT section
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local output_num = (x - self.layout.x) + 1
      params:set("eurorack_selected_type", 1) -- 1 = Crow
      params:set("eurorack_selected_number", output_num)
      _seeker.ui_state.set_current_section("CROW_OUTPUT")
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Parameter creation

local function create_params()
    params:add_group("crow_output", "CROW OUTPUT", 184)

    for i = 1, 4 do
        params:add_option("crow_" .. i .. "_clock_interval", "Interval", EurorackUtils.interval_options, 1)
        params:add_option("crow_" .. i .. "_clock_modifier", "Modifier", EurorackUtils.modifier_options, 26)
        params:add_option("crow_" .. i .. "_clock_offset", "Offset", EurorackUtils.offset_options, 1)
        params:set_action("crow_" .. i .. "_clock_interval", function(value)
            CrowOutput.update_crow(i)
        end)
        params:set_action("crow_" .. i .. "_clock_modifier", function(value)
            CrowOutput.update_crow(i)
        end)
        params:set_action("crow_" .. i .. "_clock_offset", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_type", "Type", {"Gate", "Burst", "LFO", "Envelope", "Knob Recorder", "Looped Random", "Clocked Random", "Random Walk"}, 1)
        params:set_action("crow_" .. i .. "_type", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Gate parameters
        params:add_control("crow_" .. i .. "_gate_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_gate_voltage", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_control("crow_" .. i .. "_gate_length", "Gate Length", controlspec.new(1, 100, 'lin', 1, 25), function(param) return params:get(param.id) .. "%" end)
        params:set_action("crow_" .. i .. "_gate_length", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_gate_mode", "Gate Mode", {"Clock", "Pattern"}, 1)
        params:set_action("crow_" .. i .. "_gate_mode", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_number("crow_" .. i .. "_gate_pattern_length", "Pattern Length", 1, 32, 8)
        params:set_action("crow_" .. i .. "_gate_pattern_length", function(value)
            CrowOutput.generate_pattern(i)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_gate_pattern_hits", "Pattern Hits", 1, 32, 4)
        params:set_action("crow_" .. i .. "_gate_pattern_hits", function(value)
            CrowOutput.generate_pattern(i)
            CrowOutput.update_crow(i)
        end)

        params:add_binary("crow_" .. i .. "_gate_pattern_reroll", "Reroll Pattern", "trigger", 0)
        params:set_action("crow_" .. i .. "_gate_pattern_reroll", function(value)
            CrowOutput.reroll_pattern(i)
        end)

        -- Burst parameters
        params:add_control("crow_" .. i .. "_burst_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_burst_voltage", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_burst_count", "Burst Count", 1, 16, 1)
        params:set_action("crow_" .. i .. "_burst_count", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_burst_time", "Burst Window", controlspec.new(0, 1, 'lin', 0.01, 0.1), function(param) return string.format("%.0f", params:get(param.id) * 100) .. "%" end)
        params:set_action("crow_" .. i .. "_burst_time", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_burst_shape", "Burst Shape", {"Linear", "Accelerating", "Decelerating", "Random"}, 1)
        params:set_action("crow_" .. i .. "_burst_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        -- LFO parameters
        params:add_option("crow_" .. i .. "_lfo_shape", "CV Shape", EurorackUtils.shape_options, 1)
        params:set_action("crow_" .. i .. "_lfo_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_lfo_min", "CV Min", controlspec.new(-10, 10, 'lin', 0.01, -5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_lfo_min", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_lfo_max", "CV Max", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_lfo_max", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Looped Random parameters
        params:add_option("crow_" .. i .. "_looped_random_shape", "Shape", EurorackUtils.shape_options, 3)
        params:set_action("crow_" .. i .. "_looped_random_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_looped_random_quantize", "Quantize", {"On", "Off"}, 2)
        params:set_action("crow_" .. i .. "_looped_random_quantize", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_looped_random_steps", "Steps", 1, 32, 1)
        params:set_action("crow_" .. i .. "_looped_random_steps", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_looped_random_loops", "Loops", 1, 32, 1)
        params:set_action("crow_" .. i .. "_looped_random_loops", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_looped_random_min", "Min Value", controlspec.new(-10, 10, 'lin', 0.01, -5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_looped_random_min", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_looped_random_max", "Max Value", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_looped_random_max", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Clocked Random parameters
        params:add_number("crow_" .. i .. "_clocked_random_trigger", "Crow Input", 0, 2, 0)
        params:set_action("crow_" .. i .. "_clocked_random_trigger", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_clocked_random_shape", "Shape", EurorackUtils.shape_options, 3)
        params:set_action("crow_" .. i .. "_clocked_random_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_clocked_random_quantize", "Quantize", {"On", "Off"}, 2)
        params:set_action("crow_" .. i .. "_clocked_random_quantize", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_clocked_random_min", "Min Value", controlspec.new(-10, 10, 'lin', 0.01, -5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_clocked_random_min", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_clocked_random_max", "Max Value", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_clocked_random_max", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Knob Recorder parameters
        params:add_control("crow_" .. i .. "_knob_sensitivity", "Sensitivity", controlspec.new(0.01, 1.0, 'lin', 0.01, 0.1))
        params:set_action("crow_" .. i .. "_knob_sensitivity", function(value)
            recording_states[i].sensitivity = value
        end)

        params:add_binary("crow_" .. i .. "_knob_start_recording", "Toggle Recording", "trigger", 0)
        params:set_action("crow_" .. i .. "_knob_start_recording", function(value)
            if value == 1 then
                CrowOutput.record_knob(i)
                _seeker.ui_state.trigger_activated("crow_" .. i .. "_knob_start_recording")
            end
        end)

        params:add_binary("crow_" .. i .. "_knob_clear", "Clear", "trigger", 0)
        params:set_action("crow_" .. i .. "_knob_clear", function(value)
            if value == 1 then
                CrowOutput.clear_knob(i)
                _seeker.ui_state.trigger_activated("crow_" .. i .. "_knob_clear")
            end
        end)

        -- Envelope parameters
        params:add_option("crow_" .. i .. "_envelope_mode", "Envelope Mode", {"ADSR", "AR"}, 1)
        params:set_action("crow_" .. i .. "_envelope_mode", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("crow_" .. i .. "_envelope_voltage", "Max Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_envelope_voltage", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_envelope_duration", "Duration", 1, 100, 50, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_duration", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_envelope_attack", "Attack", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_attack", function(value)
            clamp_envelope_if_needed(i, "crow_" .. i .. "_envelope_attack")
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_envelope_decay", "Decay", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_decay", function(value)
            clamp_envelope_if_needed(i, "crow_" .. i .. "_envelope_decay")
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_envelope_sustain", "Sustain Level", 1, 100, 80, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_sustain", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_envelope_release", "Release", 1, 100, 20, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_envelope_release", function(value)
            clamp_envelope_if_needed(i, "crow_" .. i .. "_envelope_release")
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_envelope_shape", "Envelope Shape", EurorackUtils.shape_options, 2)
        params:set_action("crow_" .. i .. "_envelope_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Random Walk parameters
        params:add_option("crow_" .. i .. "_random_walk_mode", "Mode", {"Jump", "Accumulate"}, 2)
        params:set_action("crow_" .. i .. "_random_walk_mode", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("crow_" .. i .. "_random_walk_slew", "Slew", controlspec.new(0, 100, 'lin', 1, 50), function(param) return params:get(param.id) .. "%" end)
        params:set_action("crow_" .. i .. "_random_walk_slew", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_random_walk_shape", "Shape", EurorackUtils.shape_options, 2)
        params:set_action("crow_" .. i .. "_random_walk_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_walk_min", "Min", controlspec.new(-10, 10, 'lin', 0.01, -5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_random_walk_min", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_walk_max", "Max", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_random_walk_max", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_walk_step_size", "Step Size", controlspec.new(0.01, 5, 'lin', 0.01, 0.5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_random_walk_step_size", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_walk_offset", "Offset", controlspec.new(-10, 10, 'lin', 0.01, 0), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_random_walk_offset", function(value)
            CrowOutput.update_crow(i)
        end)
    end
end

-- Sync all crow outputs by restarting their clocks
function CrowOutput.sync()
    for i = 1, 4 do
        CrowOutput.update_crow(i)
    end
end

function CrowOutput.init()
    create_params()

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = CrowOutput.sync,
        handle_encoder_input = CrowOutput.handle_encoder_input,
        record_knob = CrowOutput.record_knob,
        stop_recording_knob = CrowOutput.stop_recording_knob,
        clear_knob = CrowOutput.clear_knob
    }

    return component
end

return CrowOutput

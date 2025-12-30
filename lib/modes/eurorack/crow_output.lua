-- crow_output.lua
-- Component for individual Crow output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")

-- Use global Modal singleton
local function get_modal()
  return _seeker and _seeker.modal
end

local CrowOutput = {}
CrowOutput.__index = CrowOutput

-- Mode options by category
local GATE_MODES = {"Clock", "Pattern", "Euclidean", "Burst"}
local CV_MODES = {"LFO", "Knob Recorder", "Envelope", "Looped Random", "Clocked Random", "Random Walk"}

-- Mode descriptions for dynamic help
local MODE_DESCRIPTIONS = {
  Clock = "Clocked gate output.",
  Pattern = "Random rhythmic pattern.\n\nREROLL generates a new random distribution.",
  Euclidean = "Euclidean rhythmic pattern.",
  Burst = "Rapid burst of triggers.\n\nWINDOW sets burst duration as percentage of clock period.\n\nSHAPE controls timing between triggers.",
  LFO = "Clock-synced LFO.",
  Envelope = "Clock-synced envelope.\n\nDURATION sets envelope time as percentage of clock period.",
  ["Knob Recorder"] = "Record E3 knob movements as CV.\n\nK3 opens preview, K3 starts recording, K3 stops.\nK2 cancels.\n\nCROSSFADE smooths the loop point.",
  ["Looped Random"] = "Looping random sequence.\n\nLOOPS sets how many times the sequence repeats before regenerating.",
  ["Clocked Random"] = "Random voltage on external trigger.\n\nConnect a trigger source to Crow input 1.",
  ["Random Walk"] = "Wandering voltage.\n\nJUMP picks a new random position each step.\n\nACCUMULATE drifts from current value by STEP SIZE."
}

-- Returns the mode name for an output based on its category (Gate or CV)
local function get_output_mode(output_num)
  local category = params:string("crow_" .. output_num .. "_category")
  local mode_index = params:get("crow_" .. output_num .. "_mode")
  local modes = category == "Gate" and GATE_MODES or CV_MODES
  local clamped_index = math.min(mode_index, #modes)
  return modes[clamped_index]
end

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

-- Reduces the changed envelope parameter if A+D+R total exceeds 100%
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

-- Recording stage constants
local RECORDING_STAGE = {
    IDLE = 0,
    PREVIEW = 1,
    RECORDING = 2
}

-- Initialize recording states for all 4 crow outputs
for i = 1, 4 do
    recording_states[i] = {
        stage = 0,
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
        stage = 0,
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

-- ASL helpers - see https://monome.org/docs/crow/reference/
local function asl_to(volts, time, shape)
    return string.format("to(%f,%f,'%s')", volts, time, shape)
end

local function asl_loop(stages)
    return "loop({ " .. table.concat(stages, ", ") .. " })"
end

local function asl_once(stages)
    return "{ " .. table.concat(stages, ", ") .. " }"
end

-- Pattern generation and management

-- Generate random pattern with hits distributed randomly across length
function CrowOutput.generate_random_pattern(output_num)
    local pattern_length = params:get("crow_" .. output_num .. "_pattern_length")
    local pattern_hits = params:get("crow_" .. output_num .. "_pattern_hits")

    if not pattern_states[output_num] then
        pattern_states[output_num] = {
            pattern = {},
            current_step = 1
        }
    end

    -- Ensure hits doesn't exceed pattern length
    pattern_hits = math.min(pattern_hits, pattern_length)

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

-- Generate euclidean pattern using Bjorklund algorithm
function CrowOutput.generate_euclidean_pattern(output_num)
    local pattern_length = params:get("crow_" .. output_num .. "_euclidean_length")
    local pattern_hits = params:get("crow_" .. output_num .. "_euclidean_hits")
    local rotation = params:get("crow_" .. output_num .. "_euclidean_rotation")

    if not pattern_states[output_num] then
        pattern_states[output_num] = {
            pattern = {},
            current_step = 1
        }
    end

    -- Clamp hits to length
    pattern_hits = math.min(pattern_hits, pattern_length)

    -- Bjorklund algorithm
    local pattern = {}
    if pattern_hits == 0 then
        for i = 1, pattern_length do
            pattern[i] = false
        end
    elseif pattern_hits == pattern_length then
        for i = 1, pattern_length do
            pattern[i] = true
        end
    else
        local groups = {}
        for i = 1, pattern_hits do
            groups[i] = {true}
        end
        for i = 1, pattern_length - pattern_hits do
            groups[pattern_hits + i] = {false}
        end

        while #groups > pattern_hits do
            local new_groups = {}
            local num_to_merge = math.min(pattern_hits, #groups - pattern_hits)
            for i = 1, num_to_merge do
                local merged = {}
                for _, v in ipairs(groups[i]) do table.insert(merged, v) end
                for _, v in ipairs(groups[#groups - num_to_merge + i]) do table.insert(merged, v) end
                new_groups[i] = merged
            end
            for i = num_to_merge + 1, #groups - num_to_merge do
                new_groups[i] = groups[i]
            end
            groups = new_groups
            if #groups <= pattern_hits then break end
        end

        local idx = 1
        for _, group in ipairs(groups) do
            for _, v in ipairs(group) do
                pattern[idx] = v
                idx = idx + 1
            end
        end
    end

    -- Apply rotation
    if rotation > 0 then
        local rotated = {}
        for i = 1, pattern_length do
            local src_idx = ((i - 1 + rotation) % pattern_length) + 1
            rotated[i] = pattern[src_idx]
        end
        pattern = rotated
    end

    pattern_states[output_num].pattern = pattern
    pattern_states[output_num].current_step = 1

    return pattern
end

function CrowOutput.reroll_pattern(output_num)
    local mode = get_output_mode(output_num)
    if mode == "Pattern" then
        CrowOutput.generate_random_pattern(output_num)
    elseif mode == "Euclidean" then
        CrowOutput.generate_euclidean_pattern(output_num)
    end
    CrowOutput.update_crow(output_num)
    _seeker.screen_ui.set_needs_redraw()
end

-- Knob Recorder functions
-- Stage 0: idle, Stage 1: preview (modal open), Stage 2: recording

-- Returns data for the recording modal visualization
local function get_recording_data(output_num)
    return function()
        local state = recording_states[output_num]
        return {
            data = state.data,
            voltage = state.voltage,
            min = -10,
            max = 10
        }
    end
end

-- Arc display for recording modal - shows voltage position on all 4 rings
local function create_recording_arc_display(output_num)
    return function()
        local arc = _seeker.arc
        if not arc then return end

        local state = recording_states[output_num]
        local voltage = state.voltage
        local normalized = (voltage + 10) / 20
        normalized = util.clamp(normalized, 0, 1)
        local led_pos = math.floor(normalized * 63) + 1

        -- Ring 1: dim base (recording takes over, no param navigation)
        for i = 1, 64 do
            arc:led(1, i, 1)
        end

        -- Rings 2-4: show voltage position
        for ring = 2, 4 do
            for i = 1, 64 do
                arc:led(ring, i, 2)
            end
            arc:led(ring, led_pos, 15)
            if led_pos > 1 then arc:led(ring, led_pos - 1, 10) end
            if led_pos < 64 then arc:led(ring, led_pos + 1, 10) end
        end

        arc:refresh()
    end
end

-- Creates key callback for recording modal that advances stages or cancels
local function create_recording_key_handler(output_num)
    return function(n, z)
        local state = recording_states[output_num]

        -- K3 press advances recording stage
        if n == 3 and z == 1 then
            CrowOutput.toggle_knob_recording(output_num)
            return true
        end

        -- K2 press cancels recording without playback
        if n == 2 and z == 1 then
            if state.capture_clock then
                clock.cancel(state.capture_clock)
                state.capture_clock = nil
            end
            local Modal = get_modal()
            if Modal then Modal.dismiss() end
            reset_recording_state(output_num)
            _seeker.ui_state.state.knob_recording_active = false
            if _seeker.arc and _seeker.arc.clear_display then _seeker.arc.clear_display() end
            crow.output[output_num].volts = 0
            _seeker.screen_ui.set_needs_redraw()
            return true
        end

        -- Block K2 release during recording (prevent parent dismiss)
        if n == 2 and z == 0 then
            return true
        end

        return false
    end
end

-- Arc uses fixed multi-float steps, Norns uses sensitivity param
local ARC_VOLTAGE_STEPS = { [2] = 0.1, [3] = 0.05, [4] = 0.01 }

local function create_recording_enc_handler(output_num)
    return function(n, d, source)
        local state = recording_states[output_num]
        local step_size = nil

        if source == "arc" then
            step_size = ARC_VOLTAGE_STEPS[n]
        elseif source == "norns" and n == 3 then
            step_size = params:get("crow_" .. output_num .. "_knob_sensitivity")
        end

        if step_size then
            state.voltage = state.voltage + (d * step_size)
            state.voltage = util.clamp(state.voltage, -10, 10)
            crow.output[output_num].volts = state.voltage
            if _seeker.arc and _seeker.arc.sync_display then
                _seeker.arc.sync_display()
            end
            _seeker.screen_ui.set_needs_redraw()
            return true
        end

        return true
    end
end

-- 3-stage toggle: idle -> preview -> recording -> idle (with playback)
function CrowOutput.toggle_knob_recording(output_num)
    local state = recording_states[output_num]
    local Modal = get_modal()

    if state.stage == 0 then
        -- Stage 0 -> 1: Open modal for preview, user can set start voltage
        if active_clocks["knob_playback_" .. output_num] then
            clock.cancel(active_clocks["knob_playback_" .. output_num])
            active_clocks["knob_playback_" .. output_num] = nil
        end

        state.stage = 1
        state.voltage = 0
        state.data = {}
        crow.output[output_num].volts = 0

        _seeker.ui_state.state.knob_recording_active = true

        -- Set Arc to show voltage display
        if _seeker.arc then
            if _seeker.arc.stop_action_pulse then
                _seeker.arc.stop_action_pulse()
            end
            if _seeker.arc.set_display then
                _seeker.arc.set_display(create_recording_arc_display(output_num))
            end
        end

        if Modal then
            Modal.show_recording({
                get_data = get_recording_data(output_num),
                output_num = output_num,
                hint = "k2 cancel · k3 record",
                on_key = create_recording_key_handler(output_num),
                on_enc = create_recording_enc_handler(output_num)
            })
        end

    elseif state.stage == 1 then
        -- Stage 1 -> 2: Start recording
        state.stage = 2

        if Modal then
            Modal.show_recording({
                get_data = get_recording_data(output_num),
                output_num = output_num,
                hint = "k2 cancel · k3 stop",
                on_key = create_recording_key_handler(output_num),
                on_enc = create_recording_enc_handler(output_num)
            })
        end

        state.capture_clock = clock.run(function()
            while state.stage == 2 do
                table.insert(state.data, state.voltage)
                crow.output[output_num].volts = state.voltage
                clock.sleep(state.clock_interval)
            end
        end)

    elseif state.stage == 2 then
        -- Stage 2 -> 0: Stop recording, dismiss modal, start playback
        CrowOutput.stop_recording_knob(output_num)
    end

    _seeker.screen_ui.set_needs_redraw()
end

-- Legacy function for backwards compatibility
function CrowOutput.record_knob(output_num)
    CrowOutput.toggle_knob_recording(output_num)
end

function CrowOutput.stop_recording_knob(output_num)
    local state = recording_states[output_num]
    local Modal = get_modal()

    -- Stop capture clock
    if state.capture_clock then
        clock.cancel(state.capture_clock)
        state.capture_clock = nil
    end

    -- Capture data before any resets
    local data = {}
    for i, v in ipairs(state.data) do
        data[i] = v
    end
    local interpolation_steps = state.interpolation_steps

    -- Show completion state briefly before dismissing
    if Modal then
        Modal.show_recording({
            get_data = get_recording_data(output_num),
            output_num = output_num,
            hint = "looping",
            on_key = function() return true end,  -- Block input during completion
            on_enc = function() return true end
        })
    end

    -- Apply crossfade to smooth the loop point
    if #data > 1 then
        local crossfade_pct = params:get("crow_" .. output_num .. "_knob_crossfade") / 100
        local crossfade_samples = math.floor(#data * crossfade_pct)

        if crossfade_samples > 0 and crossfade_samples < #data / 2 then
            for i = 1, crossfade_samples do
                local blend = i / crossfade_samples
                local end_idx = #data - crossfade_samples + i
                local start_idx = i
                data[end_idx] = data[end_idx] * (1 - blend) + data[start_idx] * blend
            end
        end

        -- Start playback immediately
        active_clocks["knob_playback_" .. output_num] = clock.run(function()
            local step = 1
            local substep = 0

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

    -- Dismiss modal and clean up after pause (keeps visualization during pause)
    clock.run(function()
        clock.sleep(2.0)
        if Modal then Modal.dismiss() end
        reset_recording_state(output_num)
        _seeker.ui_state.state.knob_recording_active = false
        if _seeker.arc and _seeker.arc.clear_display then _seeker.arc.clear_display() end
        _seeker.screen_ui.set_needs_redraw()
    end)
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

    local mode = get_output_mode(output_num)

    -- Knob Recorder: stop any running output, user controls voltage manually
    if mode == "Knob Recorder" then
        crow.output[output_num].volts = 0
        return
    end

    if mode == "LFO" then
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
        local half_cycle = timing.total_sec / 2

        crow.output[output_num].action = asl_loop({
            asl_to(min, half_cycle, shape),
            asl_to(max, half_cycle, shape)
        })
        crow.output[output_num]()
        return
    end

    if mode == "Looped Random" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local shape = params:string("crow_" .. output_num .. "_looped_random_shape")
        local quantize = params:get("crow_" .. output_num .. "_looped_random_quantize") == 1
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

        if quantize then
            local scale = params:get("scale_type")
            local root = params:get("root_note")
            crow.output[output_num].scale(scale)
        else
            crow.output[output_num].scale('none')
        end

        local function generate_asl_pattern()
            local stages = {}
            for i = 1, steps do
                local random_value = min + math.random() * (max - min)
                table.insert(stages, asl_to(random_value, time, shape))
            end

            crow.output[output_num].action = asl_loop(stages)
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

    if mode == "Clocked Random" then
        local input_number = params:get("crow_" .. output_num .. "_clocked_random_trigger")
        local min_value = params:get("crow_" .. output_num .. "_clocked_random_min")
        local max_value = params:get("crow_" .. output_num .. "_clocked_random_max")
        local shape = params:string("crow_" .. output_num .. "_clocked_random_shape")
        local quantize = params:get("crow_" .. output_num .. "_clocked_random_quantize") == 1

        local function generate_random_value()
            local random_value
            if quantize then
                random_value = math.random(min_value, max_value)
            else
                random_value = min_value + math.random() * (max_value - min_value)
            end

            crow.output[output_num].action = asl_once({ asl_to(random_value, 0.1, shape) })
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

    if mode == "Burst" then
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

    if mode == "Clock" then
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
                local gate_voltage = params:get("crow_" .. output_num .. "_clock_voltage")
                local gate_length = params:get("crow_" .. output_num .. "_clock_length") / 100
                local gate_time = timing.total_sec * gate_length

                crow.output[output_num].volts = gate_voltage
                clock.sleep(gate_time)
                crow.output[output_num].volts = 0

                clock.sync(timing.beats, timing.offset)
            end
        end

        setup_clock("crow_" .. output_num, clock_fn)
        return
    end

    if mode == "Pattern" or mode == "Euclidean" then
        local clock_interval = params:string("crow_" .. output_num .. "_clock_interval")
        local clock_modifier = params:string("crow_" .. output_num .. "_clock_modifier")
        local clock_offset = params:string("crow_" .. output_num .. "_clock_offset")
        local timing = get_clock_timing(clock_interval, clock_modifier, clock_offset)

        if not timing then
            crow.output[output_num].volts = 0
            return
        end

        if not pattern_states[output_num] or not pattern_states[output_num].pattern then
            if mode == "Pattern" then
                CrowOutput.generate_random_pattern(output_num)
            else
                CrowOutput.generate_euclidean_pattern(output_num)
            end
        end

        local clock_fn = function()
            while true do
                local voltage_param = mode == "Pattern" and "_pattern_voltage" or "_euclidean_voltage"
                local length_param = mode == "Pattern" and "_pattern_length" or "_euclidean_length"
                local gate_voltage = params:get("crow_" .. output_num .. voltage_param)
                local gate_length_pct = params:get("crow_" .. output_num .. "_gate_length") / 100
                local gate_time = timing.total_sec * gate_length_pct
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
        return
    end

    if mode == "Envelope" then
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
            local wait_time = cycle_time - envelope_time

            local stages = {}

            if mode == "ADSR" then
                local total_percent = attack_percent + decay_percent + release_percent
                local sustain_percent = math.max(0, 100 - total_percent)

                local attack_time = envelope_time * (attack_percent / 100)
                local decay_time = envelope_time * (decay_percent / 100)
                local sustain_time = envelope_time * (sustain_percent / 100)
                local release_time = envelope_time * (release_percent / 100)

                table.insert(stages, asl_to(max_voltage, attack_time, shape))
                table.insert(stages, asl_to(sustain_voltage, decay_time, shape))
                table.insert(stages, asl_to(sustain_voltage, sustain_time, shape))
                table.insert(stages, asl_to(0, release_time, shape))
            else
                local total_percent = attack_percent + release_percent
                local scale_factor = 100 / total_percent

                local attack_time = envelope_time * ((attack_percent * scale_factor) / 100)
                local release_time = envelope_time * ((release_percent * scale_factor) / 100)

                table.insert(stages, asl_to(max_voltage, attack_time, shape))
                table.insert(stages, asl_to(0, release_time, shape))
            end

            if wait_time > 0 then
                table.insert(stages, asl_to(0, wait_time, "now"))
            end

            return asl_loop(stages)
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

    if mode == "Random Walk" then
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
                    crow.output[output_num].action = asl_once({ asl_to(new_value, slew_time, shape) })
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

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")
        self.name = "Crow Output " .. selected_number

        local param_table = {}
        local output_num = selected_number
        local category = params:string("crow_" .. output_num .. "_category")
        local mode = get_output_mode(output_num)

        -- Update description based on selected mode
        self.description = MODE_DESCRIPTIONS[mode] or Descriptions.CROW_OUTPUT

        -- Header shows Crow output number and current mode
        table.insert(param_table, { separator = true, title = "Crow " .. output_num })
        table.insert(param_table, { id = "crow_" .. output_num .. "_category" })

        table.insert(param_table, { id = "crow_" .. output_num .. "_mode" })

        if mode ~= "Clocked Random" and mode ~= "Knob Recorder" then
            table.insert(param_table, { separator = true, title = "Timing" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_interval" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_modifier" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_offset" })
        end

        if mode == "Burst" then
            table.insert(param_table, { separator = true, title = "Burst" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_count" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_time", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_shape" })
        elseif mode == "Clock" then
            table.insert(param_table, { separator = true, title = "Gate" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_length", arc_multi_float = {10, 5, 1} })
        elseif mode == "Pattern" then
            table.insert(param_table, { separator = true, title = "Pattern" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_pattern_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_pattern_length" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_pattern_hits" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_pattern_reroll", is_action = true })
        elseif mode == "Euclidean" then
            table.insert(param_table, { separator = true, title = "Euclidean" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_euclidean_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_euclidean_length" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_euclidean_hits" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_euclidean_rotation" })
        elseif mode == "LFO" then
            table.insert(param_table, { separator = true, title = "Shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif mode == "Looped Random" then
            table.insert(param_table, { separator = true, title = "Shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_quantize" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_steps" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_loops" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_looped_random_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif mode == "Clocked Random" then
            table.insert(param_table, { separator = true, title = "Clocked Random" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_trigger" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_quantize" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clocked_random_max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif mode == "Knob Recorder" then
            table.insert(param_table, { separator = true, title = "Knob Recorder" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_sensitivity", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_crossfade", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_start_recording", is_action = true })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_clear", is_action = true })
        elseif mode == "Envelope" then
            table.insert(param_table, { separator = true, title = "Envelope" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_mode" })

            local envelope_mode = params:string("crow_" .. output_num .. "_envelope_mode")
            -- Visual Edit only for ADSR mode (at top of section)
            if envelope_mode == "ADSR" then
                table.insert(param_table, {
                    id = "crow_" .. output_num .. "_envelope_visual_edit",
                    is_action = true,
                    custom_name = "Visual Edit"
                })
            end

            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_duration", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_attack", arc_multi_float = {10, 5, 1} })

            if envelope_mode == "ADSR" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_decay", arc_multi_float = {10, 5, 1} })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_sustain", arc_multi_float = {10, 5, 1} })
            end

            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_release", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_shape" })
        elseif mode == "Random Walk" then
            table.insert(param_table, { separator = true, title = "Random Walk" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_mode" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_slew", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_walk_max", arc_multi_float = {1.0, 0.1, 0.01} })

            local walk_mode = params:string("crow_" .. output_num .. "_random_walk_mode")
            if walk_mode == "Accumulate" then
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

      -- Check if output is enabled based on mode
      local output_mode = get_output_mode(output_num)
      local is_enabled = false
      if output_mode == "Clocked Random" then
        is_enabled = params:get("crow_" .. output_num .. "_clocked_random_trigger") > 0
      elseif output_mode ~= "Knob Recorder" then
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
    params:add_group("crow_output", "CROW OUTPUT", 212)

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

        -- Mode param - index into GATE_MODES or CV_MODES based on category
        local output_idx = i
        params:add_number("crow_" .. i .. "_mode", "Mode", 1, 6, 1, function(param)
            local category = params:string("crow_" .. output_idx .. "_category")
            local modes = category == "Gate" and GATE_MODES or CV_MODES
            local idx = math.min(param:get(), #modes)
            return modes[idx]
        end)
        params:set_action("crow_" .. i .. "_mode", function(value)
            -- Reset pattern state when mode changes
            pattern_states[i] = nil
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Clock parameters (simple clocked gate)
        params:add_control("crow_" .. i .. "_clock_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_clock_voltage", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_control("crow_" .. i .. "_clock_length", "Gate Length", controlspec.new(1, 100, 'lin', 1, 25), function(param) return params:get(param.id) .. "%" end)
        params:set_action("crow_" .. i .. "_clock_length", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Shared gate length for Pattern/Euclidean
        params:add_control("crow_" .. i .. "_gate_length", "Gate Length", controlspec.new(1, 100, 'lin', 1, 25), function(param) return params:get(param.id) .. "%" end)
        params:set_action("crow_" .. i .. "_gate_length", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Pattern parameters (random distribution)
        params:add_control("crow_" .. i .. "_pattern_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_pattern_voltage", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_pattern_length", "Length", 1, 32, 8)
        params:set_action("crow_" .. i .. "_pattern_length", function(value)
            -- Clamp hits to not exceed length
            local hits = params:get("crow_" .. i .. "_pattern_hits")
            if hits > value then
                params:set("crow_" .. i .. "_pattern_hits", value)
            end
            CrowOutput.generate_random_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_pattern_hits", "Hits", 1, 32, 4)
        params:set_action("crow_" .. i .. "_pattern_hits", function(value)
            -- Clamp hits to not exceed length
            local length = params:get("crow_" .. i .. "_pattern_length")
            if value > length then
                params:set("crow_" .. i .. "_pattern_hits", length)
                return
            end
            CrowOutput.generate_random_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_binary("crow_" .. i .. "_pattern_reroll", "Reroll", "trigger", 0)
        params:set_action("crow_" .. i .. "_pattern_reroll", function(value)
            CrowOutput.reroll_pattern(i)
        end)

        -- Euclidean parameters (Bjorklund algorithm)
        params:add_control("crow_" .. i .. "_euclidean_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_euclidean_voltage", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_euclidean_length", "Length", 1, 32, 8)
        params:set_action("crow_" .. i .. "_euclidean_length", function(value)
            -- Clamp hits to not exceed length
            local hits = params:get("crow_" .. i .. "_euclidean_hits")
            if hits > value then
                params:set("crow_" .. i .. "_euclidean_hits", value)
            end
            CrowOutput.generate_euclidean_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_euclidean_hits", "Hits", 1, 32, 4)
        params:set_action("crow_" .. i .. "_euclidean_hits", function(value)
            -- Clamp hits to not exceed length
            local length = params:get("crow_" .. i .. "_euclidean_length")
            if value > length then
                params:set("crow_" .. i .. "_euclidean_hits", length)
                return
            end
            CrowOutput.generate_euclidean_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_euclidean_rotation", "Rotation", 0, 31, 0)
        params:set_action("crow_" .. i .. "_euclidean_rotation", function(value)
            CrowOutput.generate_euclidean_pattern(i)
            CrowOutput.update_crow(i)
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

        params:add_binary("crow_" .. i .. "_looped_random_quantize", "Quantize", "toggle", 0)
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

        params:add_binary("crow_" .. i .. "_clocked_random_quantize", "Quantize", "toggle", 0)
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

        params:add_control("crow_" .. i .. "_knob_crossfade", "Loop Crossfade", controlspec.new(0, 50, 'lin', 1, 10), function(param)
            return params:get(param.id) .. "%"
        end)

        params:add_binary("crow_" .. i .. "_knob_start_recording", "Record", "trigger", 0)
        local output_idx = i  -- Capture for closure
        params:set_action("crow_" .. i .. "_knob_start_recording", function(value)
            -- Only trigger from stage 0 (idle) - prevents Arc/encoder re-triggering
            if value == 1 and recording_states[output_idx].stage == 0 then
                CrowOutput.record_knob(output_idx)
                _seeker.ui_state.trigger_activated("crow_" .. output_idx .. "_knob_start_recording")
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

        -- ADSR visual editor trigger
        local output_idx = i
        params:add_binary("crow_" .. i .. "_envelope_visual_edit", "Visual Edit", "trigger", 0)
        params:set_action("crow_" .. i .. "_envelope_visual_edit", function()
            local Modal = get_modal()
            if not Modal then return end

            -- Values normalized to 0-1 for modal visualization
            local function get_adsr_data()
                return {
                    a = params:get("crow_" .. output_idx .. "_envelope_attack") / 100,
                    d = params:get("crow_" .. output_idx .. "_envelope_decay") / 100,
                    s = params:get("crow_" .. output_idx .. "_envelope_sustain") / 100,
                    r = params:get("crow_" .. output_idx .. "_envelope_release") / 100
                }
            end

            Modal.show_adsr({
                get_data = get_adsr_data,
                param_ids = {
                    "crow_" .. output_idx .. "_envelope_attack",
                    "crow_" .. output_idx .. "_envelope_decay",
                    "crow_" .. output_idx .. "_envelope_sustain",
                    "crow_" .. output_idx .. "_envelope_release"
                }
            })
            _seeker.screen_ui.set_needs_redraw()
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
        record_knob = CrowOutput.record_knob,
        stop_recording_knob = CrowOutput.stop_recording_knob,
        clear_knob = CrowOutput.clear_knob
    }

    return component
end

return CrowOutput

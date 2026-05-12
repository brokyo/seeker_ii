-- crow_output.lua
-- Component for individual Crow output configuration (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")
local ArcPages = include("lib/modes/eurorack/arc_pages")

-- Use global Modal singleton
local function get_modal()
  return _seeker and _seeker.modal
end

local CrowOutput = {}
CrowOutput.__index = CrowOutput

-- Available output types for crow outputs
local CROW_TYPES = {"Rhythm", "Burst", "LFO", "Envelope", "Knob Rec", "Random"}

-- Short codes for CV monitor display
local TYPE_SHORT_CODES = {
    Rhythm = "RTH", Burst = "BST",
    LFO = "LFO", ["Knob Rec"] = "KR", Envelope = "ENV",
    Random = "RND"
}

-- Type descriptions for dynamic help
local TYPE_DESCRIPTIONS = {
  Rhythm = "Clock-synced rhythmic gate.\n\nWhen HITS = LENGTH, acts as a simple clock.\nDISTRIBUTION: Even uses Euclidean spacing, Random scatters hits.\nREROLL regenerates the random pattern.",
  Burst = "Rapid burst of triggers.\n\nWINDOW sets burst duration as percentage of clock period.\n\nSHAPE controls timing between triggers.",
  LFO = "Clock-synced LFO.",
  Envelope = "Clock-synced envelope.\n\nDURATION sets envelope time as percentage of clock period.",
  ["Knob Rec"] = "Record E3 knob movements as CV.\n\nK3 opens preview, K3 starts recording, K3 stops.\nK2 cancels.\n\nCROSSFADE smooths the loop point.",
  Random = "Random voltage generator.\n\nSOURCE: Clock for timed steps, Trigger for external input.\nSTEP: Jump picks new values, Accumulate drifts by STEP SIZE.\nSTEPS > 1 creates a looping sequence, LOOPS controls regeneration (0 = infinite)."
}

-- Returns the type name for a crow output
local function get_output_type(output_num)
  return params:string("crow_" .. output_num .. "_type")
end

-- Store active clock IDs globally
local active_clocks = {}

-- Store envelope states globally
local envelope_states = {}

-- Store pattern states globally for rhythmic patterns
local pattern_states = {}

-- Track which burst tick is currently firing (0 = between bursts)
local burst_states = {0, 0, 0, 0}

-- Store random walk states globally
local random_states = {}

-- Store knob recording state for each output
local recording_states = {}

-- Compute envelope stage times in seconds from beat params.
-- Attack, decay, and release are independent of cycle length; if their total exceeds one
-- cycle, the envelope is retriggered mid-flight at the next clock boundary.
-- Returns {mode, a, d, s, r, wait, cycle} for ADSR, or {mode, a, r, wait, cycle} for AR.
local function compute_envelope_times(output_num, cycle_sec)
    local env_mode = params:string("crow_" .. output_num .. "_envelope_mode")
    local beat_sec = clock.get_beat_sec()
    local a_beats = params:get("crow_" .. output_num .. "_envelope_attack")
    local r_beats = params:get("crow_" .. output_num .. "_envelope_release")

    if env_mode == "ADSR" then
        local d_beats = params:get("crow_" .. output_num .. "_envelope_decay")
        local a_sec = a_beats * beat_sec
        local d_sec = d_beats * beat_sec
        local r_sec = r_beats * beat_sec
        local s_sec = math.max(0, cycle_sec - a_sec - d_sec - r_sec)
        return { mode = "ADSR", a = a_sec, d = d_sec, s = s_sec, r = r_sec, wait = 0, cycle = cycle_sec }
    else
        local a_sec = a_beats * beat_sec
        local r_sec = r_beats * beat_sec
        local wait = math.max(0, cycle_sec - a_sec - r_sec)
        return { mode = "AR", a = a_sec, r = r_sec, wait = wait, cycle = cycle_sec }
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

-- Initialize random states for all 4 crow outputs
for i = 1, 4 do
    random_states[i] = {
        current_value = 0,
        initialized = false,
        history = {},
        history_max = 32
    }
end

-- Track current voltage for CV monitor screensaver
local cv_voltages = {0, 0, 0, 0}
local cv_cycle_starts = {0, 0, 0, 0}

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


-- Aliases to shared utilities
local get_clock_timing = EurorackUtils.get_clock_timing
local get_burst_intervals = EurorackUtils.get_burst_intervals

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

-- Rhythm pattern generation.
-- "Even" distribution uses Bjorklund (euclidean spacing).
-- "Random" distribution scatters hits randomly.
function CrowOutput.generate_rhythm_pattern(output_num)
    local length = params:get("crow_" .. output_num .. "_rhythm_length")
    local hits = math.min(params:get("crow_" .. output_num .. "_rhythm_hits"), length)
    local rotation = params:get("crow_" .. output_num .. "_rhythm_rotation")
    local distribution = params:string("crow_" .. output_num .. "_rhythm_distribution")

    if not pattern_states[output_num] then
        pattern_states[output_num] = { pattern = {}, current_step = 1 }
    end

    local pattern
    if distribution == "Even" then
        pattern = EurorackUtils.bjorklund(length, hits, rotation)
    else
        -- Random distribution
        pattern = {}
        local placed = 0
        while placed < hits do
            local pos = math.random(1, length)
            if not pattern[pos] then
                pattern[pos] = true
                placed = placed + 1
            end
        end
        for i = 1, length do
            if not pattern[i] then pattern[i] = false end
        end
        -- Apply rotation to random patterns too
        if rotation > 0 then
            local rotated = {}
            for i = 1, length do
                rotated[i] = pattern[((i - 1 + rotation) % length) + 1]
            end
            pattern = rotated
        end
    end

    pattern_states[output_num].pattern = pattern
    pattern_states[output_num].current_step = 1
    return pattern
end

function CrowOutput.reroll_pattern(output_num)
    CrowOutput.generate_rhythm_pattern(output_num)
    CrowOutput.update_crow(output_num)
    _seeker.screen_ui.set_needs_redraw()
end

-- Knob Rec functions
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

        -- Store crossfaded data back so live view viz can read it
        recording_states[output_num].data = data

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
                cv_voltages[output_num] = interpolated_voltage
                recording_states[output_num].playback_step = step

                substep = substep + 1
                if substep >= interpolation_steps then
                    substep = 0
                    step = next_step
                end

                clock.sleep(0.01)
            end
        end)
    end

    -- Dismiss modal and clean up after pause.
    -- Reset modal-related fields only — preserve data and playback_step for live view viz.
    clock.run(function()
        clock.sleep(2.0)
        if Modal then Modal.dismiss() end
        recording_states[output_num].stage = 0
        recording_states[output_num].voltage = 0
        recording_states[output_num].capture_clock = nil
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

-- Per-type update handlers. Each receives (output_num, prefix) and starts clocks as needed.

local function update_rhythm(output_num, prefix)
    local timing = get_clock_timing(
        params:string(prefix .. "clock_interval"),
        params:string(prefix .. "clock_modifier"),
        params:string(prefix .. "clock_offset"))
    if not timing then
        crow.output[output_num].volts = 0
        return
    end

    if not pattern_states[output_num] or not pattern_states[output_num].pattern then
        CrowOutput.generate_rhythm_pattern(output_num)
    end

    local clock_fn = function()
        while true do
            local gate_voltage = params:get(prefix .. "rhythm_voltage")
            local gate_pct = params:get(prefix .. "rhythm_gate_length") / 100
            local gate_time = timing.total_sec * gate_pct
            local swing_pct = params:get(prefix .. "rhythm_swing") / 100
            local prob = params:get(prefix .. "rhythm_probability")
            local pattern = pattern_states[output_num].pattern
            local step = pattern_states[output_num].current_step

            if step % 2 == 0 and swing_pct > 0 then
                clock.sleep(swing_pct * timing.total_sec * 0.5)
            end

            if pattern[step] and math.random(100) <= prob then
                crow.output[output_num].volts = gate_voltage
                cv_voltages[output_num] = gate_voltage
                clock.sleep(gate_time)
                crow.output[output_num].volts = 0
                cv_voltages[output_num] = 0
            end

            clock.sync(timing.beats, timing.offset)

            local next_step = step + 1
            if next_step > #pattern then next_step = 1 end
            pattern_states[output_num].current_step = next_step
        end
    end

    setup_clock("crow_" .. output_num, clock_fn)
end

local function update_burst(output_num, prefix)
    local timing = get_clock_timing(
        params:string(prefix .. "clock_interval"),
        params:string(prefix .. "clock_modifier"),
        params:string(prefix .. "clock_offset"))
    if not timing then
        crow.output[output_num].volts = 0
        return
    end

    local clock_fn = function()
        while true do
            local burst_voltage = params:get(prefix .. "burst_voltage")
            local burst_count = params:get(prefix .. "burst_count")
            local burst_time = params:get(prefix .. "burst_time")
            local burst_shape = params:string(prefix .. "burst_shape")

            local intervals = get_burst_intervals(burst_count, burst_time * timing.total_sec, burst_shape)

            for i = 1, burst_count do
                burst_states[output_num] = i
                crow.output[output_num].volts = burst_voltage
                cv_voltages[output_num] = burst_voltage
                clock.sleep(intervals[i] / 2)
                crow.output[output_num].volts = 0
                cv_voltages[output_num] = 0
                clock.sleep(intervals[i] / 2)
            end
            burst_states[output_num] = 0

            clock.sync(timing.beats, timing.offset)
        end
    end

    setup_clock("crow_" .. output_num, clock_fn)
end

local function update_lfo(output_num, prefix)
    local timing = get_clock_timing(
        params:string(prefix .. "clock_interval"),
        params:string(prefix .. "clock_modifier"),
        params:string(prefix .. "clock_offset"))
    if not timing then
        crow.output[output_num].volts = 0
        return
    end

    local shape = params:string(prefix .. "lfo_shape")
    local center = params:get(prefix .. "lfo_center")
    local depth = params:get(prefix .. "lfo_depth")
    local skew = params:get(prefix .. "lfo_skew")
    local min_v = math.max(-10, center - depth)
    local max_v = math.min(10, center + depth)

    -- Skew controls rise/fall time ratio: 0.5 = symmetric, 0.9 = slow rise fast fall
    local rise_time = timing.total_sec * skew
    local fall_time = timing.total_sec * (1 - skew)

    crow.output[output_num].action = asl_loop({
        asl_to(min_v, fall_time, shape),
        asl_to(max_v, rise_time, shape)
    })
    crow.output[output_num]()
    cv_cycle_starts[output_num] = util.time()
end

local function update_envelope(output_num, prefix)
    local timing = get_clock_timing(
        params:string(prefix .. "clock_interval"),
        params:string(prefix .. "clock_modifier"),
        params:string(prefix .. "clock_offset"))
    if not timing then
        crow.output[output_num].volts = 0
        return
    end

    envelope_states[output_num] = { active = true }

    -- Clock-synced retrigger: fire a one-shot ASL each cycle.
    -- If stages exceed cycle time, crow is mid-envelope when retriggered.
    local clock_fn = function()
        while true do
            local peak = params:get(prefix .. "envelope_peak")
            local sustain_v = params:get(prefix .. "envelope_sustain")
            local attack_shape = params:string(prefix .. "envelope_attack_shape")
            local release_shape = params:string(prefix .. "envelope_release_shape")

            local cycle_sec = timing.beats * clock.get_beat_sec()
            local t = compute_envelope_times(output_num, cycle_sec)
            local stages = {}

            if t.mode == "ADSR" then
                table.insert(stages, asl_to(peak, t.a, attack_shape))
                table.insert(stages, asl_to(sustain_v, t.d, release_shape))
                if t.s > 0 then
                    table.insert(stages, asl_to(sustain_v, t.s, "now"))
                end
                table.insert(stages, asl_to(0, t.r, release_shape))
            else
                table.insert(stages, asl_to(peak, t.a, attack_shape))
                table.insert(stages, asl_to(0, t.r, release_shape))
                if t.wait > 0 then
                    table.insert(stages, asl_to(0, t.wait, "now"))
                end
            end

            crow.output[output_num].action = asl_once(stages)
            crow.output[output_num]()
            cv_cycle_starts[output_num] = util.time()

            clock.sync(timing.beats, timing.offset)
        end
    end

    setup_clock("crow_" .. output_num, clock_fn)
end

local function update_knob_recorder(output_num, prefix)
    crow.output[output_num].volts = 0
end

local function update_random(output_num, prefix)
    local source = params:string(prefix .. "random_source")
    local center = params:get(prefix .. "random_center")
    local depth = params:get(prefix .. "random_depth")
    local shape = params:string(prefix .. "random_shape")
    local min_v = math.max(-10, center - depth)
    local max_v = math.min(10, center + depth)

    -- Triggered random: fire on crow input rising edge
    if source == "Trigger 1" or source == "Trigger 2" then
        local input_number = source == "Trigger 1" and 1 or 2
        crow.input[input_number].mode('change', 1.0, 0.1, 'rising')
        crow.input[input_number].change = function(state)
            if state then
                local v = min_v + math.random() * (max_v - min_v)
                cv_voltages[output_num] = v
                crow.output[output_num].action = asl_once({ asl_to(v, 0.1, shape) })
                crow.output[output_num]()
            end
        end
        local v = min_v + math.random() * (max_v - min_v)
        cv_voltages[output_num] = v
        crow.output[output_num].volts = v
        return
    end

    -- Clock source
    local timing = get_clock_timing(
        params:string(prefix .. "clock_interval"),
        params:string(prefix .. "clock_modifier"),
        params:string(prefix .. "clock_offset"))
    if not timing then
        crow.output[output_num].volts = 0
        return
    end

    local step_mode = params:string(prefix .. "random_step")
    local slew_beats = params:get(prefix .. "random_slew")
    local steps = params:get(prefix .. "random_steps")
    local loop_count = params:get(prefix .. "random_loop_count")

    if steps > 1 then
        -- Multi-step looping sequence
        local step_time = timing.total_sec

        local function generate_asl_pattern()
            local stages = {}
            for i = 1, steps do
                table.insert(stages, asl_to(min_v + math.random() * (max_v - min_v), step_time, shape))
            end
            crow.output[output_num].action = asl_loop(stages)
            crow.output[output_num]()
        end

        if loop_count == 0 then
            -- Infinite loop: generate once
            generate_asl_pattern()
        else
            -- Regenerate after N loops
            active_clocks["crow_" .. output_num] = clock.run(function()
                while true do
                    generate_asl_pattern()
                    clock.sync(steps * loop_count * timing.beats)
                end
            end)
        end
    else
        -- Single-step per clock tick (random walk behavior)
        if not random_states[output_num].initialized then
            if step_mode == "Accumulate" then
                random_states[output_num].current_value = center
            else
                random_states[output_num].current_value = min_v + math.random() * (max_v - min_v)
            end
            random_states[output_num].initialized = true
            crow.output[output_num].volts = random_states[output_num].current_value
        end

        local clock_fn = function()
            while true do
                local new_value
                if step_mode == "Jump" then
                    new_value = min_v + math.random() * (max_v - min_v)
                else
                    local step_size = params:get(prefix .. "random_step_size")
                    local step = (math.random() - 0.5) * 2 * step_size
                    new_value = random_states[output_num].current_value + step
                    -- Reflect at boundaries
                    if new_value > max_v then new_value = 2 * max_v - new_value
                    elseif new_value < min_v then new_value = 2 * min_v - new_value end
                    new_value = util.clamp(new_value, min_v, max_v)
                end

                random_states[output_num].current_value = new_value
                local hist = random_states[output_num].history
                table.insert(hist, new_value)
                if #hist > random_states[output_num].history_max then table.remove(hist, 1) end
                local slew_sec = slew_beats * clock.get_beat_sec()

                if slew_sec > 0 then
                    crow.output[output_num].action = asl_once({ asl_to(new_value, slew_sec, shape) })
                    crow.output[output_num]()
                else
                    crow.output[output_num].volts = new_value
                end

                clock.sync(timing.beats, timing.offset)
            end
        end

        setup_clock("crow_" .. output_num, clock_fn)
    end
end

-- Dispatch table: type name -> handler function
local update_handlers = {
    Rhythm             = update_rhythm,
    Burst              = update_burst,
    LFO                = update_lfo,
    Envelope           = update_envelope,
    ["Knob Rec"]  = update_knob_recorder,
    Random             = update_random,
}

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

    random_states[output_num].initialized = false

    local crow_type = get_output_type(output_num)
    local prefix = "crow_" .. output_num .. "_"
    local handler = update_handlers[crow_type]
    if handler then handler(output_num, prefix) end
end

---------------------------------------------------------------
-- Live view: single-output console with PageState frame
---------------------------------------------------------------
local crow_page_state = nil

local function crow_get_selected()
  return { source = "crow", num = params:get("eurorack_selected_number") }
end

local function crow_rebuild_page_state()
  local pages = ArcPages.build_pages_for_output(crow_get_selected())
  if crow_page_state then
    crow_page_state:set_pages(pages)
  else
    crow_page_state = PageState.new({ pages = pages })
  end
end

local function draw_crow_live()
  local selected = crow_get_selected()
  local states = CrowOutput.get_cv_states()
  local state = states[selected.num]

  crow_page_state:draw_frame({
    draw_fallback = function()
      screen.level(8); screen.rect(0, 52, 128, 12); screen.fill()
      screen.level(0); screen.move(2, 60); screen.text("Crow " .. selected.num)
    end,
    draw_header = function()
      local type_label = state and state.type or "---"
      local active = state and state.active
      screen.level(active and 12 or 4)
      screen.move(2, 7)
      screen.text("Crow " .. selected.num .. " — " .. type_label)
    end,
    draw_content = function(top, height)
      if state then ArcPages.draw_output_viz(state, top, height) end
    end,
  })
end

-- Screen UI

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CROW_OUTPUT",
        name = "Crow Output",
        description = Descriptions.CROW_OUTPUT,
        params = {},
    })

    norns_ui.needs_playback_refresh = true
    norns_ui.live_view_enabled = true

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        crow_rebuild_page_state()
        original_enter(self)
    end

    norns_ui.draw_live = function(self) draw_crow_live() end

    -- Initialize page state and wire arc/enc/key routing
    crow_rebuild_page_state()
    crow_page_state:wire(norns_ui, {
      after_delta = function(n)
        local page_def = crow_page_state.pages[crow_page_state.page]
        if not page_def then return end
        local slot = page_def.slots[n]
        if not slot or not slot.param_id then return end
        local selected = crow_get_selected()
        if slot.param_id == "crow_" .. selected.num .. "_type" then
          crow_rebuild_page_state()
        end
      end,
    })

    -- K3 starts knob recording when output type is Knob Rec
    local wired_handle_live_key = norns_ui.handle_live_key
    norns_ui.handle_live_key = function(self_ui, n, z)
      if n == 3 and z == 1 then
        local selected = crow_get_selected()
        if get_output_type(selected.num) == "Knob Rec" then
          CrowOutput.toggle_knob_recording(selected.num)
          return
        end
      end
      wired_handle_live_key(self_ui, n, z)
    end

    norns_ui.rebuild_params = function(self)
        local selected_number = params:get("eurorack_selected_number")
        self.name = "Crow Output " .. selected_number

        local param_table = {}
        local output_num = selected_number
        local crow_type = get_output_type(output_num)

        -- Update description based on selected type
        self.description = TYPE_DESCRIPTIONS[crow_type] or Descriptions.CROW_OUTPUT

        -- Header shows Crow output number and current type
        table.insert(param_table, { separator = true, title = "Crow " .. output_num })
        table.insert(param_table, { id = "crow_" .. output_num .. "_type" })

        -- Timing section (all types except Knob Rec and trigger-sourced Random)
        local show_timing = crow_type ~= "Knob Rec"
        if crow_type == "Random" then
            local source = params:string("crow_" .. output_num .. "_random_source")
            if source ~= "Clock" then show_timing = false end
        end
        if show_timing then
            table.insert(param_table, { separator = true, title = "Timing" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_interval" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_modifier" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_clock_offset" })
        end

        if crow_type == "Rhythm" then
            table.insert(param_table, { separator = true, title = "Rhythm" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_gate_length", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_swing", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_probability", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_length" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_hits" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_distribution" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_rotation" })
            local dist = params:string("crow_" .. output_num .. "_rhythm_distribution")
            if dist == "Random" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_rhythm_reroll", is_action = true })
            end
        elseif crow_type == "Burst" then
            table.insert(param_table, { separator = true, title = "Burst" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_voltage", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_count" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_time", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_burst_shape" })
        elseif crow_type == "LFO" then
            table.insert(param_table, { separator = true, title = "LFO" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_center", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_depth", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_lfo_skew", arc_multi_float = {0.1, 0.05, 0.01} })
        elseif crow_type == "Random" then
            table.insert(param_table, { separator = true, title = "Random" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_source" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_step" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_center", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_depth", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_shape" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_slew", arc_multi_float = {0.5, 0.1, 0.01} })

            local step_mode = params:string("crow_" .. output_num .. "_random_step")
            if step_mode == "Accumulate" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_random_step_size", arc_multi_float = {0.5, 0.1, 0.01} })
            end

            table.insert(param_table, { id = "crow_" .. output_num .. "_random_steps" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_random_loop_count" })
        elseif crow_type == "Knob Rec" then
            table.insert(param_table, { separator = true, title = "Knob Rec" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_sensitivity", arc_multi_float = {0.1, 0.05, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_crossfade", arc_multi_float = {10, 5, 1} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_start_recording", is_action = true })
            table.insert(param_table, { id = "crow_" .. output_num .. "_knob_clear", is_action = true })
        elseif crow_type == "Envelope" then
            table.insert(param_table, { separator = true, title = "Envelope" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_mode" })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_peak", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_attack", arc_multi_float = {0.5, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_attack_shape" })

            local envelope_mode = params:string("crow_" .. output_num .. "_envelope_mode")
            if envelope_mode == "ADSR" then
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_decay", arc_multi_float = {0.5, 0.1, 0.01} })
                table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_sustain", arc_multi_float = {1.0, 0.1, 0.01} })
            end

            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_release", arc_multi_float = {0.5, 0.1, 0.01} })
            table.insert(param_table, { id = "crow_" .. output_num .. "_envelope_release_shape" })
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
      local output_mode = get_output_type(output_num)
      local is_enabled = false
      if output_mode == "Random" then
        local source = params:string("crow_" .. output_num .. "_random_source")
        is_enabled = source ~= "Clock" or params:string("crow_" .. output_num .. "_clock_interval") ~= "Off"
      elseif output_mode ~= "Knob Rec" then
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
  -- First click selects output (preserves current page), second click cycles page
  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local output_num = (x - self.layout.x) + 1
      local current = _seeker.ui_state.get_current_section()
      local already_selected = current == "CROW_OUTPUT" and
        params:get("eurorack_selected_type") == 1 and
        params:get("eurorack_selected_number") == output_num

      if already_selected then
        crow_page_state:next_page()
      else
        params:set("eurorack_selected_type", 1) -- 1 = Crow
        params:set("eurorack_selected_number", output_num)
        crow_rebuild_page_state()
        _seeker.ui_state.set_current_section("CROW_OUTPUT")
      end
      _seeker.screen_ui.set_needs_redraw()
      _seeker.grid_ui.redraw()
    end
  end

  return grid_ui
end

-- Parameter creation

local function create_params()
    params:add_group("crow_output", "CROW OUTPUT", 168)

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

        -- Output type selection
        params:add_option("crow_" .. i .. "_type", "Type", CROW_TYPES, 1)
        params:set_action("crow_" .. i .. "_type", function(value)
            pattern_states[i] = nil
            if CROW_TYPES[value] == "Rhythm" then
                CrowOutput.generate_rhythm_pattern(i)
            end
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        -- Rhythm parameters (replaces Clock, Pattern, Euclidean)
        params:add_number("crow_" .. i .. "_rhythm_length", "Length", 1, 32, 8)
        params:set_action("crow_" .. i .. "_rhythm_length", function(value)
            local hits = params:get("crow_" .. i .. "_rhythm_hits")
            if hits > value then params:set("crow_" .. i .. "_rhythm_hits", value) end
            CrowOutput.generate_rhythm_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_rhythm_hits", "Hits", 1, 32, 8)
        params:set_action("crow_" .. i .. "_rhythm_hits", function(value)
            local length = params:get("crow_" .. i .. "_rhythm_length")
            if value > length then params:set("crow_" .. i .. "_rhythm_hits", length); return end
            CrowOutput.generate_rhythm_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_option("crow_" .. i .. "_rhythm_distribution", "Distribution", {"Even", "Random"}, 1)
        params:set_action("crow_" .. i .. "_rhythm_distribution", function(value)
            CrowOutput.generate_rhythm_pattern(i)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)
        params:add_number("crow_" .. i .. "_rhythm_rotation", "Rotation", 0, 31, 0)
        params:set_action("crow_" .. i .. "_rhythm_rotation", function(value)
            CrowOutput.generate_rhythm_pattern(i)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_rhythm_gate_length", "Gate Length", 1, 100, 25, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_rhythm_gate_length", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_control("crow_" .. i .. "_rhythm_voltage", "Voltage", controlspec.new(-10, 10, 'lin', 0.01, 5), function(param) return params:get(param.id) .. "v" end)
        params:set_action("crow_" .. i .. "_rhythm_voltage", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_rhythm_swing", "Swing", 0, 100, 0, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_rhythm_swing", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_number("crow_" .. i .. "_rhythm_probability", "Probability", 0, 100, 100, function(param) return param.value .. "%" end)
        params:set_action("crow_" .. i .. "_rhythm_probability", function(value)
            CrowOutput.update_crow(i)
        end)
        params:add_binary("crow_" .. i .. "_rhythm_reroll", "Reroll", "trigger", 0)
        params:set_action("crow_" .. i .. "_rhythm_reroll", function(value)
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
        params:add_control("crow_" .. i .. "_lfo_center", "Center", controlspec.new(-10, 10, 'lin', 0.01, 0), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_lfo_center", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_lfo_depth", "Depth", controlspec.new(0, 10, 'lin', 0.01, 5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_lfo_depth", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_lfo_shape", "Shape", EurorackUtils.shape_options, 1)
        params:set_action("crow_" .. i .. "_lfo_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_lfo_skew", "Skew", controlspec.new(0.05, 0.95, 'lin', 0.01, 0.5))
        params:set_action("crow_" .. i .. "_lfo_skew", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Random parameters
        params:add_option("crow_" .. i .. "_random_source", "Source", {"Clock", "Trigger 1", "Trigger 2"}, 1)
        params:set_action("crow_" .. i .. "_random_source", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_option("crow_" .. i .. "_random_step", "Step", {"Jump", "Accumulate"}, 1)
        params:set_action("crow_" .. i .. "_random_step", function(value)
            CrowOutput.update_crow(i)
            if _seeker and _seeker.eurorack and _seeker.eurorack.crow_output then
                _seeker.eurorack.crow_output.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end
        end)

        params:add_control("crow_" .. i .. "_random_center", "Center", controlspec.new(-10, 10, 'lin', 0.01, 0), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_random_center", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_depth", "Depth", controlspec.new(0, 10, 'lin', 0.01, 5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_random_depth", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_random_shape", "Shape", EurorackUtils.shape_options, 2)
        params:set_action("crow_" .. i .. "_random_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_slew", "Slew", controlspec.new(0, 4, 'lin', 0.01, 0.5), function(param) return string.format("%.2f beats", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_random_slew", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_random_step_size", "Step Size", controlspec.new(0.01, 5, 'lin', 0.01, 0.5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_random_step_size", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_random_steps", "Steps", 1, 32, 1)
        params:set_action("crow_" .. i .. "_random_steps", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_number("crow_" .. i .. "_random_loop_count", "Loops", 0, 32, 0)
        params:set_action("crow_" .. i .. "_random_loop_count", function(value)
            CrowOutput.update_crow(i)
        end)

        -- Knob Rec parameters
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

        params:add_control("crow_" .. i .. "_envelope_peak", "Peak", controlspec.new(0, 10, 'lin', 0.01, 5), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_envelope_peak", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_envelope_attack", "Attack", controlspec.new(0.01, 16, 'exp', 0.01, 0.25), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_envelope_attack", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_envelope_attack_shape", "Attack Shape", EurorackUtils.shape_options, 2)
        params:set_action("crow_" .. i .. "_envelope_attack_shape", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_envelope_decay", "Decay", controlspec.new(0.01, 16, 'exp', 0.01, 0.25), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_envelope_decay", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_envelope_sustain", "Sustain", controlspec.new(0, 10, 'lin', 0.01, 3), function(param) return string.format("%.2fv", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_envelope_sustain", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_control("crow_" .. i .. "_envelope_release", "Release", controlspec.new(0.01, 16, 'exp', 0.01, 0.5), function(param) return string.format("%.2f", params:get(param.id)) end)
        params:set_action("crow_" .. i .. "_envelope_release", function(value)
            CrowOutput.update_crow(i)
        end)

        params:add_option("crow_" .. i .. "_envelope_release_shape", "Release Shape", EurorackUtils.shape_options, 2)
        params:set_action("crow_" .. i .. "_envelope_release_shape", function(value)
            CrowOutput.update_crow(i)
        end)

    end
end

-- Apply ASL easing shape to a linear 0-1 parameter.
-- Approximates crow's built-in ASL shape curves.
local function apply_asl_shape(t, shape)
    if shape == "sine" then
        return (1 - math.cos(math.pi * t)) / 2
    elseif shape == "exponential" then
        return t * t * t
    elseif shape == "logarithmic" then
        return 1 - (1 - t) * (1 - t) * (1 - t)
    elseif shape == "now" then
        return 1
    elseif shape == "wait" then
        return t < 1 and 0 or 1
    elseif shape == "over" then
        return t < 0.7 and (t / 0.7) * 1.15 or 1.15 - 0.15 * ((t - 0.7) / 0.3)
    elseif shape == "under" then
        return t < 0.3 and -0.15 * (1 - t / 0.3) or -0.15 + 1.15 * ((t - 0.3) / 0.7)
    elseif shape == "rebound" then
        if t < 0.6 then return t / 0.6
        elseif t < 0.8 then return 1 - 0.15 * ((t - 0.6) / 0.2)
        else return 0.85 + 0.15 * ((t - 0.8) / 0.2) end
    end
    return t
end

-- Estimate current LFO voltage from elapsed time since cycle start.
-- ASL loop is: to(min, fall_time, shape) then to(max, rise_time, shape).
local function estimate_lfo_voltage(output_num)
    local center = params:get("crow_" .. output_num .. "_lfo_center")
    local depth = params:get("crow_" .. output_num .. "_lfo_depth")
    local shape = params:string("crow_" .. output_num .. "_lfo_shape")
    local skew = params:get("crow_" .. output_num .. "_lfo_skew")
    local min_v = math.max(-10, center - depth)
    local max_v = math.min(10, center + depth)
    local timing = get_clock_timing(
        params:string("crow_" .. output_num .. "_clock_interval"),
        params:string("crow_" .. output_num .. "_clock_modifier"),
        params:string("crow_" .. output_num .. "_clock_offset")
    )
    if not timing or timing.total_sec <= 0 then return min_v end

    local elapsed = util.time() - cv_cycle_starts[output_num]
    local phase = (elapsed % timing.total_sec) / timing.total_sec
    local fall_frac = 1 - skew
    -- First segment: fall (max -> min), second segment: rise (min -> max)
    if phase < fall_frac then
        local t = apply_asl_shape(phase / fall_frac, shape)
        return max_v - (max_v - min_v) * t
    else
        local t = apply_asl_shape((phase - fall_frac) / skew, shape)
        return min_v + (max_v - min_v) * t
    end
end

-- Estimate current envelope voltage from elapsed time since cycle start.
-- Uses compute_envelope_times() for stage durations. Applies per-stage ASL curves.
local function estimate_envelope_voltage(output_num)
    local timing = get_clock_timing(
        params:string("crow_" .. output_num .. "_clock_interval"),
        params:string("crow_" .. output_num .. "_clock_modifier"),
        params:string("crow_" .. output_num .. "_clock_offset")
    )
    if not timing or timing.total_sec <= 0 then return 0 end

    local peak = params:get("crow_" .. output_num .. "_envelope_peak")
    local sustain_v = params:get("crow_" .. output_num .. "_envelope_sustain")
    local a_shape = params:string("crow_" .. output_num .. "_envelope_attack_shape")
    local r_shape = params:string("crow_" .. output_num .. "_envelope_release_shape")

    local cycle_sec = timing.total_sec
    local t = compute_envelope_times(output_num, cycle_sec)
    local elapsed = (util.time() - cv_cycle_starts[output_num]) % cycle_sec

    if t.mode == "ADSR" then
        if elapsed < t.a then
            return peak * apply_asl_shape(elapsed / t.a, a_shape)
        elseif elapsed < t.a + t.d then
            local p = apply_asl_shape((elapsed - t.a) / t.d, r_shape)
            return peak - (peak - sustain_v) * p
        elseif elapsed < t.a + t.d + t.s then
            return sustain_v
        elseif elapsed < t.a + t.d + t.s + t.r then
            local p = apply_asl_shape((elapsed - t.a - t.d - t.s) / t.r, r_shape)
            return sustain_v * (1 - p)
        else
            return 0
        end
    else
        if elapsed < t.a then
            return peak * apply_asl_shape(elapsed / t.a, a_shape)
        elseif elapsed < t.a + t.r then
            local p = apply_asl_shape((elapsed - t.a) / t.r, r_shape)
            return peak * (1 - p)
        else
            return 0
        end
    end
end

-- Returns state table for each Crow output (1-4) for the CV monitor.
-- Base fields: { active, type, current, min, max }
-- Type-specific fields for visualization:
--   Rhythm: pattern (bool array), current_step (1-indexed)
--   LFO: phase (0-1), shape (string), skew (0-1)
--   Envelope: env_times ({a,d,s,r}), peak, sustain, elapsed_frac (0-1)
--   Random: voltage_history (array of recent values)
--   KR: recorded_data (voltage array), playback_pos (0-1)
function CrowOutput.get_cv_states()
    local states = {}
    for i = 1, 4 do
        local mode = get_output_type(i)
        local short = TYPE_SHORT_CODES[mode] or mode
        local clock_interval = params:string("crow_" .. i .. "_clock_interval")

        if mode == "Knob Rec" then
            local is_playing = active_clocks["knob_playback_" .. i] ~= nil
            local rec = recording_states[i]
            local pos = 0
            if is_playing and rec.data and #rec.data > 0 then
                pos = (rec.playback_step or 1) / #rec.data
            end
            states[i] = {
                active = is_playing, type = short, current = cv_voltages[i], min = -10, max = 10,
                recorded_data = rec.data, playback_pos = pos
            }

        elseif mode == "Rhythm" then
            local v = params:get("crow_" .. i .. "_rhythm_voltage")
            local ps = pattern_states[i]
            states[i] = {
                active = clock_interval ~= "Off", type = short, current = cv_voltages[i],
                min = math.min(0, v), max = math.max(0, v),
                pattern = ps and ps.pattern, current_step = ps and ps.current_step
            }

        elseif mode == "Burst" then
            local v = params:get("crow_" .. i .. "_burst_voltage")
            states[i] = {
                active = clock_interval ~= "Off", type = short, current = cv_voltages[i],
                min = math.min(0, v), max = math.max(0, v),
                burst_count = params:get("crow_" .. i .. "_burst_count"),
                burst_shape = params:string("crow_" .. i .. "_burst_shape"),
                burst_time = params:get("crow_" .. i .. "_burst_time"),
                burst_current_tick = burst_states[i],
            }

        elseif clock_interval == "Off" and mode ~= "Random" then
            states[i] = { active = false, type = short, current = 0, min = 0, max = 1 }
        elseif mode == "LFO" then
            local center = params:get("crow_" .. i .. "_lfo_center")
            local depth = params:get("crow_" .. i .. "_lfo_depth")
            local skew = params:get("crow_" .. i .. "_lfo_skew")
            local shape = params:string("crow_" .. i .. "_lfo_shape")
            local min_v = math.max(-10, center - depth)
            local max_v = math.min(10, center + depth)
            local timing = get_clock_timing(
                clock_interval,
                params:string("crow_" .. i .. "_clock_modifier"),
                params:string("crow_" .. i .. "_clock_offset")
            )
            local phase = 0
            if timing and timing.total_sec > 0 then
                local elapsed = util.time() - cv_cycle_starts[i]
                phase = (elapsed % timing.total_sec) / timing.total_sec
            end
            states[i] = {
                active = true, type = short, current = estimate_lfo_voltage(i),
                min = min_v, max = max_v,
                phase = phase, lfo_shape = shape, lfo_skew = skew
            }
        elseif mode == "Envelope" then
            local peak = params:get("crow_" .. i .. "_envelope_peak")
            local sustain_v = params:get("crow_" .. i .. "_envelope_sustain")
            local timing = get_clock_timing(
                clock_interval,
                params:string("crow_" .. i .. "_clock_modifier"),
                params:string("crow_" .. i .. "_clock_offset")
            )
            local env_times, elapsed_frac = nil, 0
            if timing and timing.total_sec > 0 then
                env_times = compute_envelope_times(i, timing.total_sec)
                elapsed_frac = ((util.time() - cv_cycle_starts[i]) % timing.total_sec) / timing.total_sec
            end
            states[i] = {
                active = true, type = short, current = estimate_envelope_voltage(i),
                min = 0, max = peak,
                env_times = env_times, peak = peak, sustain = sustain_v, elapsed_frac = elapsed_frac,
                attack_shape = params:string("crow_" .. i .. "_envelope_attack_shape"),
                release_shape = params:string("crow_" .. i .. "_envelope_release_shape"),
            }
        elseif mode == "Random" then
            local center = params:get("crow_" .. i .. "_random_center")
            local depth = params:get("crow_" .. i .. "_random_depth")
            local min_v = math.max(-10, center - depth)
            local max_v = math.min(10, center + depth)
            local source = params:string("crow_" .. i .. "_random_source")
            local is_active = source ~= "Clock" or clock_interval ~= "Off"
            states[i] = {
                active = is_active, type = short, current = random_states[i].current_value,
                min = min_v, max = max_v,
                voltage_history = random_states[i].history
            }
        else
            states[i] = { active = false, type = short, current = 0, min = 0, max = 1 }
        end
        -- Tag for transport icon hold matching
        states[i]._source = "crow"
        states[i]._num = i
    end
    return states
end

-- Sync all crow outputs by restarting their clocks
function CrowOutput.sync()
    -- Ensure i2c pullup resistors are active (crow.reset() can disable them)
    crow.ii.pullup(true)
    for i = 1, 4 do
        CrowOutput.update_crow(i)
    end
end

function CrowOutput.init()
    create_params()

    -- Generate initial rhythm patterns (default type is Rhythm)
    for i = 1, 4 do
        CrowOutput.generate_rhythm_pattern(i)
    end

    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = CrowOutput.sync,
        record_knob = CrowOutput.record_knob,
        stop_recording_knob = CrowOutput.stop_recording_knob,
        clear_knob = CrowOutput.clear_knob,
        get_cv_states = CrowOutput.get_cv_states
    }

    return component
end

return CrowOutput

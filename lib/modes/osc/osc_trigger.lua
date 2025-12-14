-- osc_trigger.lua
-- Component for OSC trigger outputs (1-4)

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local OscUtils = include("lib/modes/osc/osc_utils")
local Descriptions = include("lib/ui/component_descriptions")

local OscTrigger = {}
OscTrigger.__index = OscTrigger

-- Track which trigger is currently selected (1-4)
local selected_trigger = 1

-- Track active trigger clocks
local active_trigger_clocks = {}

-- Clamp envelope param if total exceeds 100%
local function clamp_envelope_if_needed(trigger_index, changed_param)
    local attack = params:get("osc_trigger_" .. trigger_index .. "_attack")
    local decay = params:get("osc_trigger_" .. trigger_index .. "_decay")
    local min_sustain = params:get("osc_trigger_" .. trigger_index .. "_min_sustain")
    local release = params:get("osc_trigger_" .. trigger_index .. "_release")

    local total = attack + decay + min_sustain + release

    if total > 100 then
        local excess = total - 100
        local current_value = params:get(changed_param)
        local clamped_value = math.max(0, current_value - excess)
        params:set(changed_param, clamped_value)
    end
end

-- Send trigger envelope parameters
local function send_trigger_envelope(trigger_index)
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

    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/attack", {attack_frac})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/decay", {decay_frac})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/min_sustain", {min_sustain_frac})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/release", {release_frac})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/min", {env_min})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/max", {env_max})
    _seeker.osc.send_message("/trigger/" .. trigger_index .. "/multiplier", {multiplier})
end

-- Send trigger pulse with explicit value
local function send_trigger_pulse(trigger_index, value)
    local path = "/trigger/" .. trigger_index .. "/pulse"
    _seeker.osc.send_message(path, {value})
end

-- Update trigger clock (start/stop trigger pulses)
local function update_trigger_clock(trigger_index)
    -- Stop existing clock if any
    if active_trigger_clocks["trigger_" .. trigger_index] then
        clock.cancel(active_trigger_clocks["trigger_" .. trigger_index])
        active_trigger_clocks["trigger_" .. trigger_index] = nil
    end

    local interval = params:string("osc_trigger_" .. trigger_index .. "_interval")
    local modifier = params:string("osc_trigger_" .. trigger_index .. "_modifier")
    local beats = OscUtils.interval_to_beats(interval) * OscUtils.modifier_to_value(modifier)

    if beats <= 0 or interval == "Off" then
        return
    end

    -- Create clock function for trigger pulses
    local function trigger_clock_function()
        local current_beat_sec = clock.get_beat_sec()

        while true do
            clock.sync(beats)

            local new_beat_sec = clock.get_beat_sec()
            if new_beat_sec ~= current_beat_sec then
                current_beat_sec = new_beat_sec
            end

            local gate_length = params:get("osc_trigger_" .. trigger_index .. "_env_gate_length") / 100

            send_trigger_pulse(trigger_index, 1)

            local gate_time_sec = beats * gate_length * current_beat_sec
            clock.sleep(gate_time_sec)

            send_trigger_pulse(trigger_index, 0)
        end
    end

    active_trigger_clocks["trigger_" .. trigger_index] = clock.run(trigger_clock_function)
end

local function create_params()
    params:add_group("osc_trigger", "OSC TRIGGER", 40)

    for i = 1, 4 do
        params:add_option("osc_trigger_" .. i .. "_interval", "Trigger " .. i .. " Interval", OscUtils.interval_options, 1)
        params:set_action("osc_trigger_" .. i .. "_interval", function(_)
            update_trigger_clock(i)
        end)

        params:add_option("osc_trigger_" .. i .. "_modifier", "Trigger " .. i .. " Modifier", OscUtils.modifier_options, OscUtils.DEFAULT_MODIFIER_INDEX)
        params:set_action("osc_trigger_" .. i .. "_modifier", function(_)
            update_trigger_clock(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_env_gate_length", "Trigger " .. i .. " Gate Length", controlspec.new(1.0, 99.0, 'lin', 0.1, 50.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_env_gate_length", function(value)
            if active_trigger_clocks["trigger_" .. i] then
                update_trigger_clock(i)
            end
        end)

        params:add_control("osc_trigger_" .. i .. "_attack", "Trigger " .. i .. " Attack", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_attack", function(value)
            clamp_envelope_if_needed(i, "osc_trigger_" .. i .. "_attack")
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_decay", "Trigger " .. i .. " Decay", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_decay", function(value)
            clamp_envelope_if_needed(i, "osc_trigger_" .. i .. "_decay")
            send_trigger_envelope(i)
        end)

        params:add_control("osc_trigger_" .. i .. "_min_sustain", "Trigger " .. i .. " Min Sustain", controlspec.new(0.0, 100.0, 'lin', 0.1, 25.0, "%"))
        params:set_action("osc_trigger_" .. i .. "_min_sustain", function(value)
            clamp_envelope_if_needed(i, "osc_trigger_" .. i .. "_min_sustain")
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
            clamp_envelope_if_needed(i, "osc_trigger_" .. i .. "_release")
            send_trigger_envelope(i)
        end)

        params:add_number("osc_trigger_" .. i .. "_env_multiplier", "Trigger " .. i .. " Multiplier", -100, 100, 1)
        params:set_action("osc_trigger_" .. i .. "_env_multiplier", function(value)
            send_trigger_envelope(i)
        end)
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "OSC_TRIGGER",
        name = "Trigger 1",
        description = Descriptions.OSC_TRIGGER,
        params = {}
    })

    -- Populate params before parent enter so Arc controller receives data
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    norns_ui.rebuild_params = function(self)
        self.name = string.format("Trigger %d", selected_trigger)

        local param_table = {
            { separator = true, title = "Timing" },
            { id = "osc_trigger_" .. selected_trigger .. "_interval", name = "Interval" },
            { id = "osc_trigger_" .. selected_trigger .. "_modifier", name = "Modifier" },
            { separator = true, title = "Envelope" },
            { id = "osc_trigger_" .. selected_trigger .. "_env_gate_length", name = "Gate Length", arc_multi_float = {10.0, 1.0, 0.1} },
            { id = "osc_trigger_" .. selected_trigger .. "_attack", name = "Attack", arc_multi_float = {10.0, 1.0, 0.1} },
            { id = "osc_trigger_" .. selected_trigger .. "_decay", name = "Decay", arc_multi_float = {10.0, 1.0, 0.1} },
            { id = "osc_trigger_" .. selected_trigger .. "_min_sustain", name = "Min Sustain", arc_multi_float = {10.0, 1.0, 0.1} },
            { id = "osc_trigger_" .. selected_trigger .. "_release", name = "Release", arc_multi_float = {10.0, 1.0, 0.1} },
            { separator = true, title = "Range" },
            { id = "osc_trigger_" .. selected_trigger .. "_env_min", name = "Min", arc_multi_float = {1.0, 0.1, 0.01} },
            { id = "osc_trigger_" .. selected_trigger .. "_env_max", name = "Max", arc_multi_float = {1.0, 0.1, 0.01} },
            { id = "osc_trigger_" .. selected_trigger .. "_env_multiplier", name = "Multiplier" }
        }

        self.params = param_table
    end

    return norns_ui
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "OSC_TRIGGER",
        layout = {
            x = 13,
            y = 7,
            width = 4,
            height = 1
        }
    })

    grid_ui.draw = function(self, layers)
        local current_section = _seeker.ui_state.get_current_section()
        local is_on_trigger_screen = current_section == "OSC_TRIGGER"

        for i = 0, 3 do
            local trigger_num = i + 1
            local is_selected = (trigger_num == selected_trigger)

            local brightness
            if is_selected and is_on_trigger_screen then
                brightness = GridConstants.BRIGHTNESS.UI.FOCUSED
            elseif is_selected then
                brightness = GridConstants.BRIGHTNESS.MEDIUM
            else
                brightness = GridConstants.BRIGHTNESS.UI.NORMAL
            end

            layers.ui[self.layout.x + i][self.layout.y] = brightness
        end
    end

    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            local trigger_num = (x - self.layout.x) + 1

            if trigger_num >= 1 and trigger_num <= 4 then
                selected_trigger = trigger_num

                _seeker.ui_state.set_current_section("OSC_TRIGGER")

                if _seeker.osc and _seeker.osc.trigger and _seeker.osc.trigger.screen then
                    _seeker.osc.trigger.screen:rebuild_params()
                    _seeker.screen_ui.set_needs_redraw()
                end

                return true
            end
        end

        return false
    end

    return grid_ui
end

-- Sync all triggers by restarting their clocks
function OscTrigger.sync()
    for clock_id, _ in pairs(active_trigger_clocks) do
        if active_trigger_clocks[clock_id] then
            clock.cancel(active_trigger_clocks[clock_id])
            active_trigger_clocks[clock_id] = nil
        end
    end

    for i = 1, 4 do
        update_trigger_clock(i)
    end
end

function OscTrigger.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui(),
        sync = OscTrigger.sync
    }
    create_params()

    -- Initialize OSC values with non-zero multiplier default
    for i = 1, 4 do
        params:set("osc_trigger_" .. i .. "_env_multiplier", 1)
        send_trigger_envelope(i)
        update_trigger_clock(i)
    end

    return component
end

return OscTrigger

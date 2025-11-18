-- osc_output.lua
-- Component for individual OSC output configuration (Float/LFO/Trigger 1-4)
-- Similar to lane_config - grid buttons select which output to configure

local NornsUI = include("lib/components/classes/norns_ui")

local OscOutput = {}
OscOutput.__index = OscOutput

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "OSC_OUTPUT",
        name = "OSC Output",
        description = "Configure individual OSC output. Use grid to select output.",
        params = {}
    })

    -- Override enter method to build initial params
    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        original_enter(self)
        self:rebuild_params()
    end

    -- Dynamic parameter rebuilding based on selected type and number
    -- Follows lane_config pattern: grid selection updates focused output
    norns_ui.rebuild_params = function(self)
        local selected_type = params:string("osc_selected_type")
        local selected_number = params:get("osc_selected_number")

        -- Update section name with current output
        self.name = string.format("%s %d", selected_type, selected_number)

        local param_table = {}

        -- Build type-specific parameters for the selected output
        if selected_type == "Float" then
            table.insert(param_table, { separator = true, title = "Float " .. selected_number })
            table.insert(param_table, { id = "osc_float_" .. selected_number .. "_value", name = "Value", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_float_" .. selected_number .. "_multiplier", name = "Multiplier" })
        elseif selected_type == "LFO" then
            table.insert(param_table, { separator = true, title = "LFO " .. selected_number })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_sync", name = "Sync" })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_shape", name = "Shape" })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_min", name = "Min", arc_multi_float = {1.0, 0.1, 0.01} })
            table.insert(param_table, { id = "osc_lfo_" .. selected_number .. "_max", name = "Max", arc_multi_float = {1.0, 0.1, 0.01} })
        elseif selected_type == "Trigger" then
            table.insert(param_table, { separator = true, title = "Trigger " .. selected_number })
            table.insert(param_table, { id = "osc_trigger_" .. selected_number .. "_sync", name = "Sync" })
            table.insert(param_table, { separator = true, title = "Envelope" })
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

        self.params = param_table
    end

    return norns_ui
end

function OscOutput.init()
    local component = {
        screen = create_screen_ui()
    }

    return component
end

return OscOutput

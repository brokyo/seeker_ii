-- keyboard.lua
-- Component for keyboard mode - represents musical/performance parameters

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")

local Keyboard = {}
Keyboard.__index = Keyboard

local function create_params()
    params:add_group("keyboard", "KEYBOARD", 14)

    -- Keyboard layout parameters (moved from config)
    params:add_number("keyboard_column_steps", "Column Spacing", 1, 8, 1)
    params:set_action("keyboard_column_steps", function(value)
        local theory = include('lib/theory_utils')
        theory.print_keyboard_layout()
    end)

    params:add_number("keyboard_row_steps", "Row Spacing", 1, 8, 2)
    params:set_action("keyboard_row_steps", function(value)
        local theory = include('lib/theory_utils')
        theory.print_keyboard_layout()
    end)

    -- Global tuning (moved from config)
    params:add_option("tuning_preset", "Preset",
        {"Custom", "Ethereal", "Mysterious", "Melancholic", "Hopeful", "Contemplative", "Triumphant", "Dreamy",
         "Ancient", "Floating", "Pastoral", "Nocturne", "Ritual", "Celestial", "Distant"}, 1)
    params:set_action("tuning_preset", function(value)
        if value > 1 then
            local presets = {{6, 7}, {3, 5}, {10, 2}, {8, 1}, {5, 2}, {1, 1}, {2, 1}, {3, 6},
                            {1, 10}, {8, 11}, {7, 12}, {5, 6}, {7, 7}, {11, 10}}
            local preset = presets[value - 1]
            params:set("root_note", preset[1], true)
            params:set("scale_type", preset[2], true)
            local theory = include('lib/theory_utils')
            theory.print_keyboard_layout()
        end
    end)

    params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
    params:set_action("root_note", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/theory_utils')
        theory.print_keyboard_layout()
    end)

    local musicutil = require('musicutil')
    local scale_names = {}
    for i = 1, #musicutil.SCALES do
        scale_names[i] = musicutil.SCALES[i].name
    end
    params:add_option("scale_type", "Scale", scale_names, 8)
    params:set_action("scale_type", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/theory_utils')
        theory.print_keyboard_layout()
    end)

    -- Global Effects (shared across all lanes)
    params:add_option("mxsamples_delay_rate", "Delay Rate",
        {"whole-note", "half-note", "quarter note", "eighth note", "sixteenth note", "thirtysecond"}, 4)
    params:set_action("mxsamples_delay_rate", function(value)
        local delay_rates = {4, 2, 1, 1/2, 1/4, 1/8}
        engine.mxsamples_delay_beats(delay_rates[value])
    end)

    params:add_control("mxsamples_delay_feedback", "Delay Feedback",
        controlspec.new(0, 100, 'lin', 1, 40, "%"))
    params:set_action("mxsamples_delay_feedback", function(value)
        engine.mxsamples_delay_feedback(value / 100)
    end)

    -- MIDI
    params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 1)
    params:add_number("record_midi_note", "Record Toggle Note", 0, 127, 0)
    params:add_number("overdub_midi_note", "Overdub Toggle Note", 0, 127, 0)
end

local function create_screen_ui()
    return NornsUI.new({
        id = "KEYBOARD",
        name = "Keyboard",
        description = "Musical keyboard and tuning configuration",
        params = {
            { separator = true, title = "Tuning" },
            { id = "tuning_preset" },
            { id = "root_note" },
            { id = "scale_type" },
            { separator = true, title = "Layout" },
            { id = "keyboard_column_steps" },
            { id = "keyboard_row_steps" },
            { separator = true, title = "Global Effects" },
            { id = "mxsamples_delay_rate" },
            { id = "mxsamples_delay_feedback" },
            { separator = true, title = "MIDI" },
            { id = "snap_midi_to_scale" },
            { id = "record_midi_note" },
            { id = "overdub_midi_note" }
        }
    })
end

local function create_grid_ui()
    local grid_ui = GridUI.new({
        id = "KEYBOARD",
        layout = {
            x = 16,
            y = 2,
            width = 1,
            height = 1
        }
    })

    -- Override handle_key to switch to KEYBOARD section
    grid_ui.handle_key = function(self, x, y, z)
        if z == 1 then
            _seeker.ui_state.set_current_section("KEYBOARD")
        end
    end

    return grid_ui
end

function Keyboard.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()

    return component
end

return Keyboard

-- keyboard.lua
-- Component for keyboard mode - represents musical/performance parameters

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")

local Keyboard = {}
Keyboard.__index = Keyboard

local function create_params()
    params:add_group("keyboard", "KEYBOARD", 9)

    -- Sync trigger
    params:add_binary("keyboard_sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("keyboard_sync_all_clocks", function(value)
        if value == 1 then
            if _seeker and _seeker.conductor then
                _seeker.conductor.sync_all()
            end
            _seeker.ui_state.trigger_activated("keyboard_sync_all_clocks")
        end
    end)

    -- Keyboard layout parameters (moved from config)
    params:add_number("keyboard_column_steps", "Column Spacing", 1, 8, 1)
    params:set_action("keyboard_column_steps", function(value)
        local theory = include('lib/motif_core/theory')
        theory.print_keyboard_layout()
    end)

    params:add_number("keyboard_row_steps", "Row Spacing", 1, 8, 4)
    params:set_action("keyboard_row_steps", function(value)
        local theory = include('lib/motif_core/theory')
        theory.print_keyboard_layout()
    end)

    -- Global tuning (moved from config)
    -- Tuning presets: curated root/scale combinations for emotional palettes
    -- Format: {root_note_index, scale_index} where root 1=C, scale per musicutil.SCALES
    params:add_option("tuning_preset", "Preset",
        {"Custom", "Ethereal", "Mysterious", "Melancholic", "Hopeful", "Contemplative", "Triumphant",
         "Dreamy", "Ancient", "Pastoral", "Nocturne", "Ritual", "Celestial",
         "Moss", "Temple", "Overworld", "Save Point"}, 17)
    params:set_action("tuning_preset", function(value)
        if value > 1 then
            local presets = {
                {6, 7},   -- Ethereal: F Lydian
                {2, 3},   -- Mysterious: C# Harmonic Minor
                {10, 2},  -- Melancholic: A Natural Minor
                {8, 1},   -- Hopeful: G Major
                {5, 5},   -- Contemplative: E Dorian
                {1, 1},   -- Triumphant: C Major
                {9, 7},   -- Dreamy: Ab Lydian
                {3, 6},   -- Ancient: D Phrygian
                {8, 11},  -- Pastoral: G Major Pentatonic
                {4, 3},   -- Nocturne: Eb Harmonic Minor
                {5, 6},   -- Ritual: E Phrygian
                {7, 7},   -- Celestial: F# Lydian
                {3, 44},  -- Moss: D In Sen Pou (Japanese ambient)
                {10, 42}, -- Temple: A Gagaku Ryo Sen Pou (Japanese court)
                {8, 8},   -- Overworld: G Mixolydian (adventure game)
                {4, 7},   -- Save Point: Eb Lydian (RPG rest moment)
            }
            local preset = presets[value - 1]
            params:set("root_note", preset[1], true)
            params:set("scale_type", preset[2], true)
            local theory = include('lib/motif_core/theory')
            theory.print_keyboard_layout()
        end
    end)

    params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
    params:set_action("root_note", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/motif_core/theory')
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
        local theory = include('lib/motif_core/theory')
        theory.print_keyboard_layout()
    end)

    -- MIDI
    params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 1)
    params:add_number("record_midi_note", "Record Toggle Note", 0, 127, 0)
    params:add_number("overdub_midi_note", "Overdub Toggle Note", 0, 127, 0)
end

local function create_screen_ui()
    return NornsUI.new({
        id = "KEYBOARD",
        name = "Keyboard Config",
        description = "Select the scale. Set keyboard intervals. Connect MIDI.",
        params = {
            { separator = true, title = "Actions" },
            { id = "keyboard_sync_all_clocks", is_action = true },
            { separator = true, title = "Tuning" },
            { id = "tuning_preset" },
            { id = "root_note" },
            { id = "scale_type" },
            { separator = true, title = "Layout" },
            { id = "keyboard_column_steps" },
            { id = "keyboard_row_steps" },
            { separator = true, title = "MIDI" },
            { id = "snap_midi_to_scale" },
            { id = "record_midi_note" },
            { id = "overdub_midi_note" }
        }
    })
end

local function create_grid_ui()
    -- No grid button - the KEYBOARD mode button at (16, 2) serves as virtual navigation
    -- ModeSwitcher handles switching to KEYBOARD mode and setting default section
    -- This pattern allows mode buttons to serve dual purpose: mode switching + component access
    return nil
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

-- tuning.lua
-- Global motif settings: tuning, scale, keyboard layout, and MIDI triggers

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local Descriptions = include("lib/ui/component_descriptions")

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
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    params:add_number("keyboard_row_steps", "Row Spacing", 1, 8, 4)
    params:set_action("keyboard_row_steps", function(value)
        local theory = include('lib/modes/motif/core/theory')
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
            local theory = include('lib/modes/motif/core/theory')
            theory.print_keyboard_layout()
        end
    end)

    params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
    params:set_action("root_note", function(value)
        params:set("tuning_preset", 1, true)
        local theory = include('lib/modes/motif/core/theory')
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
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    -- MIDI
    params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 1)

    local function midi_note_formatter(param)
        if param:get() == -1 then return "Off" end
        return param:get()
    end
    params:add_number("record_midi_note", "Record Toggle Note", -1, 127, -1, midi_note_formatter)
    params:add_number("overdub_midi_note", "Overdub Toggle Note", -1, 127, -1, midi_note_formatter)
end

-- Motif type constants
local MOTIF_TYPE_TAPE = 1

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "KEYBOARD",
        name = "Tuning",
        description = Descriptions.KEYBOARD,
        params = {}
    })

    -- Dynamic parameter rebuilding based on motif type
    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. lane_idx .. "_motif_type")

        local param_table = {
            { separator = true, title = "Actions" },
            { id = "keyboard_sync_all_clocks", is_action = true },
            { separator = true, title = "Tuning" },
            { id = "tuning_preset" },
            { id = "root_note" },
            { id = "scale_type" }
        }

        -- Tape mode: show lane-specific keyboard tuning (octave, grid offset)
        if motif_type == MOTIF_TYPE_TAPE then
            table.insert(param_table, { separator = true, title = "Lane " .. lane_idx .. " Tuning" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_keyboard_octave" })
            table.insert(param_table, { id = "lane_" .. lane_idx .. "_grid_offset" })
        end

        table.insert(param_table, { separator = true, title = "Layout" })
        table.insert(param_table, { id = "keyboard_column_steps" })
        table.insert(param_table, { id = "keyboard_row_steps" })
        table.insert(param_table, { separator = true, title = "MIDI" })
        table.insert(param_table, { id = "snap_midi_to_scale" })
        table.insert(param_table, { id = "record_midi_note", arc_multi_float = {10, 5, 1} })
        table.insert(param_table, { id = "overdub_midi_note", arc_multi_float = {10, 5, 1} })

        self.params = param_table
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    return norns_ui
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

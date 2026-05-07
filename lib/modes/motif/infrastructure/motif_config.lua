-- motif_config.lua
-- Global motif settings: tuning, scale, and keyboard layout

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local Descriptions = include("lib/ui/component_descriptions")

local MotifConfig = {}
MotifConfig.__index = MotifConfig

local function create_params()
    params:add_group("motif_config", "MOTIF CONFIG", 6)

    -- Sync trigger
    params:add_binary("motif_config_sync_all_clocks", "Synchronize All", "trigger", 0)
    params:set_action("motif_config_sync_all_clocks", function(value)
        if value == 1 then
            if _seeker and _seeker.conductor then
                _seeker.conductor.sync_all()
            end
            _seeker.ui_state.trigger_activated("motif_config_sync_all_clocks")
        end
    end)

    -- Keyboard layout parameters
    params:add_number("motif_config_column_steps", "Column Spacing", 1, 8, 1)
    params:set_action("motif_config_column_steps", function(value)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    params:add_number("motif_config_row_steps", "Row Spacing", 1, 8, 4)
    params:set_action("motif_config_row_steps", function(value)
        local theory = include('lib/modes/motif/core/theory')
        theory.print_keyboard_layout()
    end)

    -- Global tuning
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

end

-- Motif type constants
local MOTIF_TYPE_TAPE = 1

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "MOTIF",
        name = "Motif",
        description = Descriptions.MOTIF,
        params = {}
    })

    norns_ui.rebuild_params = function(self)
        self.params = {
            { id = "tuning_preset" },
            { id = "root_note" },
            { id = "scale_type" },
        }
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    return norns_ui
end

local function create_tape_home_screen()
    local norns_ui = NornsUI.new({
        id = "TAPE_HOME",
        name = "Tape Config",
        description = "Grid layout for the tape keyboard.\n\nColumn and row spacing control how notes are arranged on the grid.",
        params = {}
    })

    norns_ui.rebuild_params = function(self)
        self.params = {
            { id = "motif_config_column_steps" },
            { id = "motif_config_row_steps" },
        }
    end

    local original_enter = norns_ui.enter
    norns_ui.enter = function(self)
        self:rebuild_params()
        original_enter(self)
    end

    return norns_ui
end

function MotifConfig.init()
    local component = {
        screen = create_screen_ui(),
        tape_home_screen = create_tape_home_screen(),
    }
    create_params()

    return component
end

return MotifConfig

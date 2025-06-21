-- config.lua
-- Self-contained component for global configuration settings

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")
local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

local Config = {}
Config.__index = Config

local function create_params()
    params:add_group("config", "CONFIG", 9)
    
    -- Global Tuning
    params:add_option("tuning_preset", "Preset", 
        {"Custom", "Ethereal", "Mysterious", "Melancholic", "Hopeful", "Contemplative", "Triumphant", "Dreamy",
         "Ancient", "Floating", "Pastoral", "Nocturne", "Ritual", "Celestial", "Distant"}, 1)
    params:set_action("tuning_preset", function(value)
        if value > 1 then -- Skip action for "Custom"
            local presets = {{6, 7}, -- F Lydian
            {3, 5}, -- D Dorian
            {10, 2}, -- A Minor (Natural)
            {8, 1}, -- G Major
            {5, 2}, -- E Minor (Natural)
            {1, 1}, -- C Major
            {2, 1}, -- Db Major
            {3, 6}, -- D Phrygian
            {1, 10}, -- C Whole Tone
            {8, 11}, -- G Major Pentatonic (Pastoral)
            {7, 12}, -- F# Minor Pentatonic (Nocturne)
            {5, 6}, -- E Phrygian (Ritual)
            {7, 7}, -- F# Lydian (Celestial)
            {11, 10} -- Bb Whole Tone (Distant)
            }
            local preset = presets[value - 1]
            params:set("root_note", preset[1], true)
            params:set("scale_type", preset[2], true)
            theory.print_keyboard_layout()
        end
    end)
    
    params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
    params:set_action("root_note", function(value)
        -- Set tuning preset to custom when manually changing root
        params:set("tuning_preset", 1, true)
        theory.print_keyboard_layout()
    end)
    
    local scale_names = {}
    for i = 1, #musicutil.SCALES do
        scale_names[i] = musicutil.SCALES[i].name
    end
    params:add_option("scale_type", "Scale", scale_names, 8)
    params:set_action("scale_type", function(value)
        -- Set tuning preset to custom when manually changing scale
        params:set("tuning_preset", 1, true)
        theory.print_keyboard_layout()
    end)
    
    -- Clock
    params:add_control("clock_tempo", "BPM", controlspec.new(40, 200, 'lin', 1, 120), function(param) return params:get(param.id) .. " BPM" end)
    
    -- Visuals
    params:add_control("background_brightness", "Background Brightness", controlspec.new(0, 15, 'lin', 1, 4), function(param) return params:get(param.id) end)
    
    -- MIDI
    params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 1)
    params:add_number("record_midi_note", "Record Toggle Note", 0, 127, 0)
    params:add_number("overdub_midi_note", "Overdub Toggle Note", 0, 127, 0)
    
    params:add_binary("reset", "Clear Layers", "trigger", 0)
    params:set_action("reset", function(value)
        if value == 1 then
            for i = 1, 8 do
                if _seeker.lanes[i] then
                    _seeker.lanes[i]:clear()            
                    -- Reset all stage transforms to noop
                    for stage_idx = 1, 4 do
                        for transform_idx = 1, 3 do
                            _seeker.lanes[i]:change_stage_transform(i, stage_idx, transform_idx, "noop")
                        end
                    end
                end
            end
            print("⚡ Reset all layers")
        end
    end)
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "CONFIG",
        name = "Seeker II Config",
        description = "Global level configuration. Press k3 to trigger actions.",
        params = {
            { separator = true, title = "Global Tuning" },
            { id = "tuning_preset" },
            { id = "root_note" },
            { id = "scale_type" },
            { separator = true, title = "Clock" },
            { id = "clock_tempo" },
            { separator = true, title = "Visuals" },
            { id = "background_brightness" },
            { separator = true, title = "MIDI" },
            { id = "snap_midi_to_scale" },
            { id = "record_midi_note" },
            { id = "overdub_midi_note" },
            { separator = true, title = "Actions" },
            { id = "reset", is_action = true }
        }
    })
    
    return norns_ui
end

local function create_grid_ui()
    return GridUI.new({
        id = "CONFIG",
        layout = {
            x = 16,
            y = 2,
            width = 1,
            height = 1
        }
    })
end

function Config.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return Config 
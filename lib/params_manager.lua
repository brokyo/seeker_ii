local musicutil = require("musicutil")

local params_manager = {}

-- Store callbacks for different parameter changes
local callbacks = {
  scale_change = {},
  root_note_change = {},
  octave_change = {}
}

-- Helper to register callbacks
function params_manager.on_scale_change(callback_fn)
  print("Registering scale change callback")
  table.insert(callbacks.scale_change, callback_fn)
end

function params_manager.on_root_note_change(callback_fn)
  print("Registering root note change callback")
  table.insert(callbacks.root_note_change, callback_fn)
end

function params_manager.on_octave_change(callback_fn)
  print("Registering octave change callback")
  table.insert(callbacks.octave_change, callback_fn)
end

function params_manager.init_musical_params(skeys)
  local grid_ui = include('lib/grid')
  local theory = include('lib/theory_utils')
  
  -- Musical parameters
  params:add_group("MUSICAL", 3)
  
  -- Root note selection (0-11 representing C through B)
  params:add_option("root_note", "Root Note", 
    {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 
    1)
  
  -- Scale selection
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    scale_names[i] = musicutil.SCALES[i].name
  end
  params:add_option("scale_type", "Scale", scale_names, 1)
  
  -- Base octave selection
  params:add_number("base_octave", "Base Octave", 1, 7, 3)
  
  -- Sound parameters
  params:add_group("SOUND", 1)
  local instruments = {}
  for k,v in pairs(skeys.instrument) do
    table.insert(instruments, k)
  end
  table.sort(instruments)
  params:add_option("instrument", "Instrument", instruments, 1)
end

-- Register parameter actions after all initialization is complete
function params_manager.register_actions()
  local grid_ui = include('lib/grid')
  local theory = include('lib/theory_utils')
  
  params:set_action("root_note", function(value)
    print("Root note changed to: " .. (value - 1))
    grid_ui.root_note = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
  
  params:set_action("scale_type", function(value)
    print("Scale type changed to: " .. scale_names[value])
    grid_ui.scale_type = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
  
  params:set_action("base_octave", function(value)
    print("Base octave changed to: " .. value)
    grid_ui.base_octave = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
end

-- Helper function to convert root note option (1-12) to MIDI note number
function params_manager.get_current_root_midi_note()
  local root = (params:get("root_note") - 1)  -- Convert from 1-based index to 0-based note value
  local octave = params:get("base_octave")
  -- MIDI note 60 is middle C (C3), so we offset our octave calculation
  return root + ((octave + 2) * 12)  -- +2 to align with standard MIDI octave numbering
end

return params_manager 
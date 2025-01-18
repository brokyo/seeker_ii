-- Import required music utilities
local musicutil = require("musicutil")

local params_manager = {}

-- Helper function to get sorted list of instruments
function params_manager.get_instrument_list()
  local instruments = {}
  for k,v in pairs(_seeker.skeys.instrument) do
    table.insert(instruments, k)
  end
  table.sort(instruments)
  return instruments
end

-------------------------------------------
-- Initialize all parameters for the synth
-------------------------------------------
function params_manager.init_params()
  local grid_ui = include('lib/grid')
  local theory = include('lib/theory_utils')
  
  -------------------------------------------
  -- MUSICAL PARAMETERS GROUP
  -------------------------------------------
  params:add_group("MUSICAL", 3)
  
  -- Root note selection (C through B)
  -- Updates grid UI and keyboard layout when changed
  params:add_option("root_note", "Root Note", 
    {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 
    1)
  params:set_action("root_note", function(value)
    grid_ui.root_note = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
  
  -- Scale selection from musicutil.SCALES
  -- Updates grid UI and keyboard layout when changed
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    scale_names[i] = musicutil.SCALES[i].name
  end
  params:add_option("scale_type", "Scale", scale_names, 1)
  params:set_action("scale_type", function(value)
    grid_ui.scale_type = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
  
  -- Base octave selection (1-7, default 3)
  params:add_number("base_octave", "Base Octave", 1, 7, 3)
  
  -------------------------------------------
  -- SOUND PARAMETERS GROUP
  -------------------------------------------
  params:add_group("SOUND", 1)
  -- Global instrument selection
  local instruments = params_manager.get_instrument_list()
  params:add_option("instrument", "Instrument", instruments, 1)
  
  -------------------------------------------
  -- VOICE-SPECIFIC PARAMETERS
  -- Creates 4 identical voice groups with:
  -- - Instrument selection
  -- - Octave selection
  -------------------------------------------
  for i = 1,4 do
    params:add_group("VOICE " .. i, 2)
    
    -- Instrument selection for this voice
    -- Updates global instrument if this voice is selected
    local instruments = params_manager.get_instrument_list()
    params:add_option("voice_" .. i .. "_instrument", "Instrument", instruments, 1)
    params:set_action("voice_" .. i .. "_instrument", function(value)
      if _seeker.focused_voice == i then
        params:set("instrument", value)
      end
      if _seeker.conductor and _seeker.conductor.voices[i] then
        _seeker.conductor.voices[i].instrument = instruments[value]  -- Store actual name
      end
    end)
    
    -- Octave selection for this voice (1-7, default 3)
    -- Updates grid UI if this voice is selected
    params:add_number("voice_" .. i .. "_octave", "Octave", 1, 7, 3)
    params:set_action("voice_" .. i .. "_octave", function(value)
      if _seeker.focused_voice == i then
        grid_ui.base_octave = value
        grid_ui.redraw()
      end
      if _seeker.conductor and _seeker.conductor.voices[i] then
        _seeker.conductor.voices[i].octave = value
      end
    end)
  end
end

return params_manager 
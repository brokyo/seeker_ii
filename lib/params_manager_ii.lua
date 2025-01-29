-- params_manager_ii.lua
-- A clean start for params management, focused on core functionality

local params_manager_ii = {}
local musicutil = require('musicutil')

-- Get sorted list of available instruments
function params_manager_ii.get_instrument_list()
  local instruments = {}
  for k,v in pairs(_seeker.skeys.instrument) do
    table.insert(instruments, k)
  end
  table.sort(instruments)
  return instruments
end

function init_musical_params()
  params:add_group("MUSICAL", 3)

  -- Add root note selection
  params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 1)
  params:set_action("root_note", function(value)
    theory.print_keyboard_layout()
  end)

  -- Add scale selection
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    scale_names[i] = musicutil.SCALES[i].name
  end
  params:add_option("scale_type", "Scale", scale_names, 1)
  params:set_action("scale_type", function(value)
    theory.print_keyboard_layout()
  end)

  -- Add octave selection
  params:add_option("octave", "Octave", {1,2,3,4,5,6,7}, 3)
end

function init_recording_params()
  params:add_group("recording", "RECORDING", 1)
  params:add_option("quantize_division", "Quantize Division", 
    {"1/32", "1/24", "1/16", "1/12", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2"}, 7) 
end

function init_lane_params()
  local instruments = params_manager_ii.get_instrument_list()
  for i = 1,4 do
    params:add_group("lane_" .. i, "LANE " .. i, 1)
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)
  end 
end

-- Initialize just the essential parameters we need
function params_manager_ii.init_params()
  init_musical_params()
  init_recording_params()
  init_lane_params()
end

return params_manager_ii 

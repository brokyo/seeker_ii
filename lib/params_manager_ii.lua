-- params_manager_ii.lua
-- A clean start for params management, focused on core functionality

local params_manager_ii = {}
local musicutil = require('musicutil')
local theory = include('lib/theory_utils')
local transforms = include('lib/transforms')

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
    params:add_group("lane_" .. i, "LANE " .. i, 3)
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)
    params:add_control("lane_" .. i .. "_volume", "Volume", controlspec.new(0, 1, 'lin', 0.05, 1, ""))
    params:set_action("lane_" .. i .. "_volume", function(value)
      _seeker.lanes[i].volume = value
    end)
    params:add_control("lane_" .. i .. "_speed", "Speed", controlspec.new(0.1, 4, 'lin', 0.05, 1, ""))

    -- See forms.lua for stage configuration
    for j = 1, 4 do
      params:add_binary("lane_" .. i .. "_stage_" .. j .. "_mute", "Mute", "toggle", 0)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_mute", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)
      
      params:add_binary("lane_" .. i .. "_stage_" .. j .. "_reset_motif", "Reset Motif", "toggle", 0)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_reset_motif", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)
      
      params:add_number("lane_" .. i .. "_stage_" .. j .. "_loops", "Loops", 1, 10, 1)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_loops", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)

      -- Add transform selection
      local transform_names = {}
      for name, _ in pairs(transforms.available) do
        table.insert(transform_names, name)
      end
      table.sort(transform_names)  -- For consistent ordering
      
      params:add_option("lane_" .. i .. "_stage_" .. j .. "_transform", 
        "Transform", transform_names, #transform_names)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_transform", function(value)
        _seeker.lanes[i]:change_stage_transform(i, j, transform_names[value])
      end)
    end 
  end 
end

function params_manager_ii.init_params()
  params:add_separator("seeker_ii_header", "seeker_ii")
  init_musical_params()
  init_recording_params()
  init_lane_params()
end

return params_manager_ii 
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
  params:add_group("MUSICAL", 4)  -- Increased group size for new param

  -- Add root note selection
  params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
  params:set_action("root_note", function(value)
    theory.print_keyboard_layout()
  end)

  -- Add scale selection
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    scale_names[i] = musicutil.SCALES[i].name
  end
  params:add_option("scale_type", "Scale", scale_names, 8)
  params:set_action("scale_type", function(value)
    theory.print_keyboard_layout()
  end)

  -- Add clock pulse output
  params:add_option("clock_pulse_out", "Clock Pulse Out", {
    "none", 
    "crow 1", "crow 2", "crow 3", "crow 4",
    "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"
  }, 1)

  -- Add clock division
  params:add_option("clock_division", "Clock Division", {
    "off",
    "1 beat",
    "2 beats",
    "4 beats (bar)",
    "8 beats",
    "16 beats"
  }, 1)

  -- Set up the clock coroutine when either parameter changes
  local function setup_clock_coroutine()
    local pulse_out = params:get("clock_pulse_out")
    local division = params:get("clock_division")
    
    -- Clear existing clock coroutine if it exists
    if _seeker.clock_pulse_coroutine then
      clock.cancel(_seeker.clock_pulse_coroutine)
      _seeker.clock_pulse_coroutine = nil
    end
    
    -- Only start if we have an output and division selected
    if pulse_out > 1 and division > 1 then
      -- Convert division option to number of beats
      local beats = {1, 2, 4, 8, 16}
      local beat_count = beats[division - 1]
      
      _seeker.clock_pulse_coroutine = clock.run(function()
        while true do
          -- Send pulse
          if pulse_out <= 5 then
            -- Crow pulse
            crow.output[pulse_out - 1].volts = 5
            clock.sleep(0.01)  -- 10ms pulse
            crow.output[pulse_out - 1].volts = 0
          else
            -- TXO pulse
            crow.ii.txo.tr(pulse_out - 5, 1)
            clock.sleep(0.01)  -- 10ms pulse
            crow.ii.txo.tr(pulse_out - 5, 0)
          end
          
          -- Wait for next pulse
          clock.sync(beat_count)
        end
      end)
    end
  end

  -- Set up clock coroutine when either parameter changes
  params:set_action("clock_pulse_out", setup_clock_coroutine)
  params:set_action("clock_division", setup_clock_coroutine)
end

function init_recording_params()
  params:add_group("recording", "RECORDING", 3)  -- Reduced group size by 1
  
  -- Recording mode
  params:add_option("recording_mode", "Recording Mode", {"New", "Overdub"}, 1)
  
  -- Quantization settings
  params:add_option("quantize_division", "Quantize Division", 
    {"1/32", "1/24", "1/16", "1/12", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2"}, 6)
  
  -- Add sync lanes control
  params:add_binary("sync_lanes", "Sync Lanes", "toggle", 0)
  params:set_action("sync_lanes", function(value)
    if value == 1 then
      _seeker.conductor.sync_lanes()
      -- Auto-reset the toggle
      clock.run(function()
        clock.sleep(0.2)
        params:set("sync_lanes", 0)
        _seeker.update_ui_state()
      end)
    end
  end)
end

function init_lane_params()
  local instruments = params_manager_ii.get_instrument_list()
  for i = 1,4 do
    params:add_group("lane_" .. i, "LANE " .. i, 14) -- Increased group size for crow params
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)

    -- Octave selection for this lane
    params:add_number("lane_" .. i .. "_octave", "Octave", 1, 7, 3)

    -- MIDI Device
    local device_names = {"none"}
    for _, dev in pairs(midi.devices) do
      table.insert(device_names, dev.name)
    end
    params:add_option("lane_" .. i .. "_midi_device", "MIDI Device", device_names, 1)
    params:set_action("lane_" .. i .. "_midi_device", function(value)
      if value > 1 then
        _seeker.lanes[i].midi_out_device = midi.connect(value)
      end
    end)

    -- MIDI Channel
    params:add_number("lane_" .. i .. "_midi_channel", "MIDI Channel", 0, 16, 0)

    -- Crow parameters
    params:add_option("lane_" .. i .. "_gate_out", "Gate Out", {
      "none", 
      "crow 1", "crow 2", "crow 3", "crow 4",
      "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"
    }, 1)
    params:add_option("lane_" .. i .. "_cv_out", "CV Out", {
      "none", 
      "crow 1", "crow 2", "crow 3", "crow 4",
      "txo cv 1", "txo cv 2", "txo cv 3", "txo cv 4"
    }, 1)

    -- Volume
    params:add_control("lane_" .. i .. "_volume", "Volume", controlspec.new(0, 1, 'lin', 0.05, 1, ""))
    params:set_action("lane_" .. i .. "_volume", function(value)
      _seeker.lanes[i].volume = value
    end)
    
    -- Replace continuous speed with musical ratios
    params:add_option("lane_" .. i .. "_speed", "Speed", {
      "1/4x", "1/3x", "1/2x", "2/3x", "1x", "3/2x", "2x", "3x", "4x"
    }, 5)
    params:set_action("lane_" .. i .. "_speed", function(value)
      local speed_ratios = {0.25, 0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0, 4.0}
      if _seeker.lanes[i] then
        _seeker.lanes[i].speed = speed_ratios[value]
      end
    end)

    -- Add custom duration parameter
    params:add_number("lane_" .. i .. "_custom_duration", "Duration (beats)", 0, 64, 0)
    params:set_action("lane_" .. i .. "_custom_duration", function(value)
        if value == 0 then
          _seeker.lanes[i].motif.custom_duration = nil
        else
          _seeker.lanes[i].motif.custom_duration = value
        end
    end)

    -- See forms.lua for stage configuration
    for j = 1, 4 do
      params:add_binary("lane_" .. i .. "_stage_" .. j .. "_mute", "Mute", "toggle", 0)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_mute", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)
      
      -- Set reset_motif to 1 (true) for stage 1, 0 (false) for others
      params:add_binary("lane_" .. i .. "_stage_" .. j .. "_reset_motif", "Reset Motif", "toggle", j == 1 and 1 or 0)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_reset_motif", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)
      
      params:add_number("lane_" .. i .. "_stage_" .. j .. "_loops", "Loops", 1, 10, 4)  -- Changed default to 4
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_loops", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)

      -- Add loop end trigger
      params:add_option("lane_" .. i .. "_stage_" .. j .. "_loop_trigger", "Loop Trigger", {
        "none", 
        "crow 1", "crow 2", "crow 3", "crow 4",
        "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"
      }, 1)

      -- Add transform selection for each slot
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
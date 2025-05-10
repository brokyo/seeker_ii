-- params_manager_ii.lua
-- Manage norns-stored params

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
  params:add_group("CONFIG", 7)

  -- ** Tuning Presets **
  params:add_option("tuning_preset", "Tuning Preset", {
    "Custom",
    "Ethereal",
    "Mysterious",
    "Melancholic",
    "Hopeful",
    "Contemplative",
    "Triumphant",
    "Dreamy",
    "Ancient",
    "Floating"
  }, 1)
  params:set_action("tuning_preset", function(value)
    if value > 1 then  -- Skip action for "Custom"
      local presets = {
        {6, 7},    -- F Lydian
        {3, 5},    -- D Dorian
        {10, 2},   -- A Minor (Natural)
        {8, 1},    -- G Major
        {5, 2},    -- E Minor (Natural)
        {1, 1},    -- C Major
        {2, 1},    -- Db Major
        {3, 6},    -- D Phrygian
        {1, 12}    -- C Whole Tone
      }
      local preset = presets[value - 1]
      params:set("root_note", preset[1], true)
      params:set("scale_type", preset[2], true)
      theory.print_keyboard_layout()
    end
  end)

  -- ** Root Note **
  params:add_option("root_note", "Root Note", {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 6)
  params:set_action("root_note", function(value)
    -- Set tuning preset to custom when manually changing root
    params:set("tuning_preset", 1, true)
    theory.print_keyboard_layout()
  end)

  -- ** Scale **
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

  -- ** Clock Pulse Out **
  params:add_option("clock_pulse_out", "Clock Pulse Out", {
    "none", 
    "crow 1", "crow 2", "crow 3", "crow 4",
    "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"
  }, 1)

  -- ** Clock Division **
  params:add_option("clock_division", "Clock Division", {
    "off",
    "1/16",
    "1/8",
    "1/4",
    "1/2",
    "1x",
    "2x",
    "4x",
    "8x",
    "16x"
  }, 1)

  -- ** Background Brightness **
  params:add_number("background_brightness", "Background Brightness", 0, 15, 3)
  
  -- ** Snap MIDI to Scale **
  params:add_binary("snap_midi_to_scale", "Snap MIDI to Scale", "toggle", 0)
  params:set_action("snap_midi_to_scale", function(value)
    -- Nothing to do here, the value will be checked when MIDI notes are received
  end)

  -- ** Clock Coroutine **
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
      -- Convert division option to beat fraction
      local divisions = {1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16}
      local beat_division = divisions[division - 1]
      
      _seeker.clock_pulse_coroutine = clock.run(function()
        while true do
          -- Send pulse
          if pulse_out <= 5 then
            -- Crow pulse
            crow.output[pulse_out - 1].volts = 5
            clock.sleep(0.05)  -- 50ms pulse
            crow.output[pulse_out - 1].volts = 0
          else
            -- TXO pulse
            crow.ii.txo.tr(pulse_out - 5, 1)
            clock.sleep(0.05)  -- 50ms pulse
            crow.ii.txo.tr(pulse_out - 5, 0)
          end
          
          -- Wait for next pulse using division
          clock.sync(beat_division)
        end
      end)
    end
  end

  -- Set up clock division coroutine when either parameter changes
  params:set_action("clock_pulse_out", setup_clock_coroutine)
  params:set_action("clock_division", setup_clock_coroutine)
end

function init_recording_params()
  params:add_group("recording", "RECORDING", 5)
  
  -- Recording mode
  params:add_option("recording_mode", "Recording Mode", {"New", "Overdub"}, 1)
  
  -- Quantization settings
  params:add_option("quantize_division", "Quantize Division", 
    {"1/32", "1/24", "1/16", "1/12", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2"}, 2)
  
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

  -- Add MIDI notes for recording and overdub toggle (-1 = disabled)
  params:add_number("record_midi_note", "Record Toggle Key", -1, 127, -1)
  params:add_number("overdub_midi_note", "Overdub Toggle Key", -1, 127, -1)
end

function init_lane_params()
  local instruments = params_manager_ii.get_instrument_list()
  for i = 1,8 do
    params:add_group("lane_" .. i, "LANE " .. i, 39)
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)

    -- Keyboard octave control (for grid input)
    params:add_number("lane_" .. i .. "_keyboard_octave", "Keyboard Octave", 1, 7, 3)
    
    -- Grid offset (shifts starting position within scale)
    params:add_number("lane_" .. i .. "_grid_offset", "Grid Offset", -8, 8, 0)
    
    -- Playback octave offset
    params:add_number("lane_" .. i .. "_playback_offset", "Playback Offset", -3, 3, 0)
    
    -- Scale degree offset for in-scale transposition
    params:add_number("lane_" .. i .. "_scale_degree_offset", "Scale Degree Offset", -7, 7, 0)

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

    -- Add loop start trigger
    params:add_option("lane_" .. i .. "_loop_start_trigger", "Loop Start Trigger", {
      "none", 
      "crow 1", "crow 2", "crow 3", "crow 4",
      "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"
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
    params:add_control(
      "lane_" .. i .. "_custom_duration",
      "Duration (beats)",
      controlspec.new(
        0.25,           -- min
        128,            -- max
        'lin',          -- warp
        0.25,           -- step size
        0,              -- default
        "beats",        -- units
        0.25/128       -- quantum (ensure steps align properly)
      )
    )
    params:set_action("lane_" .. i .. "_custom_duration", function(value)
        if value == 0 then
          _seeker.lanes[i].motif.custom_duration = nil
        else
          _seeker.lanes[i].motif.custom_duration = value
        end
    end)

    -- Add pan control
    params:add_control("lane_" .. i .. "_pan", "Pan", controlspec.new(-1, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_pan", function(value)
      if _seeker.lanes[i] then
        -- Store pan value on lane for use during note playback
        _seeker.lanes[i].pan = value
      end
    end)

    -- Add filter controls with taper for better control
    params:add_taper(
      "lane_" .. i .. "_lpf", 
      "LPF Cutoff",
      20,     -- min
      20000,  -- max
      20000,  -- default (maximum = no filtering)
      3,      -- k (curve shape)
      "Hz"    -- units
    )
    params:set_action("lane_" .. i .. "_lpf", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].lpf = value
      end
    end)

    params:add_control("lane_" .. i .. "_resonance", "LPF Resonance", controlspec.new(0, 4, 'lin', 0.01, 0, ""))
    params:set_action("lane_" .. i .. "_resonance", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].resonance = value
      end
    end)

    -- Add high-pass filter with taper for better control
    params:add_taper(
      "lane_" .. i .. "_hpf", 
      "HPF Cutoff",
      20,    -- min
      20000, -- max
      20,    -- default (minimum = no filtering)
      3,     -- k (curve shape)
      "Hz"   -- units
    )
    params:set_action("lane_" .. i .. "_hpf", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].hpf = value
      end
    end)

    -- Add delay send
    params:add_control(
      "lane_" .. i .. "_delay_send",
      "Delay Send",
      controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01)
    )
    params:set_action("lane_" .. i .. "_delay_send", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].delay_send = value
      end
    end)

    -- Add reverb send
    params:add_control(
      "lane_" .. i .. "_reverb_send",
      "Reverb Send",
      controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01)
    )
    params:set_action("lane_" .. i .. "_reverb_send", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].reverb_send = value
      end
    end)

    -- Add ADSR envelope controls
    params:add_control(
      "lane_" .. i .. "_attack",
      "Attack",
      controlspec.new(0, 10, 'lin', 0.1, 0, "s")
    )
    params:set_action("lane_" .. i .. "_attack", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].attack = value
      end
    end)

    params:add_control(
      "lane_" .. i .. "_decay",
      "Decay",
      controlspec.new(0, 10, 'lin', 0.1, 1, "s")
    )
    params:set_action("lane_" .. i .. "_decay", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].decay = value
      end
    end)

    params:add_control(
      "lane_" .. i .. "_sustain",
      "Sustain",
      controlspec.new(0, 2, 'lin', 0.1, 0.9, "amp")
    )
    params:set_action("lane_" .. i .. "_sustain", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].sustain = value
      end
    end)

    params:add_control(
      "lane_" .. i .. "_release",
      "Release",
      controlspec.new(0, 10, 'lin', 0.1, 2, "s")
    )
    params:set_action("lane_" .. i .. "_release", function(value)
      if _seeker.lanes[i] then
        _seeker.lanes[i].release = value
      end
    end)

    -- Add Just Friends
    params:add_binary("lane_" .. i .. "_just_friends_active", "Just Friends Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_just_friends_active", function(value)
      -- Turn JF on or off based on parameter
      if value == 1 then
        print("⚡ Setting JF to synthesis mode...")
        crow.ii.jf.mode(1)
        -- Send a test note
        print("⚡ Sending test note to JF...")
        crow.ii.jf.play_note(0, 5) -- Play C4 at 5V velocity
      else
        print("⚡ Setting JF to off...")
        crow.ii.jf.mode(0)
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
      
      -- Set reset_motif to 1 (true) for all stages
      params:add_binary("lane_" .. i .. "_stage_" .. j .. "_reset_motif", "Reset Motif", "toggle", 1)
      params:set_action("lane_" .. i .. "_stage_" .. j .. "_reset_motif", function(value)
        if _seeker.lanes[i] then
          _seeker.lanes[i]:sync_stage_from_params(j)
        end
      end)
      
      params:add_number("lane_" .. i .. "_stage_" .. j .. "_loops", "Loops", 1, 10, 2)
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

-- Initialize MIDI input parameters
local function add_midi_input_params()
  params:add_group("midi_input", "MIDI INPUT", 1)
  
  -- MIDI input device selection (None = disabled)
  local midi_devices = {"None"}
  for i = 1, #midi.vports do
    local name = midi.vports[i].name or string.format("Port %d", i)
    table.insert(midi_devices, name)
  end
  
  params:add{
    type = "option",
    id = "midi_input_device",
    name = "MIDI Input Device",
    options = midi_devices,
    default = 2,  -- Default to first available device
    action = function(value)
      if _seeker.midi_input then
        if value > 1 then
          -- Enable MIDI and set device
          _seeker.midi_input.set_enabled(true)
          _seeker.midi_input.set_device(value - 1)
        else
          -- Disable MIDI input when "None" is selected
          _seeker.midi_input.set_enabled(false)
        end
      end
    end
  }
end

function params_manager_ii.init_params()
  params:add_separator("seeker_ii_header", "seeker_ii")
  init_musical_params()
  init_recording_params()
  init_lane_params()
  
  -- Add MIDI input parameters
  add_midi_input_params()
end

return params_manager_ii 
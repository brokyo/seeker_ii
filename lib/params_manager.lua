-- Import required music utilities
local musicutil = require("musicutil")

local params_manager = {
  -- Track parameter ranges for each lane
  lane_param_indices = {}  -- Will store {start_index, num_params} for each lane
}

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
  params:add_option("root_note", "Root Note", 
    {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}, 
    1)
  params:set_action("root_note", function(value)
    grid_ui.root_note = value
    grid_ui.redraw()
    theory.print_keyboard_layout()
  end)
  
  -- Scale selection from musicutil.SCALES
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
  -- LANE CONFIGURATION
  -- Each lane (1-4) has:
  -- 1. Voice settings (instrument, octave)
  -- 2. Playback settings (timing mode)
  -- 3. Stage configuration (4 stages with:
  --    - Active state
  --    - Loop count
  --    - Loop rest
  --    - Stage rest)
  -------------------------------------------
  for i = 1,4 do
    -- Calculate total params:
    -- 2 voice params + 1 timing mode + (4 stages * 4 params per stage)
    local params_per_lane = 2 + 1 + (4 * 4)
    
    -- Store the starting index before adding the group
    local start_index = #params.params + 1
    
    print("Creating param group for lane " .. i .. " with " .. params_per_lane .. " params starting at " .. start_index)
    params:add_group("LANE " .. i, params_per_lane)
    
    -- Store the parameter range for this lane
    params_manager.lane_param_indices[i] = {
      start_index = start_index,
      count = params_per_lane
    }
    
    -- Voice/Instrument Configuration
    local instruments = params_manager.get_instrument_list()
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)
    params:set_action("lane_" .. i .. "_instrument", function(value)
      if _seeker.conductor and _seeker.conductor.lanes[i] then
        _seeker.conductor.lanes[i].instrument = instruments[value]
      end
    end)
    
    params:add_number("lane_" .. i .. "_octave", "Octave", 1, 7, 3)
    params:set_action("lane_" .. i .. "_octave", function(value)
      if _seeker.focused_lane == i then
        grid_ui.base_octave = value
        grid_ui.redraw()
      end
      if _seeker.conductor and _seeker.conductor.lanes[i] then
        _seeker.conductor.lanes[i].octave = value
      end
    end)

    -- Timing Configuration
    params:add_option(
      "lane_" .. i .. "_timing_mode",
      "Timing Mode",
      {"free", "grid"},
      1
    )

    -- Stage Configuration
    -- We'll support 4 stages initially, but the conductor should not assume this number
    for stage = 1,4 do
      local stage_prefix = "lane_" .. i .. "_stage_" .. stage
      
      -- Stage active state
      params:add_option(
        stage_prefix .. "_active",
        "Stage " .. stage .. " Active",
        {"Off", "On"},
        stage == 1 and 2 or 1  -- First stage on by default
      )
      
      -- Loop count for this stage
      params:add_number(
        stage_prefix .. "_loop_count",
        "Stage " .. stage .. " Loops",
        1, 64, 4
      )
      
      -- Loop rest duration for this stage
      params:add_control(
        stage_prefix .. "_loop_rest",
        "Stage " .. stage .. " Loop Rest",
        controlspec.new(0, 16, 'lin', 1, 0, "bars")
      )
      
      -- Stage rest duration (after all loops complete)
      params:add_control(
        stage_prefix .. "_stage_rest",
        "Stage " .. stage .. " Rest",
        controlspec.new(0, 32, 'lin', 1, 0, "bars")
      )
    end
  end
end

-- Helper function to get parameters for a lane
function params_manager.get_lane_params(lane_num)
  local indices = params_manager.lane_param_indices[lane_num]
  if not indices then return {} end
  
  local lane_params = {}
  for i = indices.start_index, indices.start_index + indices.count - 1 do
    local param = params:lookup_param(i)
    if param then
      table.insert(lane_params, param)
    end
  end
  
  return lane_params
end

return params_manager 
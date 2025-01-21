-- Import required music utilities
local musicutil = require("musicutil")
local Log = include('lib/log')

local params_manager = {}
local MAX_STAGES = 4  -- Configurable number of stages

-- Track parameter ranges for each lane
local lane_param_indices = {}

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
  Log.log("PARAMS", "STATUS", string.format("%s Added MUSICAL group with 3 params", Log.ICONS.PARAMS))
  
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
    
    Log.log("PARAMS", "STATUS", string.format("%s Creating LANE %d group: %d params at index %d", Log.ICONS.PARAMS, i, params_per_lane, start_index))
    params:add_group("LANE " .. i, params_per_lane)
    
    -- Store the parameter range locally
    lane_param_indices[i] = {
      start_index = start_index,
      count = params_per_lane
    }
    
    -- Voice/Instrument Configuration
    local instruments = params_manager.get_instrument_list()
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)
    params:set_action("lane_" .. i .. "_instrument", function(value)
      if _seeker.focused_lane == i then
        grid_ui.instrument = instruments[value]
        grid_ui.redraw()
      end
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

    -- Add volume parameter
    params:add_control("lane_" .. i .. "_volume", "Volume", 
      controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_volume", function(value)
      if _seeker.conductor and _seeker.conductor.lanes[i] then
        _seeker.conductor.lanes[i].volume = value
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
    -- Support configurable number of stages
    for stage = 1,MAX_STAGES do
      local stage_prefix = "lane_" .. i .. "_stage_" .. stage
      
      -- Stage active state
      params:add_option(
        stage_prefix .. "_active",
        "Active",
        {"Off", "On"},
        stage == 1 and 2 or 1  -- First stage on by default
      )
      
      -- Loop count for this stage
      params:add_number(
        stage_prefix .. "_loop_count",
        "Loops",
        1, 64, 4
      )
      
      -- Loop rest duration for this stage
      params:add_control(
        stage_prefix .. "_loop_rest",
        "Loop Rest",
        controlspec.new(0, 16, 'lin', 1, 0, "bars")
      )
      
      -- Stage rest duration (after all loops complete)
      params:add_control(
        stage_prefix .. "_stage_rest",
        "Stage Rest",
        controlspec.new(0, 32, 'lin', 1, 0, "bars")
      )
    end

    -- Add keyboard offset parameters for each lane
    params:add_number(
      "lane_" .. i .. "_keyboard_x",
      "Lane " .. i .. " Keyboard X",
      -24, 24, 0
    )
    params:set_action("lane_" .. i .. "_keyboard_x", function(value)
      if _seeker and _seeker.ui_manager then
        _seeker.ui_manager:update_lane_param(i, "keyboard_x", value)
      end
    end)
    
    params:add_number(
      "lane_" .. i .. "_keyboard_y",
      "Lane " .. i .. " Keyboard Y",
      -24, 24, 0
    )
    params:set_action("lane_" .. i .. "_keyboard_y", function(value)
      if _seeker and _seeker.ui_manager then
        _seeker.ui_manager:update_lane_param(i, "keyboard_y", value)
      end
    end)
  end

  -- Set up global parameter action handler
  params.action_write = function(filename, name, number)
    -- Let the UI manager know about ALL parameter changes
    if _seeker and _seeker.conductor then
      -- Update conductor state
      for i = 1, 4 do
        local lane = _seeker.conductor.lanes[i]
        if lane then
          lane.keyboard_x = params:get("lane_" .. i .. "_keyboard_x")
          lane.keyboard_y = params:get("lane_" .. i .. "_keyboard_y")
        end
      end
    end
  end
end

-- Get parameter range information for a lane
function params_manager.get_lane_param_range(lane_num)
  return lane_param_indices[lane_num]
end

-- Get parameters for a specific category in a lane
function params_manager.get_lane_params(lane_num, category, stage_num)
  local indices = lane_param_indices[lane_num]
  if not indices then return nil end
  
  -- Find parameters matching the category
  local result = {}
  for i = indices.start_index, indices.start_index + indices.count - 1 do
    local param = params:lookup_param(i)
    if param then
      -- Match parameter to category based on id prefix
      local matches_category = false
      
      -- Voice-related parameters
      if category == "instrument" and param.id:match("^lane_" .. lane_num .. "_instrument$") then
        matches_category = true
      elseif category == "midi" and param.id:match("^lane_" .. lane_num .. "_octave$") then
        matches_category = true
      elseif category == "volume" and param.id:match("^lane_" .. lane_num .. "_volume$") then
        matches_category = true
      -- Transport parameters
      elseif category == "record" and param.id:match("^lane_" .. lane_num .. "_timing_mode$") then
        matches_category = true
      -- Stage-specific parameters
      elseif stage_num then
        local stage_pattern = "^lane_" .. lane_num .. "_stage_" .. stage_num
        if category == "stage_rest" and param.id:match(stage_pattern .. "_stage_rest$") then
          matches_category = true
        elseif category == "loop_rest" and param.id:match(stage_pattern .. "_loop_rest$") then
          matches_category = true
        elseif category == "loop_count" and param.id:match(stage_pattern .. "_loop_count$") then
          matches_category = true
        elseif category == "transform" and param.id:match(stage_pattern .. "_active$") then
          matches_category = true
        end
      end
      
      if matches_category then
        table.insert(result, {
          id = param.id,
          name = param.name,
          value = params:string(param.id),  -- Get formatted value
          min = param.min,
          max = param.max,
          type = param.t
        })
      end
    end
  end
  
  -- Handle keyboard position parameters
  if category == "keyboard_x" then
    table.insert(result, {
      id = "lane_" .. lane_num .. "_keyboard_x",
      name = "Keyboard X",
      value = params:get("lane_" .. lane_num .. "_keyboard_x"),
      min = -24,
      max = 24,
      type = "number"
    })
  elseif category == "keyboard_y" then
    table.insert(result, {
      id = "lane_" .. lane_num .. "_keyboard_y",
      name = "Keyboard Y",
      value = params:get("lane_" .. lane_num .. "_keyboard_y"),
      min = -24,
      max = 24,
      type = "number"
    })
  end
  
  return result
end

-- Debug utility
function params_manager.debug_params(lane_num)
  local indices = lane_param_indices[lane_num]
  if not indices then
    print("No parameters found for lane " .. lane_num)
    return
  end
  
  print(string.format("\nParameters for Lane %d:", lane_num))
  print(string.format("Range: %d to %d (%d params)", 
    indices.start_index, 
    indices.start_index + indices.count - 1,
    indices.count))
    
  for i = indices.start_index, indices.start_index + indices.count - 1 do
    local param = params:lookup_param(i)
    if param then
      print(string.format("\n[%d] %s", i, param.id))
      print("  name: " .. param.name)
      print("  value: " .. params:string(param.id))
      print("  type: " .. param.t)
    end
  end
end

return params_manager 
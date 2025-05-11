-- eurorack_output_section.lua
local Section = include('lib/ui/section')
local EurorackOutputSection = setmetatable({}, { __index = Section })
EurorackOutputSection.__index = EurorackOutputSection

local sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}
local sync_and_external_options = {"Off", "Crow 1", "Crow 2", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}

local shape_options = {"sine", "linear", "now", "wait", "over", "under", "rebound"}

function EurorackOutputSection.new()
  local section = Section.new({
    id = "EURORACK_OUTPUT",
    name = "Eurorack Output",
    description = "Configure Crow outputs for clock pulses and LFOs",
    params = {
      { separator = true, name = "Output Selection" },
      { id = "selected_output", name = "Output", spec = { type = "option", values = {
        "Crow 1", "Crow 2", "Crow 3", "Crow 4",
        "TXO TR 1", "TXO TR 2", "TXO TR 3", "TXO TR 4",
        "TXO CV 1", "TXO CV 2", "TXO CV 3", "TXO CV 4"
      }}}
    }
  })
  
  setmetatable(section, EurorackOutputSection)
  
  -- Initialize state with default values
  section.state.values = {
    selected_output = "Crow 1"
  }
  
  -- Store all possible parameters for each output
  section.state.output_params = {}
  
  -- Store active clock IDs
  section.state.active_clocks = {}
  
  -- Crow outputs (1-4)
  for i = 1, 4 do
    section.state.output_params["Crow " .. i] = {
      { id = "crow_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"Gate", "Burst", "LFO", "Looped Random", "Clocked Random"} } },
      { id = "crow_" .. i .. "_clock_div", name = "Clock Mod", spec = { type = "option", values = sync_options } },
      -- Burst parameters
      { id = "crow_" .. i .. "_burst_voltage", name = "Voltage", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "crow_" .. i .. "_burst_count", name = "Burst Count", spec = { type = "number", min = 1, max = 16 } },
      { id = "crow_" .. i .. "_burst_time", name = "Burst Window", spec = { type = "number", min = 0.01, max = 1, step = 0.01 } },
      -- Gate parameters
      { id = "crow_" .. i .. "_gate_voltage", name = "Voltage", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "crow_" .. i .. "_gate_length", name = "Gate Length %", spec = { type = "number", min = 1, max = 100, step = 1 } },
      -- LFO parameters
      { id = "crow_" .. i .. "_lfo_shape", name = "CV Shape", spec = { type = "option", values = shape_options} },
      { id = "crow_" .. i .. "_lfo_min", name = "CV Min", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "crow_" .. i .. "_lfo_max", name = "CV Max", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      -- Looped Random parameters
      { id = "crow_" .. i .. "_looped_random_shape", name = "Shape", spec = { type = "option", values = shape_options} },
      { id = "crow_" .. i .. "_looped_random_quantize", name = "Quantize", spec = { type = "option", values = {"On", "Off"} } },
      { id = "crow_" .. i .. "_looped_random_steps", name = "Steps", spec = { type = "number", min = 1, max = 32, step = 1 } },
      { id = "crow_" .. i .. "_looped_random_loops", name = "Loops", spec = { type = "number", min = 1, max = 32, step = 1 } },
      { id = "crow_" .. i .. "_looped_random_min", name = "Min Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "crow_" .. i .. "_looped_random_max", name = "Max Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      -- Clocked Random parameters
      { id = "crow_" .. i .. "_clocked_random_trigger", name = "Crow Input", spec = { type = "option", values = {0, 1, 2}} },
      { id = "crow_" .. i .. "_clocked_random_shape", name = "Shape", spec = { type = "option", values = shape_options} },
      { id = "crow_" .. i .. "_clocked_random_quantize", name = "Quantize", spec = { type = "option", values = {"On", "Off"} } },
      { id = "crow_" .. i .. "_clocked_random_min", name = "Min Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "crow_" .. i .. "_clocked_random_max", name = "Max Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } }
    }
    
    -- Initialize default values for Crow outputs
    section.state.values["crow_" .. i .. "_type"] = "Gate"
    section.state.values["crow_" .. i .. "_clock_div"] = "0"  -- Start Crow outputs off by default
    -- Burst Defaults
    section.state.values["crow_" .. i .. "_burst_voltage"] = 0
    section.state.values["crow_" .. i .. "_burst_count"] = 1
    section.state.values["crow_" .. i .. "_burst_time"] = 0.1
    -- Gate Defaults  
    section.state.values["crow_" .. i .. "_gate_voltage"] = 0
    section.state.values["crow_" .. i .. "_gate_length"] = 50
    -- LFO Defaults
    section.state.values["crow_" .. i .. "_lfo_shape"] = "sine"
    section.state.values["crow_" .. i .. "_lfo_min"] = -5
    section.state.values["crow_" .. i .. "_lfo_max"] = 5
    -- Looped Random Defaults
    section.state.values["crow_" .. i .. "_looped_random_shape"] = "now"
    section.state.values["crow_" .. i .. "_looped_random_quantize"] = "Off"
    section.state.values["crow_" .. i .. "_looped_random_steps"] = 1
    section.state.values["crow_" .. i .. "_looped_random_loops"] = 1
    section.state.values["crow_" .. i .. "_looped_random_min"] = -5
    section.state.values["crow_" .. i .. "_looped_random_max"] = 5
    -- Clocked Random Defaults
    section.state.values["crow_" .. i .. "_clocked_random_trigger"] = 0
    section.state.values["crow_" .. i .. "_clocked_random_shape"] = "now"
    section.state.values["crow_" .. i .. "_clocked_random_quantize"] = "Off"
    section.state.values["crow_" .. i .. "_clocked_random_min"] = -5
    section.state.values["crow_" .. i .. "_clocked_random_max"] = 5
  end

  -- TXO TR outputs (1-4)
  for i = 1, 4 do
    section.state.output_params["TXO TR " .. i] = {
      { id = "txo_tr_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"Gate", "Burst", "Stepped Random"} } },
      { id = "txo_tr_" .. i .. "_clock_div", name = "Beat Div/Mult", spec = { type = "option", values = sync_options } },
      -- Burst parameters
      { id = "txo_tr_" .. i .. "_burst_count", name = "Burst Count", spec = { type = "number", min = 1, max = 16 } },
      { id = "txo_tr_" .. i .. "_burst_time", name = "Burst Time", spec = { type = "number", min = 0.01, max = 1, step = 0.01 } },
      -- Gate parameters
      { id = "txo_tr_" .. i .. "_gate_length", name = "Gate Length %", spec = { type = "number", min = 1, max = 100, step = 1 } }
    }
    
    -- Initialize default values for TXO TR outputs
    section.state.values["txo_tr_" .. i .. "_type"] = "Gate"
    section.state.values["txo_tr_" .. i .. "_clock_div"] = "0"
    section.state.values["txo_tr_" .. i .. "_burst_count"] = 1
    section.state.values["txo_tr_" .. i .. "_burst_time"] = 0.1
    section.state.values["txo_tr_" .. i .. "_gate_length"] = 50
  end

  -- TXO CV outputs (1-4)
  for i = 1, 4 do
    section.state.output_params["TXO CV " .. i] = {
      { id = "txo_cv_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"LFO", "Stepped Random"} } },
      -- LFO parameters
      { id = "txo_cv_" .. i .. "_sync", name = "Clock Mod", spec = { type = "option", values = sync_options } },
      { id = "txo_cv_" .. i .. "_shape", name = "Shape", spec = { type = "option", values = {"Sine", "Triangle", "Saw", "Pulse", "Noise"} } },
      { id = "txo_cv_" .. i .. "_morph", name = "Morph", spec = { type = "number", min = -50, max = 50, step = 1 } },
      { id = "txo_cv_" .. i .. "_depth", name = "Depth", spec = { type = "number", min = 0, max = 10, step = 0.1 } },
      { id = "txo_cv_" .. i .. "_time", name = "Time", spec = { type = "number", min = 0.1, max = 20, step = 0.1 } },
      { id = "txo_cv_" .. i .. "_offset", name = "Offset", spec = { type = "number", min = -5, max = 5, step = 0.1 } },
      { id = "txo_cv_" .. i .. "_phase", name = "Phase", spec = { type = "number", min = 0, max = 360, step = 1 } },
      { id = "txo_cv_" .. i .. "_rect", name = "Rect", spec = { type = "option", values = {"Negative Half", "Negative Clipped", "Full Range", "Positive Clipped", "Positive Half"} } },
      -- Stepped Random parameters
      { id = "txo_cv_" .. i .. "_random_min", name = "Min Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "txo_cv_" .. i .. "_random_max", name = "Max Value", spec = { type = "number", min = -10, max = 10, step = 0.1 } },
      { id = "txo_cv_" .. i .. "_restart", name = "Restart", action = true, spec = { type = "action"} }
    }
    
    -- Initialize default values for TXO CV outputs
    section.state.values["txo_cv_" .. i .. "_type"] = "LFO"
    section.state.values["txo_cv_" .. i .. "_sync"] = "Off"
    section.state.values["txo_cv_" .. i .. "_shape"] = "Sine"
    section.state.values["txo_cv_" .. i .. "_morph"] = 0
    section.state.values["txo_cv_" .. i .. "_depth"] = 2.5
    section.state.values["txo_cv_" .. i .. "_time"] = 1
    section.state.values["txo_cv_" .. i .. "_offset"] = 0
    section.state.values["txo_cv_" .. i .. "_phase"] = 0
    section.state.values["txo_cv_" .. i .. "_rect"] = "Full Range"
    section.state.values["txo_cv_" .. i .. "_random_min"] = -5
    section.state.values["txo_cv_" .. i .. "_random_max"] = 5
  end

  -- Override get_param_value to handle action items
  function section:get_param_value(param)
    if param.action then
      return "► Press K3"
    else
      return self.state.values[param.id] or ""
    end
  end

  -- Helper method to update the appropriate output based on parameter ID
  function EurorackOutputSection:update_output_for_param(param_id)
    if param_id:match("^crow_%d+_") then
      local output_num = tonumber(param_id:match("crow_(%d+)_"))
      self:update_crow(output_num)
    elseif param_id:match("^txo_tr_%d+_") then
      local output_num = tonumber(param_id:match("txo_tr_(%d+)_"))
      self:update_txo_tr(output_num)
    elseif param_id:match("^txo_cv_%d+_") then
      local output_num = tonumber(param_id:match("txo_cv_(%d+)_"))
      self:update_txo_cv(output_num)
    end
  end

  -- Override modify_param to handle action items
  function section:modify_param(param, delta)
    -- TODO: Action should be on param.spec.type == "action"
    if param.action then
      if param.id:match("^txo_cv_%d+_restart$") then
        -- Restart all TXO CV LFOs
        for i = 1, 4 do
          self:update_txo_cv(i)
        end
        print("⚡ Restarted all LFOs")
      end
    elseif param.spec then
      if param.spec.type == "option" then
        local current_idx = 1
        for i, value in ipairs(param.spec.values) do
          if value == self.state.values[param.id] then
            current_idx = i
            break
          end
        end
        local new_idx = ((current_idx - 1 + delta) % #param.spec.values) + 1
        self.state.values[param.id] = param.spec.values[new_idx]
                
        -- If we changed the selected output or type, update the params list
        if param.id == "selected_output" or param.id:match("_type$") or param.id:match("_sync$") then
          self:update_param_list()
        end
        
        -- Update the relevant output
        self:update_output_for_param(param.id)
      elseif param.spec.type == "number" then
        local current = self.state.values[param.id]
        local step = param.spec.step or 1
        local new_value = current + (delta * step)
        self.state.values[param.id] = util.clamp(new_value, param.spec.min, param.spec.max)
        
        print("Number changed:", param.id, "to:", self.state.values[param.id])
        
        -- Update the relevant output
        self:update_output_for_param(param.id)
      end
    end
  end

  -- Override update_param_list to show only selected output's params
  function section:update_param_list()
    -- Start with output selection
    self.params = {
      { separator = true, name = "Output Selection" },
      { id = "selected_output", name = "Output", spec = { type = "option", values = {
        "Crow 1", "Crow 2", "Crow 3", "Crow 4",
        "TXO TR 1", "TXO TR 2", "TXO TR 3", "TXO TR 4",
        "TXO CV 1", "TXO CV 2", "TXO CV 3", "TXO CV 4"
      }}}
    }
    
    -- Get the selected output's parameters
    local output_params = section.state.output_params[self.state.values.selected_output]
    
    -- Add type parameter first
    table.insert(self.params, output_params[1])
    
    -- **crow**
    -- Create the param table for *Crow* outputs
    if self.state.values.selected_output:match("^Crow") then
      -- Get the output number (1-4)
      local output_num = tonumber(self.state.values.selected_output:match("%d+"))
      -- Get the  selected type for this output (Gate, Burst, LFO, or Stepped Random)
      local type = self.state.values["crow_" .. output_num .. "_type"]
      
      -- Insert clock mod parameter for all types except Clocked Random
      if type ~= "Clocked Random" then
        table.insert(self.params, output_params[2]) -- Division
      end
      
      -- Add type-specific parameters based on the selected output type
      if type == "Burst" then
        table.insert(self.params, output_params[3]) -- Burst Voltage
        table.insert(self.params, output_params[4]) -- Burst Count
        table.insert(self.params, output_params[5]) -- Burst Time
      elseif type == "Gate" then
        table.insert(self.params, output_params[6]) -- Gate Voltage
        table.insert(self.params, output_params[7]) -- Gate Length
      elseif type == "LFO" then
        table.insert(self.params, output_params[8]) -- Shape
        table.insert(self.params, output_params[9]) -- Min
        table.insert(self.params, output_params[10]) -- Max
      elseif type == "Looped Random" then
        table.insert(self.params, output_params[11]) -- Shape
        table.insert(self.params, output_params[12]) -- Quantize
        table.insert(self.params, output_params[13]) -- Steps
        table.insert(self.params, output_params[14]) -- Loops
        table.insert(self.params, output_params[15]) -- Min
        table.insert(self.params, output_params[16]) -- Max
      elseif type == "Clocked Random" then
        table.insert(self.params, output_params[17]) -- Trigger
        table.insert(self.params, output_params[18]) -- Shape
        table.insert(self.params, output_params[19]) -- Quantize
        table.insert(self.params, output_params[20]) -- Min
        table.insert(self.params, output_params[21]) -- Max
      end


    -- Create the param table for *TXO TR* outputs
    elseif self.state.values.selected_output:match("^TXO TR") then
      -- Extract the output number (1-4) from the selected TXO TR output
      local output_num = tonumber(self.state.values.selected_output:match("%d+"))
      -- Get the currently selected type for this TXO TR output
      local type = self.state.values["txo_tr_" .. output_num .. "_type"]
      
      -- Add division parameter for both Burst and Gate
      if type == "Burst" or type == "Gate" then
        table.insert(self.params, output_params[2]) -- Division
      end
      
      -- Add type-specific parameters
      if type == "Burst" then
        table.insert(self.params, output_params[3]) -- Burst Count
        table.insert(self.params, output_params[4]) -- Burst Time
      elseif type == "Gate" then
        table.insert(self.params, output_params[5]) -- Gate Length
      end


      -- Create the param table for *TXO CV* outputs
    else
      -- For TXO CV outputs (continuous voltage outputs on the TXo module)
      -- Extract the output number (1-4) from the selected TXO CV output
      local output_num = tonumber(self.state.values.selected_output:match("%d+"))
      -- Get the currently selected type for this TXO CV output (LFO or Stepped Random)
      local type = self.state.values["txo_cv_" .. output_num .. "_type"]
      
      -- Add type-specific parameters for TXO CV outputs
      if type == "LFO" then
        -- Get the sync setting to determine which parameters to show
        local sync = self.state.values["txo_cv_" .. output_num .. "_sync"]
        
        -- Add sync parameter
        table.insert(self.params, output_params[2])
        
        -- Add shape and morph
        table.insert(self.params, output_params[3])
        table.insert(self.params, output_params[4])
        
        -- Add depth
        table.insert(self.params, output_params[5])
        
        -- Add time parameter only if not synced to clock
        -- (when synced, timing is determined by clock division)
        if sync == "Off" then
          table.insert(self.params, output_params[6])
        end
        
        -- Add remaining LFO parameters
        table.insert(self.params, output_params[7]) -- Offset: DC offset (vertical shift)
        table.insert(self.params, output_params[8]) -- Phase: starting point in the waveform cycle
        table.insert(self.params, output_params[9]) -- Rect: rectification mode (how the wave is clipped)
        table.insert(self.params, output_params[13]) -- Restart: action to reset and restart the LFO
      elseif type == "Stepped Random" then
        -- Stepped Random mode parameters
        table.insert(self.params, output_params[2]) -- Sync: how often to generate new values
        
        -- Enforce that Stepped Random mode must be synced to clock
        -- (prevents continuous random changes)
        if self.state.values["txo_cv_" .. output_num .. "_sync"] == "Off" then
          self.state.values["txo_cv_" .. output_num .. "_sync"] = "1/8" -- Set a default sync value
        end
        
        table.insert(self.params, output_params[10]) -- min
        table.insert(self.params, output_params[11]) -- max
        table.insert(self.params, output_params[13]) -- restart
      end
    end
  end -- Close the update_param_list function

  -- Initialize param list
  section:update_param_list()
  
  -- Start clocks for all outputs by default
  for i = 1, 4 do
    section:update_crow(i)
    section:update_txo_tr(i)
    section:update_txo_cv(i)
  end
  
  return section
end

-- Helper function to convert division string to beats
function EurorackOutputSection:division_to_beats(div)
  -- Handle "0" as off
  if div == "0" then
    return 0
  end
  
  -- Handle integer values (1, 2, 3, etc)
  if tonumber(div) then
    return tonumber(div)
  end
  
  -- Handle fraction values (1/4, 1/16, etc)
  local num, den = div:match("(%d+)/(%d+)")
  if num and den then
    return tonumber(num)/tonumber(den)
  end
  
  return 1 -- default to quarter note
end

-- Update crow output when a parameter changes
function EurorackOutputSection:update_crow(output_num)
  -- Stop existing clock if any
  if self.state.active_clocks["crow_" .. output_num] then
    clock.cancel(self.state.active_clocks["crow_" .. output_num])
    self.state.active_clocks["crow_" .. output_num] = nil
  end

  -- Get clock parameters
  local type = self.state.values["crow_" .. output_num .. "_type"]
  
  -- Handle LFO mode
  if type == "LFO" then
    local clock_mod = self.state.values["crow_" .. output_num .. "_clock_div"]
    local shape = self.state.values["crow_" .. output_num .. "_lfo_shape"]
    local min = self.state.values["crow_" .. output_num .. "_lfo_min"]
    local max = self.state.values["crow_" .. output_num .. "_lfo_max"]
    
    -- Convert clock division to beats
    local beats = self:division_to_beats(clock_mod)
    
    -- If division is 0 or invalid, turn off the LFO
    if beats <= 0 or clock_mod == "Off" then
      crow.output[output_num].volts = 0
      return
    end
    
    -- Convert beats to seconds based on current tempo
    local beat_sec = clock.get_beat_sec()
    local time = beat_sec * beats
    
    -- Construct ASL string with dynamic values
    local asl_string = string.format("loop( { to(%f,%f,'%s'), to(%f,%f,'%s') } )", 
      min, time, shape, 
      max, time, shape)
    
    -- Set up LFO using Crow's ASL system
    crow.output[output_num].action = asl_string
    
    -- Start the LFO
    crow.output[output_num]()
    return
  end

  -- Handle Looped Random mode
  if type == "Looped Random" then
    -- Get relevant parameters
    local trigger = self.state.values["crow_" .. output_num .. "_clock_div"]
    local shape = self.state.values["crow_" .. output_num .. "_looped_random_shape"]
    local quantize = self.state.values["crow_" .. output_num .. "_looped_random_quantize"]
    local steps = self.state.values["crow_" .. output_num .. "_looped_random_steps"]
    local loops = self.state.values["crow_" .. output_num .. "_looped_random_loops"]
    local min = self.state.values["crow_" .. output_num .. "_looped_random_min"]
    local max = self.state.values["crow_" .. output_num .. "_looped_random_max"]
    
    -- If division is "off", turn off the output
    if trigger == "Off" or trigger == "0" then
      crow.output[output_num].volts = 0
      return
    end

    -- Convert trigger division to beats
    local trigger_beats = self:division_to_beats(trigger)
    local beat_sec = clock.get_beat_sec()
    local time = beat_sec * trigger_beats

    -- Set up scale quantization if enabled
    if quantize == "On" then
      -- Get scale from params
      local scale = params:get("scale_type")
      local root = params:get("root_note")
      -- Apply scale quantization to the output
      crow.output[output_num].scale(scale) -- 12TET, 1V/octave
    else
      -- Disable scale quantization
      crow.output[output_num].scale('none')
    end

    -- Function to generate and set new ASL pattern
    local function generate_asl_pattern()
      -- Create looped random asl
      local asl_steps = {}
      for i = 1, steps do
        -- Generate a random value between min and max
        local random_value = min + math.random() * (max - min)
        -- Construct an asl string
        local asl_step = string.format("to(%f, %f, '%s')", random_value, time, shape)
        table.insert(asl_steps, asl_step)
      end

      -- Create the final ASL loop string
      local asl_loop = string.format("loop( { %s } )", table.concat(asl_steps, ", "))

      -- Set action on Crow
      crow.output[output_num].action = asl_loop
      crow.output[output_num]()
    end
    
    -- Create clock function that regenerates pattern
    local function clock_function()
      while true do
        -- Generate initial pattern
        generate_asl_pattern()
        
        -- Wait for complete cycle (steps * loops * trigger_beats)
        local cycle_beats = steps * loops * trigger_beats
        clock.sync(cycle_beats)
      end
    end
    
    -- Start the clock
    self.state.active_clocks["crow_" .. output_num] = clock.run(clock_function)
    return
  end
  
  -- Handle Clocked Random mode
  if type == "Clocked Random" then
    local input_number = self.state.values["crow_" .. output_num .. "_clocked_random_trigger"]
    local min_value = self.state.values["crow_" .. output_num .. "_clocked_random_min"]
    local max_value = self.state.values["crow_" .. output_num .. "_clocked_random_max"]
    local shape = self.state.values["crow_" .. output_num .. "_clocked_random_shape"]
    local quantize = self.state.values["crow_" .. output_num .. "_clocked_random_quantize"]
    
    -- Function to generate and set new random value
    local function generate_random_value()
      local random_value
      if quantize == "On" then
        random_value = math.random(min_value, max_value)
      else
        random_value = min_value + math.random() * (max_value - min_value)
      end
      
      -- Create ASL string for the transition
      local asl_string = string.format("to(%f,%f,'%s')", random_value, time, shape)
      crow.output[output_num].action = asl_string
      crow.output[output_num]()
    end
    
    -- Stop any existing clock or input handler
    if self.state.active_clocks["crow_" .. output_num] then
      clock.cancel(self.state.active_clocks["crow_" .. output_num])
      self.state.active_clocks["crow_" .. output_num] = nil
    end
    
    -- Set up input handlers for Crow 1 and 2
    if input_number == 1 or input_number == 2 then
      -- Configure input to trigger on rising edge
      crow.input[input_number].mode('change', 1.0, 0.1, 'rising')
      
      -- Set up the change handler
      crow.input[input_number].change = function(state)
        if state then
          generate_random_value()
        end
      end
      
      -- Generate initial value
      generate_random_value()
    end
    return
  end
  
  -- -- Handle Stepped Random mode
  -- if type == "Clocked Random" then
  --   local div = self.state.values["crow_" .. output_num .. "_clock_div"]
  --   local beats = self:division_to_beats(div)
  --   local min_value = self.state.values["crow_" .. output_num .. "_random_min"]
  --   local max_value = self.state.values["crow_" .. output_num .. "_random_max"]
  --   local shape = self.state.values["crow_" .. output_num .. "_random_shape"]
  --   local slew = self.state.values["crow_" .. output_num .. "_random_slew"]
    
  --   -- If division is 0 or invalid, turn off the output
  --   if beats <= 0 or div == "Off" then
  --     crow.output[output_num].volts = 0
  --     return
  --   end
    
  --   -- Convert beats to seconds based on current tempo
  --   local beat_sec = clock.get_beat_sec()
  --   local time = beat_sec * beats
    
  --   -- Calculate slew time based on percentage
  --   local slew_time = (slew / 100) * time
    
  --   -- Create stepped random function that uses ASL for each step
  --   local function stepped_random_function()
  --     while true do
  --       -- Generate new random value
  --       local random_value = min_value + math.random() * (max_value - min_value)
        
  --       -- Create a single step ASL that holds the value
  --       local asl_string = string.format("to(%f,%f,'%s')", random_value, time, shape)
  --       crow.output[output_num].action = asl_string
  --       crow.output[output_num]()
        
  --       -- Wait for next step based on clock division
  --       clock.sync(beats)
  --     end
  --   end
    
  --   -- Start the random generator
  --   self.state.active_clocks["crow_" .. output_num] = clock.run(stepped_random_function)
  --   return
  -- end

  if type == "Burst" then
    local div = self.state.values["crow_" .. output_num .. "_clock_div"]
    local beats = self:division_to_beats(div)
    
    if beats == 0 then
      crow.output[output_num].volts = 0
      return
    end

    -- Create clock function for burst mode
    local clock_fn = function()
      while true do
        local burst_voltage = self.state.values["crow_" .. output_num .. "_burst_voltage"]
        local burst_count = self.state.values["crow_" .. output_num .. "_burst_count"]
        local burst_time = self.state.values["crow_" .. output_num .. "_burst_time"]
        
        -- Send burst of pulses
        for i = 1, burst_count do
          crow.output[output_num].volts = burst_voltage
          clock.sleep(burst_time / burst_count)
          crow.output[output_num].volts = 0
          clock.sleep(burst_time / burst_count)
        end
        
        -- Wait for next interval
        clock.sync(beats)
      end
    end
    
    -- Start the clock
    self.state.active_clocks["crow_" .. output_num] = clock.run(clock_fn)
    return
  end

  if type == "Gate" then
    local div = self.state.values["crow_" .. output_num .. "_clock_div"]
    local beats = self:division_to_beats(div)
    
    if beats == 0 then
      crow.output[output_num].volts = 0
      return
    end

    -- Create clock function for gate mode
    local clock_fn = function()
      while true do
        local gate_voltage = self.state.values["crow_" .. output_num .. "_gate_voltage"]
        local gate_length = self.state.values["crow_" .. output_num .. "_gate_length"] / 100
        local beat_sec = clock.get_beat_sec()
        local gate_time = beat_sec * beats * gate_length
        
        -- Send gate pulse
        crow.output[output_num].volts = gate_voltage
        clock.sleep(gate_time)
        crow.output[output_num].volts = 0
        
        -- Wait for next interval
        clock.sync(beats)
      end
    end
    
    -- Start the clock
    self.state.active_clocks["crow_" .. output_num] = clock.run(clock_fn)
    return
  end
end

-- Function to start/stop clock for a specific TXO TR output
function EurorackOutputSection:update_txo_tr(output_num)
  -- Stop existing clock if any
  if self.state.active_clocks["txo_tr_" .. output_num] then
    clock.cancel(self.state.active_clocks["txo_tr_" .. output_num])
    self.state.active_clocks["txo_tr_" .. output_num] = nil
  end

  -- Get clock parameters
  local type = self.state.values["txo_tr_" .. output_num .. "_type"]
  if type ~= "Burst" and type ~= "Gate" then return end

  local div = self.state.values["txo_tr_" .. output_num .. "_clock_div"]
  local beats = self:division_to_beats(div)
  
  -- If division is 0, just stop the clock
  if beats == 0 then
    crow.ii.txo.tr(output_num, 0)
    return
  end
  
  -- Create clock function
  local function clock_function()
    while true do
      if type == "Burst" then
        -- Burst mode
        local burst_count = self.state.values["txo_tr_" .. output_num .. "_burst_count"]
        local burst_time = self.state.values["txo_tr_" .. output_num .. "_burst_time"]
        
        -- Send burst of pulses using TXO TR commands
        for i = 1, burst_count do
          crow.ii.txo.tr(output_num, 1) -- Set high
          clock.sleep(burst_time / burst_count)
          crow.ii.txo.tr(output_num, 0) -- Set low
          clock.sleep(burst_time / burst_count)
        end
      else
        -- Gate mode
        local gate_length = self.state.values["txo_tr_" .. output_num .. "_gate_length"] / 100
        local beat_sec = clock.get_beat_sec()
        local gate_time = beat_sec * beats * gate_length
        
        crow.ii.txo.tr(output_num, 1) -- Set high
        clock.sleep(gate_time)
        crow.ii.txo.tr(output_num, 0) -- Set low
      end
      
      -- Wait for next interval
      clock.sync(beats)
    end
  end
  
  -- Start the clock
  self.state.active_clocks["txo_tr_" .. output_num] = clock.run(clock_function)
end

-- Function to update TXO CV LFO settings
function EurorackOutputSection:update_txo_cv(output_num)
  -- Stop existing clock if any
  if self.state.active_clocks["txo_cv_" .. output_num] then
    clock.cancel(self.state.active_clocks["txo_cv_" .. output_num])
    self.state.active_clocks["txo_cv_" .. output_num] = nil
  end

  -- Get the output type
  local type = self.state.values["txo_cv_" .. output_num .. "_type"]
  local sync = self.state.values["txo_cv_" .. output_num .. "_sync"]
  
  -- Handle Stepped Random type
  if type == "Stepped Random" then
    local min_value = self.state.values["txo_cv_" .. output_num .. "_random_min"]
    local max_value = self.state.values["txo_cv_" .. output_num .. "_random_max"]
    
    -- Make sure sync is not Off for Stepped Random
    if sync == "Off" then
      self.state.values["txo_cv_" .. output_num .. "_sync"] = "1/8"
      sync = "1/8"
    end
    
    -- Initialize the CV output
    crow.ii.txo.cv_init(output_num)
    
    -- Set initial random value
    local random_value = min_value + math.random() * (max_value - min_value)
    crow.ii.txo.cv(output_num, random_value)
    
    -- Setup clock for stepped random changes
    local function random_step_function()
      while true do
        -- Generate new random value
        local random_value = min_value + math.random() * (max_value - min_value)
        crow.ii.txo.cv(output_num, random_value)
        
        -- Wait for next step
        local beats = self:division_to_beats(sync)
        clock.sync(beats)
      end
    end
    
    -- Start the clock
    self.state.active_clocks["txo_cv_" .. output_num] = clock.run(random_step_function)
    return
  end

  -- Handle LFO type (default)
  -- Get LFO parameters
  local shape = self.state.values["txo_cv_" .. output_num .. "_shape"]
  local morph = self.state.values["txo_cv_" .. output_num .. "_morph"]
  local depth = self.state.values["txo_cv_" .. output_num .. "_depth"]
  local time = self.state.values["txo_cv_" .. output_num .. "_time"]
  local offset = self.state.values["txo_cv_" .. output_num .. "_offset"]
  local phase = self.state.values["txo_cv_" .. output_num .. "_phase"]
  local rect = self.state.values["txo_cv_" .. output_num .. "_rect"]

  -- Convert rect name to TXO rect value
  local rect_value = 0  -- Default to Full Range
  if rect == "Negative Half" then rect_value = -2
  elseif rect == "Negative Clipped" then rect_value = -1
  elseif rect == "Positive Clipped" then rect_value = 1
  elseif rect == "Positive Half" then rect_value = 2
  end

  -- Convert shape to TXO wave type and apply morphing
  local base_wave_type = 0  -- Default to sine
  if shape == "Triangle" then base_wave_type = 100
  elseif shape == "Saw" then base_wave_type = 200
  elseif shape == "Pulse" then base_wave_type = 300
  elseif shape == "Noise" then base_wave_type = 400
  end

  -- Calculate morphing wave types in both directions
  local prev_wave_type = base_wave_type
  local next_wave_type = base_wave_type
  
  if shape == "Sine" then
    prev_wave_type = 400  -- Morph towards noise
    next_wave_type = 100  -- Morph towards triangle
  elseif shape == "Triangle" then
    prev_wave_type = 0    -- Morph towards sine
    next_wave_type = 200  -- Morph towards saw
  elseif shape == "Saw" then
    prev_wave_type = 100  -- Morph towards triangle
    next_wave_type = 300  -- Morph towards pulse
  elseif shape == "Pulse" then
    prev_wave_type = 200  -- Morph towards saw
    next_wave_type = 400  -- Morph towards noise
  elseif shape == "Noise" then
    prev_wave_type = 300  -- Morph towards pulse
    next_wave_type = 0    -- Morph towards sine
  end

  -- Interpolate between wave types based on morph value
  local wave_type
  if morph < 0 then
    -- Morph towards previous shape
    wave_type = base_wave_type + ((prev_wave_type - base_wave_type) * (math.abs(morph) / 50))
  else
    -- Morph towards next shape
    wave_type = base_wave_type + ((next_wave_type - base_wave_type) * (morph / 50))
  end

  -- Initialize the CV output
  crow.ii.txo.cv_init(output_num)

  -- Set up the oscillator parameters
  crow.ii.txo.osc_wave(output_num, wave_type)
  
  -- Handle sync mode
  if sync ~= "Off" then
    local beats = self:division_to_beats(sync)
    local beat_sec = clock.get_beat_sec()
    local cycle_time = beat_sec * beats * 1000  -- Convert to milliseconds
    crow.ii.txo.osc_cyc(output_num, cycle_time)
  else
    crow.ii.txo.osc_cyc(output_num, time * 1000)  -- Use time parameter when not synced
  end
  
  crow.ii.txo.cv(output_num, depth)       -- Set amplitude
  crow.ii.txo.osc_ctr(output_num, math.floor((offset/10) * 16384))  -- Set offset (convert to raw value)
  crow.ii.txo.osc_rect(output_num, rect_value)  -- Set rectification
  
  -- Set phase offset (convert degrees to raw value, 0-16384)
  local phase_raw = math.floor((phase / 360) * 16384)
  crow.ii.txo.osc_phase(output_num, phase_raw)
end

return EurorackOutputSection 
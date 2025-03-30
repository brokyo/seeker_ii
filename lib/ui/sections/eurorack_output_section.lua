-- eurorack_output_section.lua
local Section = include('lib/ui/section')
local EurorackOutputSection = setmetatable({}, { __index = Section })
EurorackOutputSection.__index = EurorackOutputSection

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
      { id = "crow_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"Burst", "Gate", "LFO"} } },
      { id = "crow_" .. i .. "_clock_div", name = "Division", spec = { type = "option", values = {"1/16", "1/8", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "8", "16"} } },
      -- Burst parameters
      { id = "crow_" .. i .. "_burst_count", name = "Burst Count", spec = { type = "number", min = 1, max = 16 } },
      { id = "crow_" .. i .. "_burst_time", name = "Burst Time", spec = { type = "number", min = 0.01, max = 1, step = 0.01 } },
      -- Gate parameters
      { id = "crow_" .. i .. "_gate_length", name = "Gate Length %", spec = { type = "number", min = 1, max = 100, step = 1 } },
      -- LFO parameters
      { id = "crow_" .. i .. "_lfo_shape", name = "Shape", spec = { type = "option", values = {"Sine", "Saw", "Square", "Triangle"} } },
      { id = "crow_" .. i .. "_lfo_freq", name = "Frequency", spec = { type = "number", min = 0.1, max = 20, step = 0.1 } },
      { id = "crow_" .. i .. "_lfo_amp", name = "Amplitude", spec = { type = "number", min = 0, max = 5, step = 0.1 } },
      { id = "crow_" .. i .. "_lfo_offset", name = "Offset", spec = { type = "number", min = -5, max = 5, step = 0.1 } },
      { id = "crow_" .. i .. "_lfo_sync", name = "Sync", spec = { type = "option", values = {"On", "Off"} } }
    }
    
    -- Initialize default values for Crow outputs
    section.state.values["crow_" .. i .. "_type"] = "Burst"
    section.state.values["crow_" .. i .. "_clock_div"] = "1/4"
    section.state.values["crow_" .. i .. "_burst_count"] = 1
    section.state.values["crow_" .. i .. "_burst_time"] = 0.1
    section.state.values["crow_" .. i .. "_gate_length"] = 50
    section.state.values["crow_" .. i .. "_lfo_shape"] = "Sine"
    section.state.values["crow_" .. i .. "_lfo_freq"] = 1
    section.state.values["crow_" .. i .. "_lfo_amp"] = 2.5
    section.state.values["crow_" .. i .. "_lfo_offset"] = 0
    section.state.values["crow_" .. i .. "_lfo_sync"] = "Off"
  end

  -- TXO TR outputs (1-4)
  for i = 1, 4 do
    section.state.output_params["TXO TR " .. i] = {
      { id = "txo_tr_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"Burst", "Gate", "LFO"} } }
      -- Other parameters will be added later
    }
  end

  -- TXO CV outputs (1-4)
  for i = 1, 4 do
    section.state.output_params["TXO CV " .. i] = {
      { id = "txo_cv_" .. i .. "_type", name = "Type", spec = { type = "option", values = {"Burst", "Gate", "LFO"} } }
      -- Other parameters will be added later
    }
  end

  -- Override get_param_value to use our state
  function section:get_param_value(param)
    return self.state.values[param.id] or ""
  end

  -- Override modify_param to update our state
  function section:modify_param(param, delta)
    if param.spec then
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
        
        print("Option changed:", param.id, "to:", self.state.values[param.id])
        
        -- If we changed the selected output or type, update the params list
        if param.id == "selected_output" or param.id:match("_type$") then
          self:update_param_list()
        end
        
        -- Update clock if we changed a clock parameter
        if param.id:match("^crow_%d+_") then
          local output_num = tonumber(param.id:match("crow_(%d+)_"))
          self:update_clock(output_num)
        end
      elseif param.spec.type == "number" then
        local current = self.state.values[param.id]
        local step = param.spec.step or 1
        local new_value = current + (delta * step)
        self.state.values[param.id] = util.clamp(new_value, param.spec.min, param.spec.max)
        
        print("Number changed:", param.id, "to:", self.state.values[param.id])
        
        -- Update clock if we changed a clock parameter
        if param.id:match("^crow_%d+_") then
          local output_num = tonumber(param.id:match("crow_(%d+)_"))
          self:update_clock(output_num)
        end
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
    
    -- For Crow outputs, show type-specific parameters
    if self.state.values.selected_output:match("^Crow") then
      local output_num = tonumber(self.state.values.selected_output:match("%d+"))
      local type = self.state.values["crow_" .. output_num .. "_type"]
      
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
      else
        -- LFO parameters
        table.insert(self.params, output_params[6]) -- Shape
        table.insert(self.params, output_params[7]) -- Frequency
        table.insert(self.params, output_params[8]) -- Amplitude
        table.insert(self.params, output_params[9]) -- Offset
        table.insert(self.params, output_params[10]) -- Sync
      end
    else
      -- For other outputs, just show their parameters
      for i = 2, #output_params do
        table.insert(self.params, output_params[i])
      end
    end
  end

  -- Initialize param list
  section:update_param_list()
  
  -- Start clocks for all Crow outputs by default
  for i = 1, 4 do
    section:update_clock(i)
  end
  
  return section
end

-- Helper function to convert division string to beats
function EurorackOutputSection:division_to_beats(div)
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

-- Function to start/stop clock for a specific output
function EurorackOutputSection:update_clock(output_num)
  -- Stop existing clock if any
  if self.state.active_clocks[output_num] then
    clock.cancel(self.state.active_clocks[output_num])
    self.state.active_clocks[output_num] = nil
  end

  -- Get clock parameters
  local type = self.state.values["crow_" .. output_num .. "_type"]
  if type ~= "Burst" and type ~= "Gate" then return end

  local div = self.state.values["crow_" .. output_num .. "_clock_div"]
  local beats = self:division_to_beats(div)
  
  -- Create clock function
  local function clock_function()
    while true do
      if type == "Burst" then
        -- Burst mode
        local burst_count = self.state.values["crow_" .. output_num .. "_burst_count"]
        local burst_time = self.state.values["crow_" .. output_num .. "_burst_time"]
        
        -- Send burst of pulses
        for i = 1, burst_count do
          crow.output[output_num].volts = 5
          clock.sleep(burst_time / burst_count)
          crow.output[output_num].volts = 0
          clock.sleep(burst_time / burst_count)
        end
      else
        -- Gate mode
        local gate_length = self.state.values["crow_" .. output_num .. "_gate_length"] / 100
        local beat_sec = clock.get_beat_sec()
        local gate_time = beat_sec * beats * gate_length
        
        crow.output[output_num].volts = 5
        clock.sleep(gate_time)
        crow.output[output_num].volts = 0
      end
      
      -- Wait for next interval
      clock.sync(beats)
    end
  end
  
  -- Start the clock
  self.state.active_clocks[output_num] = clock.run(clock_function)
end

return EurorackOutputSection 
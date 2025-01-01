local Utils = include('lib/utils')
local default_channel_params = include("lib/default_channel_params")

-- Define the class
local Channel = {}
Channel.__index = Channel

-- Constructor for new instances
function Channel.new(idx)
    local self = setmetatable({}, Channel)
    self.idx = idx

    local defaults = Utils.deep_copy(default_channel_params)
    for k, v in pairs(defaults) do
        self[k] = v
    end

    return self
end

function Channel:add_params()
    params:add_group("Channel " .. self.id " Config", 5)
    
 -- Clock Section Header
 params:add_text {
    id = "clock_section_header_" .. self.id,
    name = "Clock Settings",
    action = function() end -- No action needed, acts as a label
  }

  -- Clock Source
  params:add {
    id = "clock_source_" .. self.id,
    name = "Clock Source",
    type = "option",
    options = {"internal", "external"},
    default = 1, -- Default to "internal"
    action = function(value)
      print("Channel " .. self.id .. " clock source set to " .. (value == 1 and "internal" or "external"))
    end
  }

  -- Clock Mod
  params:add {
    id = "clock_mod_" .. self.id,
    name = "Clock Mod",
    type = "option",
    options = theory_utils.clock_divisions,
    default = 9, -- Default to "1" (normal clock speed)
    action = function(value)
      local division = theory_utils.get_clock_division(value)
      print("Channel " .. self.id .. " clock mod set to " .. division)
    end
  }

  -- Clock Pulse Behavior
  params:add {
    id = "clock_pulse_behavior_" .. self.id,
    name = "Clock Pulse Behavior",
    type = "option",
    options = {"Pulse", "Strum", "Burst"},
    default = 1, -- Default to "Pulse"
    action = function(value)
      print("Channel " .. self.id .. " pulse behavior set to " .. ({"Pulse", "Strum", "Burst"})[value])
    end
  }

  -- Clock Pulse Length
  params:add {
    id = "clock_pulse_length_" .. self.id,
    name = "Clock Pulse Length",
    type = "control",
    controlspec = controlspec.new(0, 99, "lin", 1, 0, "ms"),
    action = function(value)
      print("Channel " .. self.id .. " pulse length set to " .. value .. " ms")
    end
  }
end

return Channel
local utils = include('lib/utils')
local theory_utils = include('lib/theory_utils')
local default_channel_params = include("lib/default_channel_params")

-- Define the class
local Channel = {}
Channel.__index = Channel

-- Constructor for new instances
function Channel.new(id)
    local self = setmetatable({}, Channel)
    self.id = id

    local defaults = utils.deep_copy(default_channel_params)
    for k, v in pairs(defaults) do
        self[k] = v
    end

    return self
end

function Channel:add_params(channel_id)
    -- Group for rhythm parameters
    params:add_group("Channel " .. channel_id , 5) -- Adjust group size to include the header
  
    -- Clock Section Header
    params:add_text {
      id = "clock_section_header_" .. channel_id,
      name = "Clock Settings",
      action = function() end -- No action needed, acts as a label
    }
  
    -- Clock Source
    params:add {
      id = "clock_source_" .. channel_id,
      name = "Clock Source",
      type = "option",
      options = {"internal", "external"},
      default = 1, -- Default to "internal"
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " clock source set to " .. (value == 1 and "internal" or "external"))
      end
    }
  
    -- Clock Mod
    params:add {
      id = "clock_mod_" .. channel_id,
      name = "Clock Mod",
      type = "option",
      options = theory_utils.clock_divisions,
      default = 9, -- Default to "1" (normal clock speed)
      action = function(value)
        local division = theory_utils.get_clock_division(value)
        utils.debug_print("Channel " .. channel_id .. " clock mod set to " .. division)
      end
    }
  
    -- Clock Pulse Behavior
    params:add {
      id = "clock_pulse_behavior_" .. channel_id,
      name = "Clock Pulse Behavior",
      type = "option",
      options = {"Pulse", "Strum", "Burst"},
      default = 1, -- Default to "Pulse"
      action = function(value)
        utils.debug_print("Channel " .. channel_id .. " pulse behavior set to " .. ({"Pulse", "Strum", "Burst"})[value])
      end
    }
  
    -- Clock Pulse Length
    params:add {
      id = "clock_pulse_length_" .. channel_id,
      name = "Pulse Length (Beats)", -- Updated title for musical clarity
      type = "option",
      options = theory_utils.note_lengths, -- Use note lengths for musical rhythm
      default = 5, -- Default to "1/4" (quarter note)
      action = function(value)
        local length = theory_utils.get_note_length(value)
        utils.debug_print("Channel " .. channel_id .. " pulse length set to " .. length)
      end
    }
end

return Channel
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
    
end

return Channel
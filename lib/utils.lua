-- utils.lua
-- Convenience methods

local utils = {}

-- Utility function to deep copy a table
function utils.deep_copy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = utils.deep_copy(v)  -- Recursively copy nested tables
        else
            copy[k] = v
        end
    end
    return copy
end

function utils.debug_print(msg)
    if SEEKER_DEBUG then
      print(msg)
    end
  end

return utils
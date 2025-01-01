--[[
  utils.lua
  General utility functions for Seeker II

  Handles:
  - Debug logging with timing information
  - Table deep copying
  - Time difference tracking between events
]]--

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

function utils.debug_print(msg, channel_id)
    if SEEKER_DEBUG then
        local beat = clock.get_beats()
        local beat_sec = clock.get_beat_sec()
        local time = beat * beat_sec
        
        local prefix = ""
        if channel_id then
            prefix = string.format("[CH%d %.3fs | Beat %.2f] ", channel_id, time, beat)
        else
            prefix = string.format("[%.3fs | Beat %.2f] ", time, beat)
        end
        
        print(prefix .. msg)
    end
end

-- For timing verification between events
function utils.debug_time_diff(msg, last_time, channel_id)
    if SEEKER_DEBUG then
        local current_time = util.time()
        local diff = current_time - (last_time or current_time)
        local beat = clock.get_beats()
        
        local prefix = ""
        if channel_id then
            prefix = string.format("[CH%d +%.3fs | Beat %.2f] ", channel_id, diff, beat)
        else
            prefix = string.format("[+%.3fs | Beat %.2f] ", diff, beat)
        end
        
        print(prefix .. msg)
        return current_time
    end
    return last_time
end

return utils
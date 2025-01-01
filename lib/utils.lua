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

local script_start_time = nil
local script_start_beat = nil

function utils.init_timing()
    script_start_time = os.time()
    script_start_beat = clock.get_beats()
end

function utils.format_time(time)
    if not script_start_time then utils.init_timing() end
    return string.format("%.2fs", time - script_start_time)
end

function utils.format_beat(beat)
    if not script_start_beat then utils.init_timing() end
    return string.format("%.2f", beat - script_start_beat)
end

function utils.debug_print(message, channel_id)
    if SEEKER_VERBOSE then
        local current_beat = clock.get_beats()
        local prefix = string.format("[CH%d %d] ", 
            channel_id or 0,
            math.floor(current_beat)
        )
        print(prefix .. message)
    end
end

function utils.debug_time_diff(message, last_time, channel_id)
    local current_time = os.time()
    if last_time then
        utils.debug_print(string.format(
            "%s (+%.3fs)",
            message,
            current_time - last_time
        ), channel_id)
    else
        utils.debug_print(message, channel_id)
    end
    return current_time
end

function utils.deep_copy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[utils.deep_copy(k)] = utils.deep_copy(v) end
    return res
end

function utils.debug_table(message, channel_id)
    if SEEKER_DEBUG then
        local current_beat = clock.get_beats()
        local prefix = string.format("[CH%d %d] ", 
            channel_id or 0,
            math.floor(current_beat)
        )
        print(prefix .. message)
    end
end

return utils
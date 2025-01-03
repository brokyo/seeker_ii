--[[
  clock_utils.lua
  Clock division and timing utilities for Seeker II

  Handles:
  - Clock division definitions
  - Division string to numeric value conversion
  - Parameter index to time value mapping
]]--

local clock_utils = {}

-- Clock divisions in order (for params/display)
clock_utils.divisions = {
    "1/32", "1/16", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2",
    "1",
    "2", "3", "4", "5", "6", "7", "8", "16", "32"
}

-- Lookup table for clock divisions to their numeric values
clock_utils.division_lookup = {
    ["1/32"] = 1/32,
    ["1/16"] = 1/16,
    ["1/8"] = 1/8,
    ["1/7"] = 1/7,
    ["1/6"] = 1/6,
    ["1/5"] = 1/5,
    ["1/4"] = 1/4,
    ["1/3"] = 1/3,
    ["1/2"] = 1/2,
    ["1"] = 1,
    ["2"] = 2,
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
    ["8"] = 8,
    ["16"] = 16,
    ["32"] = 32
}

-- Get division string from param index
function clock_utils.get_division(index)
    return clock_utils.divisions[index] or "1"
end

-- Convert division string to numeric value
function clock_utils.index_to_time(index)
    local div_string = clock_utils.get_division(index)
    return clock_utils.division_lookup[div_string] or 1
end

return clock_utils
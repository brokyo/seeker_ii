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
    "/16", "/8", "/7", "/6", "/5", "/4", "/3", "/2", "1", "*2", "*3", "*4", "*5", "*6", "*7", "*8", "*16"
}

-- Lookup table for clock divisions to their numeric values
-- NB: Multipliers (*N) result in longer intervals (N beats)
-- while dividers (/N) result in shorter intervals (1/N beats)
clock_utils.division_lookup = {
    ["/16"] = 1/16,
    ["/8"] = 1/8,
    ["/7"] = 1/7,
    ["/6"] = 1/6,
    ["/5"] = 1/5,
    ["/4"] = 1/4,
    ["/3"] = 1/3,
    ["/2"] = 1/2,
    ["1"] = 1,
    ["*2"] = 2,
    ["*3"] = 3,
    ["*4"] = 4,
    ["*5"] = 5,
    ["*6"] = 6,
    ["*7"] = 7,
    ["*8"] = 8,
    ["*16"] = 16
}

-- Get division string from param index
function clock_utils.get_division(index)
    return clock_utils.divisions[index] or "1"
end

-- Convert param index directly to time value
function clock_utils.index_to_time(index)
    local division = clock_utils.get_division(index)
    return clock_utils.division_lookup[division] or 1
end

return clock_utils
-- eurorack_utils.lua
-- Shared utilities for Eurorack components

local EurorackUtils = {}

-- Clock interval options shared by all eurorack outputs
EurorackUtils.interval_options = {"Off", "1", "2", "3", "4", "5", "6", "7", "8", "12", "13", "14", "15", "16", "24", "32", "48", "64"}

-- Clock modifier options shared by all eurorack outputs
EurorackUtils.modifier_options = {"1/64", "1/32", "1/24", "1/23", "1/22", "1/21", "1/20", "1/19", "1/18", "1/17", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "48", "64"}

-- Clock offset options shared by all eurorack outputs
EurorackUtils.offset_options = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}

-- Crow ASL shape options
EurorackUtils.shape_options = {"sine", "linear", "now", "wait", "over", "under", "rebound"}

-- Convert division string to beats
function EurorackUtils.division_to_beats(div)
    if div == "Off" then
        return 0
    end

    if tonumber(div) then
        return tonumber(div)
    end

    local num, den = div:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num)/tonumber(den)
    end

    return 1
end

-- Convert modifier string to numeric value
function EurorackUtils.modifier_to_value(modifier)
    if tonumber(modifier) then
        return tonumber(modifier)
    end

    local num, den = modifier:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num)/tonumber(den)
    end

    return 1
end

-- Convert interval string to beats
function EurorackUtils.interval_to_beats(interval)
    if interval == "Off" then
        return 0
    end

    return tonumber(interval) or 1
end

return EurorackUtils

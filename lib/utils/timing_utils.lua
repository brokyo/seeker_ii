-- timing_utils.lua
-- Shared timing utilities for Eurorack and OSC components

local TimingUtils = {}

-- Base interval options (whole beats)
TimingUtils.interval_options = {"Off", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "48", "64"}

-- Modifier options (multiply interval by this value)
TimingUtils.modifier_options = {"1/64", "1/32", "1/24", "1/23", "1/22", "1/21", "1/20", "1/19", "1/18", "1/17", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "48", "64"}

-- Sync options (comprehensive list including fractions, used by OSC)
TimingUtils.sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}

-- Clock offset options (beat offset for phase alignment)
TimingUtils.offset_options = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}

-- Default modifier index (points to "1" in modifier_options)
TimingUtils.DEFAULT_MODIFIER_INDEX = 26

-- Convert division string to beats (handles fractions like "1/4" and whole numbers)
function TimingUtils.division_to_beats(div)
    if div == "Off" then
        return 0
    end

    if tonumber(div) then
        return tonumber(div)
    end

    local num, den = div:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num) / tonumber(den)
    end

    return 1
end

-- Convert modifier string to numeric multiplier
function TimingUtils.modifier_to_value(modifier)
    if tonumber(modifier) then
        return tonumber(modifier)
    end

    local num, den = modifier:match("(%d+)/(%d+)")
    if num and den then
        return tonumber(num) / tonumber(den)
    end

    return 1
end

-- Convert interval string to beats (whole numbers only)
function TimingUtils.interval_to_beats(interval)
    if interval == "Off" then
        return 0
    end

    return tonumber(interval) or 1
end

-- Convert beats to frequency in Hz based on current tempo
function TimingUtils.beats_to_frequency(beats)
    if beats <= 0 then
        return 0
    end

    local beat_sec = clock.get_beat_sec()
    return 1 / (beat_sec * beats)
end

-- Calculate effective beats from sync division and modifier
function TimingUtils.get_effective_beats(sync_div, modifier)
    local beats = TimingUtils.division_to_beats(sync_div)
    local modifier_value = TimingUtils.modifier_to_value(modifier or "1")
    return beats * modifier_value
end

-- Convert sync division and modifier to frequency
function TimingUtils.sync_to_frequency(sync_div, modifier)
    local beats = TimingUtils.get_effective_beats(sync_div, modifier)
    return TimingUtils.beats_to_frequency(beats)
end

return TimingUtils

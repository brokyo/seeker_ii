-- osc_utils.lua
-- Shared utilities for OSC components

local OscUtils = {}

-- Sync division options shared by LFO and Trigger
OscUtils.sync_options = {"Off", "1/32", "1/24", "1/16", "1/15", "1/14", "1/13", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "32", "40", "48", "56", "64", "128", "256"}

-- LFO shape options
OscUtils.lfo_shape_options = {"Sine", "Gaussian", "Triangle", "Ramp", "Square", "Pulse"}

-- Convert division string to beats
function OscUtils.division_to_beats(div)
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

-- Convert sync division to frequency in Hz based on current tempo
function OscUtils.sync_to_frequency(sync_div)
    local beats = OscUtils.division_to_beats(sync_div)

    if beats <= 0 then
        return 0
    end

    local beat_sec = clock.get_beat_sec()
    local freq_hz = 1 / (beat_sec * beats)

    return freq_hz
end

return OscUtils

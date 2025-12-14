-- osc_utils.lua
-- Shared utilities for OSC components

local TimingUtils = include("lib/utils/timing_utils")

local OscUtils = {}

-- Re-export timing options and functions (using interval_options for whole beats like eurorack)
OscUtils.interval_options = TimingUtils.interval_options
OscUtils.modifier_options = TimingUtils.modifier_options
OscUtils.DEFAULT_MODIFIER_INDEX = TimingUtils.DEFAULT_MODIFIER_INDEX
OscUtils.interval_to_beats = TimingUtils.interval_to_beats
OscUtils.modifier_to_value = TimingUtils.modifier_to_value
OscUtils.sync_to_frequency = TimingUtils.sync_to_frequency

-- LFO shape options (OSC-specific)
OscUtils.lfo_shape_options = {"Sine", "Gaussian", "Triangle", "Ramp", "Square", "Pulse"}

return OscUtils

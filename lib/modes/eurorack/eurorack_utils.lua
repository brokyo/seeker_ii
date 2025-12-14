-- eurorack_utils.lua
-- Shared utilities for Eurorack components

local TimingUtils = include("lib/utils/timing_utils")

local EurorackUtils = {}

-- Re-export timing options and functions
EurorackUtils.interval_options = TimingUtils.interval_options
EurorackUtils.modifier_options = TimingUtils.modifier_options
EurorackUtils.offset_options = TimingUtils.offset_options
EurorackUtils.division_to_beats = TimingUtils.division_to_beats
EurorackUtils.modifier_to_value = TimingUtils.modifier_to_value
EurorackUtils.interval_to_beats = TimingUtils.interval_to_beats

-- Crow ASL shape options (eurorack-specific)
EurorackUtils.shape_options = {"sine", "linear", "now", "wait", "over", "under", "rebound"}

return EurorackUtils

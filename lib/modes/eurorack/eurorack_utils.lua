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

-- TXO output conflict detection
-- TXO has 4 physical outputs that can be used as either oscillators (txo_osc) or CV (txo_cv)

-- Get range of TXO outputs used by a lane's oscillator voice
function EurorackUtils.get_lane_txo_osc_range(lane_id)
    if not _seeker or not _seeker.lanes then return nil end
    local lane = _seeker.lanes[lane_id]

    -- Check param directly for most up-to-date value
    local is_active = params:get("lane_" .. lane_id .. "_txo_osc_active") == 1
    if not lane or not is_active then return nil end

    local start = params:get("lane_" .. lane_id .. "_txo_osc_start")
    local count = params:get("lane_" .. lane_id .. "_txo_osc_count")
    return {start = start, count = count}
end

-- Check if two ranges overlap
function EurorackUtils.ranges_overlap(start1, count1, start2, count2)
    local end1 = start1 + count1 - 1
    local end2 = start2 + count2 - 1
    return start1 <= end2 and start2 <= end1
end

-- Find all conflicts for a proposed TXO osc range
-- Returns {lanes = {lane_ids}, cv_outputs = {output_nums}}
function EurorackUtils.find_txo_osc_conflicts(exclude_lane_id, start, count)
    local conflicts = {lanes = {}, cv_outputs = {}}

    -- Check other lanes' txo_osc ranges
    if _seeker and _seeker.lanes then
        for i = 1, 4 do
            if i ~= exclude_lane_id then
                local range = EurorackUtils.get_lane_txo_osc_range(i)
                if range and EurorackUtils.ranges_overlap(start, count, range.start, range.count) then
                    table.insert(conflicts.lanes, i)
                end
            end
        end
    end

    -- Check TXO CV outputs (enabled = clock_interval != "Off")
    for i = 1, 4 do
        local cv_interval = params:string("txo_cv_" .. i .. "_clock_interval")
        if cv_interval and cv_interval ~= "Off" then
            -- CV output i uses physical output i
            if start <= i and i <= (start + count - 1) then
                table.insert(conflicts.cv_outputs, i)
            end
        end
    end

    return conflicts
end

-- Find conflicts for a TXO CV output being enabled
function EurorackUtils.find_txo_cv_conflicts(output_num)
    local conflicts = {lanes = {}}

    if _seeker and _seeker.lanes then
        for i = 1, 4 do
            local range = EurorackUtils.get_lane_txo_osc_range(i)
            if range then
                -- Check if output_num falls within lane's osc range
                local range_end = range.start + range.count - 1
                if output_num >= range.start and output_num <= range_end then
                    table.insert(conflicts.lanes, i)
                end
            end
        end
    end

    return conflicts
end

-- Format conflicts as readable string for warning modal
function EurorackUtils.format_txo_conflicts(conflicts)
    local parts = {}
    if conflicts.lanes and #conflicts.lanes > 0 then
        table.insert(parts, "Lane " .. table.concat(conflicts.lanes, ","))
    end
    if conflicts.cv_outputs and #conflicts.cv_outputs > 0 then
        table.insert(parts, "CV " .. table.concat(conflicts.cv_outputs, ","))
    end
    return "IN USE: " .. table.concat(parts, ", ")
end

return EurorackUtils

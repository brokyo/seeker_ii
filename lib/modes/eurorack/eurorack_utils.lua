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

-- Crow ASL shape options - see https://monome.org/docs/crow/reference/
EurorackUtils.shape_options = {"linear", "sine", "logarithmic", "exponential", "now", "wait", "over", "under", "rebound"}

-- Clock timing from interval/modifier/offset params.
-- Returns {beats, beat_sec, total_sec, offset} or nil if interval is "Off".
function EurorackUtils.get_clock_timing(interval, modifier, offset)
    if interval == "Off" then return nil end

    local interval_beats = tonumber(interval)
    local modifier_value = EurorackUtils.modifier_to_value(modifier)
    local offset_value = tonumber(offset)

    local beats = interval_beats * modifier_value
    if beats <= 0 then return nil end

    local beat_sec = clock.get_beat_sec()
    return {
        beats = beats,
        beat_sec = beat_sec,
        total_sec = beats * beat_sec,
        offset = offset_value
    }
end

-- Bjorklund algorithm for euclidean pattern generation.
-- Returns a boolean table of length `length` with `hits` distributed evenly,
-- rotated by `rotation` steps.
function EurorackUtils.bjorklund(length, hits, rotation)
    hits = math.min(hits, length)

    local pattern = {}
    if hits == 0 then
        for i = 1, length do pattern[i] = false end
    elseif hits == length then
        for i = 1, length do pattern[i] = true end
    else
        local groups = {}
        for i = 1, hits do
            groups[i] = {true}
        end
        for i = 1, length - hits do
            groups[hits + i] = {false}
        end

        while #groups > hits do
            local new_groups = {}
            local num_to_merge = math.min(hits, #groups - hits)
            for i = 1, num_to_merge do
                local merged = {}
                for _, v in ipairs(groups[i]) do table.insert(merged, v) end
                for _, v in ipairs(groups[#groups - num_to_merge + i]) do table.insert(merged, v) end
                new_groups[i] = merged
            end
            for i = num_to_merge + 1, #groups - num_to_merge do
                new_groups[i] = groups[i]
            end
            groups = new_groups
            if #groups <= hits then break end
        end

        local idx = 1
        for _, group in ipairs(groups) do
            for _, v in ipairs(group) do
                pattern[idx] = v
                idx = idx + 1
            end
        end
    end

    -- Apply rotation
    rotation = rotation or 0
    if rotation > 0 then
        local rotated = {}
        for i = 1, length do
            local src_idx = ((i - 1 + rotation) % length) + 1
            rotated[i] = pattern[src_idx]
        end
        pattern = rotated
    end

    return pattern
end

-- Calculate burst timing intervals based on shape.
-- Returns a table of interval durations that sum to total_time.
function EurorackUtils.get_burst_intervals(count, total_time, shape)
    local intervals = {}

    if shape == "Linear" then
        local interval = total_time / count
        for i = 1, count do
            intervals[i] = interval
        end
    elseif shape == "Accelerating" then
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * (count - i + 1) / sum
        end
    elseif shape == "Decelerating" then
        local sum = 0
        for i = 1, count do sum = sum + i end
        for i = 1, count do
            intervals[i] = total_time * i / sum
        end
    elseif shape == "Random" then
        local remaining = total_time
        for i = 1, count - 1 do
            local max_for_this = remaining - (count - i) * 0.01
            intervals[i] = math.random() * max_for_this * 0.5 + 0.01
            remaining = remaining - intervals[i]
        end
        intervals[count] = remaining
    end

    return intervals
end

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

-- Check if a specific TXO output is being used by CV mode
function EurorackUtils.is_txo_cv_active(output_num)
    local cv_interval = params:string("txo_cv_" .. output_num .. "_clock_interval")
    return cv_interval and cv_interval ~= "Off"
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

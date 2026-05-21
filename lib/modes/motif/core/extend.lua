local FactorOracle = include('lib/modes/motif/core/factor_oracle')
local theory = include('lib/modes/motif/core/theory')

local Extend = {}

function Extend.slice_events(events, duration)
  local num_beats = math.max(1, math.floor(duration))
  local slices = {}
  for b = 1, num_beats do
    slices[b] = {events = {}, pitch_key = ""}
  end

  for _, event in ipairs(events) do
    if event.type == "note_on" then
      local beat = math.floor(event.time) + 1
      beat = math.max(1, math.min(beat, num_beats))
      slices[beat].events[#slices[beat].events + 1] = event
    end
  end

  -- Match note_offs to their beat's note_ons
  for _, event in ipairs(events) do
    if event.type == "note_off" then
      local beat = math.floor(event.time) + 1
      beat = math.max(1, math.min(beat, num_beats))
      -- Find which beat owns the note_on for this note
      for b = beat, 1, -1 do
        local found = false
        for _, e in ipairs(slices[b].events) do
          if e.type == "note_on" and e.note == event.note then
            found = true
            break
          end
        end
        if found then
          slices[b].events[#slices[b].events + 1] = event
          break
        end
      end
    end
  end

  local keys = {}
  for b = 1, num_beats do
    local pcs = {}
    for _, e in ipairs(slices[b].events) do
      if e.type == "note_on" then
        pcs[e.note % 12] = true
      end
    end
    local sorted = {}
    for pc, _ in pairs(pcs) do
      sorted[#sorted + 1] = pc
    end
    table.sort(sorted)
    local key = table.concat(sorted, ",")
    slices[b].pitch_key = key
    keys[b] = key
  end

  return {slices = slices, keys = keys, duration = duration}
end

function Extend.build_oracle(slice_data)
  local oracle = FactorOracle.create()
  for i = 1, #slice_data.keys do
    FactorOracle.add_symbol(oracle, slice_data.keys[i])
  end
  return {
    oracle = oracle,
    slices = slice_data.slices,
    keys = slice_data.keys,
    duration = slice_data.duration
  }
end

function Extend.generate(context, length, fidelity, constraints)
  local generated = FactorOracle.generate(context.oracle, length, fidelity, constraints)

  local events = {}
  local time_cursor = 0

  for _, gen in ipairs(generated) do
    -- state is 1-indexed; oracle state N corresponds to slice N-1
    local slice_index = gen.state - 1
    if slice_index >= 1 and slice_index <= #context.slices then
      local slice = context.slices[slice_index]
      local beat_start = math.floor((slice_index - 1))

      for _, e in ipairs(slice.events) do
        local copy = {}
        for k, v in pairs(e) do
          copy[k] = v
        end
        local offset_within_beat = e.time - beat_start
        offset_within_beat = math.max(0, offset_within_beat)
        copy.time = time_cursor + offset_within_beat
        events[#events + 1] = copy
      end
    end
    time_cursor = time_cursor + 1
  end

  return events, time_cursor
end

function Extend.triangle_depth(loop_count, half_cycle)
  if half_cycle <= 0 then return 0 end
  local full_cycle = half_cycle * 2
  local position = loop_count % full_cycle
  if position <= half_cycle then
    return position
  else
    return full_cycle - position
  end
end

function Extend.mutate_events(events, depth, intensities, scale)
  if not scale or #scale == 0 then return end

  for d = 1, depth do
    local seed = d * 7919

    -- Pitch drift
    if intensities.pitch and intensities.pitch > 0 then
      math.randomseed(seed + 1)
      local drift_chance = intensities.pitch / 100
      for _, e in ipairs(events) do
        if e.type == "note_on" and math.random() < drift_chance then
          local scale_pos = nil
          for si, sn in ipairs(scale) do
            if sn >= e.note then
              scale_pos = si
              break
            end
          end
          if not scale_pos then scale_pos = #scale end

          local max_drift = math.max(1, math.floor(intensities.pitch / 25))
          local shift = math.random(-max_drift, max_drift)
          if shift == 0 then shift = 1 end

          local new_pos = math.max(1, math.min(scale_pos + shift, #scale))
          e.note = scale[new_pos]
        end
      end
    end

    -- Density (drop events)
    if intensities.density and intensities.density > 0 then
      math.randomseed(seed + 2)
      local drop_chance = (intensities.density / 100) * 0.5
      local dropped_notes = {}
      local i = 1
      while i <= #events do
        local e = events[i]
        if e.type == "note_on" and math.random() < drop_chance then
          dropped_notes[e.note] = (dropped_notes[e.note] or 0) + 1
          table.remove(events, i)
        else
          i = i + 1
        end
      end
      -- Remove orphaned note_offs
      local i = 1
      while i <= #events do
        local e = events[i]
        if e.type == "note_off" and dropped_notes[e.note] and dropped_notes[e.note] > 0 then
          dropped_notes[e.note] = dropped_notes[e.note] - 1
          table.remove(events, i)
        else
          i = i + 1
        end
      end
    end

    -- Displace (shift timing within beat)
    if intensities.displace and intensities.displace > 0 then
      math.randomseed(seed + 3)
      local max_shift = (intensities.displace / 100) * 0.25
      for _, e in ipairs(events) do
        local shift = (math.random() * 2 - 1) * max_shift
        e.time = math.max(0, e.time + shift)
      end
    end
  end

  table.sort(events, function(a, b) return a.time < b.time end)
end

return Extend

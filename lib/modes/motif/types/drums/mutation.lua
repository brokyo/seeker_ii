-- mutation.lua
-- Shape-preserving mutation engine. Pure functions only.
-- Triangle-wave depth cycle: genesis → mutated → genesis.

local Mutation = {}

function Mutation.triangle_depth(loop_count, half_cycle)
  local full_cycle = half_cycle * 2
  local position = loop_count % full_cycle
  if position <= half_cycle then
    return position
  else
    return full_cycle - position
  end
end

local function mutation_seed(lane_id, cycle_num, depth_level, mutation_type)
  return lane_id * 100000 + cycle_num * 1000 + depth_level * 10 + mutation_type
end

local function mutate_displace(steps, length, intensity, lane_id, cycle_num, depth_level)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 1))
  local max_swaps = math.max(1, math.floor(length / 4))
  local count = math.max(1, math.ceil(intensity / 100 * max_swaps))

  for _ = 1, count do
    local active_indices = {}
    for i = 1, length do
      if steps[i].active then active_indices[#active_indices + 1] = i end
    end
    if #active_indices == 0 then return end

    local idx = active_indices[math.random(#active_indices)]
    local direction = math.random(2) == 1 and 1 or -1
    local target = idx + direction
    if target < 1 then target = 2 end
    if target > length then target = length - 1 end
    if target < 1 or target > length then return end

    steps[idx], steps[target] = steps[target], steps[idx]
  end
end

local function mutate_pitch(steps, length, intensity, lane_id, cycle_num, depth_level, scale)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 2))
  if not scale or #scale == 0 then return end

  local note_indices = {}
  for i = 1, length do
    if steps[i].note then note_indices[#note_indices + 1] = i end
  end
  if #note_indices == 0 then return end

  local max_drifts = math.max(1, #note_indices)
  local count = math.max(1, math.ceil(intensity / 100 * max_drifts))

  for c = 1, count do
    local idx = note_indices[((c - 1) % #note_indices) + 1]
    local midi = steps[idx].note
    local scale_pos = nil
    for si, sn in ipairs(scale) do
      if sn == midi then scale_pos = si; break end
      if sn > midi then scale_pos = math.max(1, si - 1); break end
    end
    if not scale_pos then scale_pos = #scale end

    local shift
    if intensity <= 33 then
      shift = math.random(2) == 1 and 1 or -1
    elseif intensity <= 66 then
      shift = math.random(-3, 3)
      if shift == 0 then shift = 1 end
    else
      local direction = math.random(2) == 1 and 1 or -1
      local pc = midi % 12
      local target_octave = math.floor(midi / 12) + direction
      local target_midi = pc + target_octave * 12
      shift = 0
      for si, sn in ipairs(scale) do
        if sn >= target_midi then
          shift = si - scale_pos
          break
        end
      end
      if shift == 0 then shift = direction * 7 end
    end

    local new_pos = math.max(1, math.min(scale_pos + shift, #scale))
    steps[idx].note = scale[new_pos]
  end
end

local function mutate_density(steps, length, intensity, lane_id, cycle_num, depth_level)
  math.randomseed(mutation_seed(lane_id, cycle_num, depth_level, 3))
  local max_toggles = math.max(1, math.floor(length / 4))
  local count = math.max(1, math.ceil(intensity / 100 * max_toggles))

  for _ = 1, count do
    local idx = math.random(1, length)
    steps[idx].active = not steps[idx].active
  end
end

function Mutation.mutate_steps(genesis_steps, depth, intensities, lane_id, cycle_num, scale, length, deep_copy_fn)
  local steps = deep_copy_fn(genesis_steps)
  if depth == 0 then return steps end

  for d = 1, depth do
    if intensities.displace > 0 then
      mutate_displace(steps, length, intensities.displace, lane_id, cycle_num, d)
    end
    if intensities.pitch > 0 then
      mutate_pitch(steps, length, intensities.pitch, lane_id, cycle_num, d, scale)
    end
    if intensities.density > 0 then
      mutate_density(steps, length, intensities.density, lane_id, cycle_num, d)
    end
  end

  return steps
end

return Mutation

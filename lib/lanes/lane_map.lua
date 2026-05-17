-- lane_map.lua
-- Maps sub-modes to dedicated lane ranges.
-- Tape=1-4, Composer=5-8, Sampler=9-12, Dialogue=13-16.

local LaneMap = {}

LaneMap.LANES_PER_MODE = 4
LaneMap.ACTIVE_LANES = 16

LaneMap.OFFSETS = {
  tape     = 0,
  composer = 4,
  sampler  = 8,
  dialogue    = 12,
}

LaneMap.MOTIF_TYPES = {
  tape     = 1,
  dialogue    = 2,
  sampler  = 3,
  composer = 4,
}

LaneMap.ACTIVE_LANE_COUNT = {
  tape     = 4,
  composer = 4,
  sampler  = 2,
  dialogue    = 4,
}

function LaneMap.active_lanes_for_mode(sub_mode)
  return LaneMap.ACTIVE_LANE_COUNT[sub_mode] or LaneMap.LANES_PER_MODE
end

function LaneMap.to_flat(sub_mode, local_index)
  return LaneMap.OFFSETS[sub_mode] + local_index
end

function LaneMap.from_flat(lane_id)
  if lane_id <= 4 then return "tape", lane_id
  elseif lane_id <= 8 then return "composer", lane_id - 4
  elseif lane_id <= 12 then return "sampler", lane_id - 8
  else return "dialogue", lane_id - 12
  end
end

function LaneMap.lanes_for_mode(sub_mode)
  local offset = LaneMap.OFFSETS[sub_mode]
  local ids = {}
  for i = 1, LaneMap.LANES_PER_MODE do
    ids[i] = offset + i
  end
  return ids
end

function LaneMap.motif_type_for_mode(sub_mode)
  return LaneMap.MOTIF_TYPES[sub_mode]
end

return LaneMap

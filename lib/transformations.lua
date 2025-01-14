-- transformations.lua
-- Defines various transformations that can be applied to a pattern.

local Transformations = {}

--------------------------------------------------
-- Transpose
--------------------------------------------------

function Transformations.transpose(pattern, interval)
  -- 1. Shift each note's pitch by 'interval'
  -- 2. e.g. for note in ipairs(pattern.notes) do note.pitch = note.pitch + interval end
  return pattern
end

--------------------------------------------------
-- Partial Playback
--------------------------------------------------

function Transformations.partial(pattern, subsetSize)
  -- 1. Keep only the first 'subsetSize' notes, or do something more interesting
  -- 2. e.g. pattern.notes = {unpack(pattern.notes, 1, subsetSize)}
  return pattern
end

--------------------------------------------------
-- Probabilistic Harmonization
--------------------------------------------------

function Transformations.harmonize(pattern, probability)
  -- 1. For each note, sometimes add a chord tone
  -- 2. e.g. if math.random() < probability then ...
  return pattern
end

return Transformations

-- motif_ii.lua
-- Core Responsibilities:
--   1. Store original state of a musical pattern (genesis)
--   2. Maintain working state for transformations

local Motif = {}
Motif.__index = Motif

function Motif.new()
  local m = setmetatable({}, Motif)

  -- Initialize genesis state (never modified)
  -- NOTE: Used by tape mode (original recording). Unused by arpeggio mode (parameter-driven).
  m.genesis = {
    events = {},  -- Array of {time, type, note, velocity, pos} events
    duration = 0  -- Total duration of pattern
  }

  -- Initialize working state (modified by transforms or regeneration)
  m.events = {}   -- Current working events
  m.duration = 0  -- Current duration (may change with transforms)
  m.custom_duration = nil  -- When set, overrides the normal duration

  return m
end

-- Deep copy an event and its nested tables
function Motif:_copy_event(evt)
  local new_evt = {}
  for k, v in pairs(evt) do
    if type(v) == "table" then
      new_evt[k] = {}
      for k2, v2 in pairs(v) do
        new_evt[k][k2] = v2
      end
    else
      new_evt[k] = v
    end
  end
  return new_evt
end

-- Store events in genesis state and initialize working state
function Motif:store_events(recorded_data)
  -- Clear existing
  self.genesis.events = {}
  self.events = {}
  
  -- Clear custom duration since we're storing new events
  self.custom_duration = nil
  
  -- Deep copy events to genesis
  for _, evt in ipairs(recorded_data.events) do
    table.insert(self.genesis.events, self:_copy_event(evt))
  end
  
  -- Store provided duration (critical for maintaining silence at end of pattern)
  self.genesis.duration = recorded_data.duration
  
  -- Initialize working state from genesis
  self:reset_to_genesis()
  print("∞ Motif stored")
end

-- Reset working state to genesis
-- NOTE: Tape mode uses this to restore original recording. Arpeggio mode regenerates from params instead.
function Motif:reset_to_genesis()
  self.events = {}
  for _, evt in ipairs(self.genesis.events) do
    table.insert(self.events, self:_copy_event(evt))
  end
  self.duration = self.genesis.duration
end

-- Get the current effective duration
function Motif:get_duration()
  -- Custom duration takes precedence if set
  if self.custom_duration then
    return self.custom_duration
  end
  return self.duration
end

-- Clear all motif data
function Motif:clear()
  -- Clear genesis state
  self.genesis.events = {}
  self.genesis.duration = 0
  
  -- Clear working state
  self.events = {}
  self.duration = 0
  self.custom_duration = nil  -- Also clear custom duration
end

return Motif 
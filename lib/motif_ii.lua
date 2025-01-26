-- motif_ii.lua
-- A simpler, event-based motif system that maintains grid awareness
-- Core Responsibilities:
--   1. Store original state of a musical pattern (genesis)
--   2. Maintain working state for transformations
--   3. Convert between note formats when needed

local Motif = {}
Motif.__index = Motif

---------------------------------------------------------
-- Example Archetypes
---------------------------------------------------------

-- Simple ascending pattern
Motif.examples = {
  -- Basic 4-note pattern (C4, E4, G4, C5)
  simple_triad = {
    events = {
      {time = 0.0, type = "note_on",  note = 60, velocity = 100, pos = {x = 1, y = 1}},
      {time = 0.2, type = "note_off", note = 60, pos = {x = 1, y = 1}},
      {time = 0.25, type = "note_on", note = 64, velocity = 90, pos = {x = 2, y = 1}},
      {time = 0.45, type = "note_off", note = 64, pos = {x = 2, y = 1}},
      {time = 0.5, type = "note_on",  note = 67, velocity = 80, pos = {x = 3, y = 1}},
      {time = 0.7, type = "note_off", note = 67, pos = {x = 3, y = 1}},
      {time = 0.75, type = "note_on", note = 72, velocity = 110, pos = {x = 4, y = 1}},
      {time = 0.95, type = "note_off", note = 72, pos = {x = 4, y = 1}}
    },
    duration = 1.0
  },

  -- Empty pattern (for recording)
  empty = {
    events = {},
    duration = 0
  },

  -- Complex rhythmic pattern
  rhythm = {
    events = {
      -- Kick-like pattern
      {time = 0.0,  type = "note_on",  note = 36, velocity = 120, pos = {x = 1, y = 4}},
      {time = 0.1,  type = "note_off", note = 36, pos = {x = 1, y = 4}},
      {time = 0.5,  type = "note_on",  note = 36, velocity = 100, pos = {x = 3, y = 4}},
      {time = 0.6,  type = "note_off", note = 36, pos = {x = 3, y = 4}},
      -- Hi-hat pattern
      {time = 0.25, type = "note_on",  note = 42, velocity = 90, pos = {x = 2, y = 3}},
      {time = 0.3,  type = "note_off", note = 42, pos = {x = 2, y = 3}},
      {time = 0.75, type = "note_on",  note = 42, velocity = 90, pos = {x = 4, y = 3}},
      {time = 0.8,  type = "note_off", note = 42, pos = {x = 4, y = 3}}
    },
    duration = 1.0
  },

  -- Test pattern with overlapping notes
  polyphonic = {
    events = {
      -- First chord (C major)
      {time = 0.0, type = "note_on",  note = 60, velocity = 100, pos = {x = 1, y = 1}},
      {time = 0.0, type = "note_on",  note = 64, velocity = 100, pos = {x = 1, y = 2}},
      {time = 0.0, type = "note_on",  note = 67, velocity = 100, pos = {x = 1, y = 3}},
      {time = 0.45, type = "note_off", note = 60, pos = {x = 1, y = 1}},
      {time = 0.45, type = "note_off", note = 64, pos = {x = 1, y = 2}},
      {time = 0.45, type = "note_off", note = 67, pos = {x = 1, y = 3}},
      -- Second chord (F major)
      {time = 0.5, type = "note_on",  note = 65, velocity = 100, pos = {x = 2, y = 1}},
      {time = 0.5, type = "note_on",  note = 69, velocity = 100, pos = {x = 2, y = 2}},
      {time = 0.5, type = "note_on",  note = 72, velocity = 100, pos = {x = 2, y = 3}},
      {time = 0.95, type = "note_off", note = 65, pos = {x = 2, y = 1}},
      {time = 0.95, type = "note_off", note = 69, pos = {x = 2, y = 2}},
      {time = 0.95, type = "note_off", note = 72, pos = {x = 2, y = 3}}
    },
    duration = 1.0
  }
}

-- Create a new Motif from an example
function Motif.from_example(name)
  local example = Motif.examples[name]
  if not example then
    print(string.format("Warning: Example '%s' not found, using empty motif", name))
    example = Motif.examples.empty
  end
  return Motif.new({events = example.events})
end

function Motif.new(opts)
  local m = setmetatable({}, Motif)
  
  -- Initialize genesis state (never modified)
  m.genesis = {
    events = {},  -- Array of {time, type, note, velocity, pos} events
    duration = 0  -- Total duration of pattern
  }
  
  -- Initialize working state (modified by transforms)
  m.events = {}   -- Current working events
  m.duration = 0  -- Current duration (may change with transforms)
  
  -- Store initial events if provided
  if opts and opts.events then
    m:store_events(opts.events)
  end
  
  return m
end

-- Store events in genesis state and initialize working state
function Motif:store_events(events)
  -- Clear existing
  self.genesis.events = {}
  self.events = {}
  
  -- Calculate total duration while copying
  local max_time = 0
  
  -- Deep copy events to genesis
  for _, evt in ipairs(events) do
    local new_evt = {
      time = evt.time,
      type = evt.type,
      note = evt.note,
      velocity = evt.velocity or (evt.type == "note_on" and 127 or 0),
      pos = evt.pos and {x = evt.pos.x, y = evt.pos.y} or nil
    }
    table.insert(self.genesis.events, new_evt)
    
    -- Track max time for duration
    if evt.time > max_time then
      max_time = evt.time
    end
  end
  
  -- Store duration
  self.genesis.duration = max_time
  
  -- Initialize working state from genesis
  self:reset_to_genesis()
end

-- Reset working state to genesis
function Motif:reset_to_genesis()
  self.events = {}
  for _, evt in ipairs(self.genesis.events) do
    local new_evt = {
      time = evt.time,
      type = evt.type,
      note = evt.note,
      velocity = evt.velocity,
      pos = evt.pos and {x = evt.pos.x, y = evt.pos.y} or nil
    }
    table.insert(self.events, new_evt)
  end
  self.duration = self.genesis.duration
end

-- Apply a transform to the working state
function Motif:apply_transform(transform_fn, params, mode)
  mode = mode or "genesis"
  
  -- Get source events (either genesis or current working state)
  local source_events = mode == "genesis" and self.genesis.events or self.events
  
  -- Apply transform
  local result = transform_fn(source_events, params)
  
  -- Update working state
  self.events = result.events
  self.duration = result.duration or self.duration
end

return Motif 
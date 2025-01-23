-- motif.lua
-- A Motif is a smart data container for musical sequences
-- Core Responsibilities:
--   1. Store and maintain the genesis (original) state of a musical pattern
--   2. Provide access to current working state
--   3. Support basic state transitions (reset, transform application)
-- Non-responsibilities:
--   1. Deciding when/how to transform (Conductor's job)
--   2. Transform sequencing and coordination
--   3. Pattern playback logic
--   4. Stage management

local musicutil = require("musicutil")

local Motif = {}
Motif.__index = Motif

--------------------------------------------------
-- Constructor
--------------------------------------------------

-- Creates a new Motif instance
-- @param opts.notes (optional) Initial note data to store
-- Note: Each note should have {pitch, velocity, time, duration, pos?}
function Motif.new(opts)
  local m = setmetatable({}, Motif)
  
  -- Initialize genesis state (never modified)
  m.genesis = {
    pitches = {},
    velocities = {},
    times = {},
    durations = {},
    grid_positions = {},
    total_duration = 0,
    note_count = 0
  }
  
  -- Initialize current state (modified by transforms)
  m.pitches = {}
  m.velocities = {}
  m.times = {}
  m.durations = {}
  m.grid_positions = {}
  m.total_duration = 0
  m.note_count = 0
  m.lane = opts.lane
  
  -- Store initial notes if provided
  if opts.notes then
    m:store_notes(opts.notes)
  end
  
  return m
end

--------------------------------------------------
-- Event Storage
--------------------------------------------------

-- Store notes in genesis state
-- @param notes Array of note events to store
-- Note: This replaces any existing genesis data
function Motif:store_genesis(notes)
  -- Validate note structure
  for i, note in ipairs(notes) do
    assert(type(note.pitch) == "number", string.format("Note %d: pitch must be a number", i))
    assert(type(note.velocity) == "number", string.format("Note %d: velocity must be a number", i))
    assert(type(note.time) == "number", string.format("Note %d: time must be a number", i))
    assert(type(note.duration) == "number", string.format("Note %d: duration must be a number", i))
    if note.pos then
      assert(type(note.pos.x) == "number", string.format("Note %d: pos.x must be a number", i))
      assert(type(note.pos.y) == "number", string.format("Note %d: pos.y must be a number", i))
    end
  end
  
  -- Store genesis state
  self.genesis.note_count = #notes
  self.genesis.total_duration = 0
  
  for i, note in ipairs(notes) do
    self.genesis.pitches[i] = note.pitch
    self.genesis.velocities[i] = note.velocity
    self.genesis.times[i] = note.time
    self.genesis.durations[i] = note.duration
    if note.pos then
      self.genesis.grid_positions[i] = {x = note.pos.x, y = note.pos.y}
    end
    
    -- Update genesis duration
    local note_end = note.time + note.duration
    self.genesis.total_duration = math.max(self.genesis.total_duration, note_end)
  end
end

-- Initialize working state from genesis
function Motif:init_from_genesis()
  self.note_count = self.genesis.note_count
  self.total_duration = self.genesis.total_duration
  
  for i = 1, self.genesis.note_count do
    self.pitches[i] = self.genesis.pitches[i]
    self.velocities[i] = self.genesis.velocities[i]
    self.times[i] = self.genesis.times[i]
    self.durations[i] = self.genesis.durations[i]
    if self.genesis.grid_positions[i] then
      self.grid_positions[i] = {
        x = self.genesis.grid_positions[i].x,
        y = self.genesis.grid_positions[i].y
      }
    end
  end
end

-- Stores an array of note events into separate property arrays
-- @param notes Array of note events to store
-- Note: This replaces any existing data - it's not additive
function Motif:store_notes(notes)
  -- Store in genesis first
  self:store_genesis(notes)
  -- Then initialize working state
  self:init_from_genesis()
end

--------------------------------------------------
-- Data Access
--------------------------------------------------

-- Get a single note event by index
-- @param index One-based index of the note to retrieve
-- @return Table with all properties of the note, or nil if index invalid
function Motif:get_event(index)
  if index < 1 or index > self.note_count then return nil end
  
  -- Create a complete note object with all required fields
  local note = {
    pitch = self.pitches[index],
    velocity = self.velocities[index] or 127,  -- Default velocity if not set
    time = self.times[index],
    duration = self.durations[index],
    pos = self.grid_positions[index] and {
      x = self.grid_positions[index].x,
      y = self.grid_positions[index].y
    } or nil
  }
  
  return note
end

-- Get all stored notes as an array of events
-- Used primarily for compatibility with other components
-- WARN: Creates new tables - could be memory intensive for large sequences
function Motif:get_all_events()
  local notes = {}
  for i = 1, self.note_count do
    notes[i] = self:get_event(i)
  end
  return notes
end

-- Get metadata about the stored sequence
-- @return Table of metadata values
function Motif:get_metadata()
  return {
    total_duration = self.total_duration,
    note_count = self.note_count
  }
end

--------------------------------------------------
-- Transform System
--------------------------------------------------

-- Reset notes back to genesis state
-- Used when returning to stage 1 or clearing transforms
function Motif:reset_to_genesis()
  self:init_from_genesis()
end

-- Apply a transform function to the current state
-- Note: This is a low-level mechanism. Transform sequencing and coordination
-- is handled by the Conductor. This function simply applies the given transform
-- to the current state.
-- @param transform_fn Function that takes arrays of note properties and params
-- @param params Parameters to pass to the transform function
-- @param mode Either "genesis" (transform from original) or "compound" (build on current)
function Motif:apply_transform(transform_fn, params, mode)
  mode = mode or "genesis"  -- Default to genesis-based transforms
  
  -- Get the source state for the transform
  local source = {
    pitches = mode == "genesis" and self.genesis.pitches or self.pitches,
    velocities = mode == "genesis" and self.genesis.velocities or self.velocities,
    times = mode == "genesis" and self.genesis.times or self.times,
    durations = mode == "genesis" and self.genesis.durations or self.durations,
    grid_positions = mode == "genesis" and self.genesis.grid_positions or self.grid_positions,
    total_duration = mode == "genesis" and self.genesis.total_duration or self.total_duration,
    note_count = mode == "genesis" and self.genesis.note_count or self.note_count
  }
  
  -- Apply the transform
  local result = transform_fn(source, params)
  
  -- Update current state with transformed values
  self.pitches = result.pitches
  self.velocities = result.velocities
  self.times = result.times
  self.durations = result.durations
  self.grid_positions = result.grid_positions
  
  -- Recalculate metadata
  self.note_count = #self.pitches
  self.total_duration = 0
  for i = 1, self.note_count do
    local note_end = self.times[i] + self.durations[i]
    if note_end > self.total_duration then
      self.total_duration = note_end
    end
  end
end

return Motif

-- motif.lua
-- A Motif is a pure data container for musical sequences
-- Responsibilities:
--   1. Store note data in separate arrays for pitch, time, and UI properties
--   2. Provide simple access to stored data
-- Non-responsibilities (handled by Conductor):
--   1. Sorting/ordering of notes
--   2. Time quantization
--   3. Pattern transformations
--   4. Playback logic

local musicutil = require("musicutil")

local Motif = {}
Motif.__index = Motif

--------------------------------------------------
-- Constructor
--------------------------------------------------

-- Creates a new Motif instance
-- @param args.notes (optional) Initial note data to store. Will use if we load saved motifs
-- Note: Each note should have {pitch, velocity, time, duration, pos?}
function Motif.new(args)
  local m = setmetatable({}, Motif)
  args = args or {}

  -- Initialize all property arrays
  -- Pitch domain: What notes are played
  m.pitches = {}    -- Array of MIDI note numbers
  m.velocities = {} -- Array of note velocities (0-127)
  
  -- Time domain: When notes are played
  m.times = {}      -- Array of start times in beats
  m.durations = {}  -- Array of note lengths in beats
  
  -- UI domain: Visual feedback data
  m.grid_positions = {}  -- Array of {x,y} pairs for grid positions
  
  -- Metadata
  -- since it's more about playback than data storage
  m.total_duration = 0   -- Length of sequence in beats
  m.note_count = 0       -- Number of notes stored
  m.start_beat = nil     -- When recording started (if recorded)

  -- Store any provided notes
  if args.notes and #args.notes > 0 then
    m:store_notes(args.notes)
  end

  return m
end

--------------------------------------------------
-- Event Storage
--------------------------------------------------

-- Stores an array of note events into separate property arrays
-- @param notes Array of note events to store
-- Note: This replaces any existing data - it's not additive
function Motif:store_notes(notes)
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

  self.note_count = #notes
  self.total_duration = 0
  
  for i, note in ipairs(notes) do
    -- Store musical properties
    self.pitches[i] = note.pitch
    self.velocities[i] = note.velocity
    self.times[i] = note.time
    self.durations[i] = note.duration
    
    -- Store grid position if available
    -- WARN: As we accept MIDI from a keyboard we'll need to figure out something here
    if note.pos then
      self.grid_positions[i] = {x = note.pos.x, y = note.pos.y}
    end
    
    -- Update total duration
    local note_end = note.time + note.duration
    if note_end > self.total_duration then
      self.total_duration = note_end
    end
  end
end

--------------------------------------------------
-- Data Access
--------------------------------------------------

-- Get a single note event by index
-- @param index One-based index of the note to retrieve
-- @return Table with all properties of the note, or nil if index invalid
function Motif:get_event(index)
  if index < 1 or index > self.note_count then return nil end
  
  return {
    pitch = self.pitches[index],
    velocity = self.velocities[index],
    time = self.times[index],
    duration = self.durations[index],
    pos = self.grid_positions[index]
  }
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
    note_count = self.note_count,
    start_beat = self.start_beat
  }
end

return Motif

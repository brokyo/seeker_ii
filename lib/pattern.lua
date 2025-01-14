-- pattern.lua
-- Defines a Pattern object for storing notes, velocities, timing, etc.

local musicutil = require("musicutil")

local Pattern = {}
Pattern.__index = Pattern

--------------------------------------------------
-- Constructor
--------------------------------------------------

function Pattern.new(args)
  local p = setmetatable({}, Pattern)

  -- 1. Initialize pattern data
  p.is_human = (args.type == "human")
  p.notes = {}         -- For "human": store {pitch, velocity, timestamp, duration}
  p.active_notes = {}  -- Track currently recording notes: pitch -> start_time
  p.loop_count = 0     -- How many times we've looped this pattern
  p.max_loops = args.max_loops or 4 -- or from a parameter
  p.transform = nil    -- reference to a transform function or table

  return p
end

--------------------------------------------------
-- Recording Logic
--------------------------------------------------

function Pattern:record_note(pitch, velocity, time, x, y)
  if velocity > 0 then  -- Note on
    -- Store start time for duration calculation
    self.active_notes[pitch] = {
      time = time,
      velocity = velocity,
      x = x,
      y = y
    }
    print(string.format("NOTE ON: pitch=%d, time=%.3f beats stored in active_notes", 
      pitch, time))
  else  -- Note off
    local note_data = self.active_notes[pitch]
    if note_data then
      -- Calculate duration
      local duration = time - note_data.time
      -- Store note data with original velocity and start time
      table.insert(self.notes, {
        pitch = pitch,
        vel = note_data.velocity,  -- Use the note-on velocity
        time = note_data.time,
        duration = duration,
        x = note_data.x,
        y = note_data.y
      })
      print(string.format("NOTE OFF: pitch=%d, start=%.3f, end=%.3f, duration=%.3f beats", 
        pitch, note_data.time, time, duration))
      self.active_notes[pitch] = nil
    else
      print(string.format("WARNING: Note off received for pitch=%d but no start time found!", 
        pitch))
    end
  end
end

function Pattern:stop_recording()
  -- Handle any still-active notes
  local end_time = clock.get_beats()
  for pitch, note_data in pairs(self.active_notes) do
    table.insert(self.notes, {
      pitch = pitch,
      vel = note_data.velocity,
      time = note_data.time,
      duration = end_time - note_data.time,
      x = note_data.x,
      y = note_data.y
    })
  end
  self.active_notes = {}

  -- Sort notes by time
  table.sort(self.notes, function(a, b) return a.time < b.time end)

  -- Calculate relative timings if needed
  if #self.notes > 0 then
    local start_time = self.notes[1].time
    for _, note in ipairs(self.notes) do
      note.time = note.time - start_time
    end
    
    -- Print recorded notes summary
    print("\nRecorded Pattern Summary:")
    print("------------------------")
    print(string.format("%-6s %-10s %-8s %-8s %-8s", "MIDI", "Note", "Vel", "Time", "Duration"))
    print("------------------------")
    
    for i, note in ipairs(self.notes) do
      local note_name = musicutil.note_num_to_name(note.pitch, true) -- true for octave
      print(string.format("%-6d %-10s %-8d %-8.3f %-8.3f", 
        note.pitch,
        note_name,
        note.vel,
        note.time,
        note.duration
      ))
    end
    print("------------------------")
  end
end

--------------------------------------------------
-- Playback
--------------------------------------------------

function Pattern:play()
  -- 1. Called by Lattice. Steps through notes in self.notes
  -- 2. Possibly handle timing offsets if is_human==true
end

--------------------------------------------------
-- Transformation Hook
--------------------------------------------------

function Pattern:apply_transform()
  -- 1. If self.transform is set, call it
  -- 2. self.transform(self) or something similar
end

return Pattern

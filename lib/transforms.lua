-- transforms.lua
-- Transform System: An algorithmic garden for pattern manipulation

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

transforms.available = {
  noop = {
    name = "No Operation",
    description = "Returns the exact same sequence with no changes",
    params = {},
    fn = function(events, params)
      -- Deep copy events
      local result = {}
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        table.insert(result, new_event)
      end
      return result
    end
  },
  
  transpose = {
    name = "Transpose",
    description = "Shift all notes up or down by a number of semitones",
    params = {
      amount = {
        type = "integer",  -- Explicitly specify parameter type
        default = 0,
        min = -24,
        max = 24,
        step = 1  -- Optional: specify custom step size if needed
      }
    },
    fn = function(events, params)
      local amount = params.amount or 0
      local result = {}
      
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        
        -- Only modify pitch for note events
        if event.type == "note_on" or event.type == "note_off" then
          new_event.note = event.note + amount
        end
        
        table.insert(result, new_event)
      end
      
      return result
    end
  },
  
  reverse = {
    name = "Reverse",
    description = "Reverse the order of notes in time while preserving note durations",
    params = {},
    fn = function(events, params)
      -- First pass: collect note_on/note_off pairs and their durations
      local notes = {}
      local total_duration = 0
      
      for i, event in ipairs(events) do
        if event.type == "note_on" then
          notes[#notes + 1] = {
            note = event.note,
            velocity = event.velocity,
            start_time = event.time,
            duration = nil -- Will be filled when we find note_off
          }
        elseif event.type == "note_off" then
          -- Find matching note_on
          for _, note in ipairs(notes) do
            if note.note == event.note and note.duration == nil then
              note.duration = event.time - note.start_time
              break
            end
          end
        end
        -- Track total duration for any non-note events
        if event.time > total_duration then
          total_duration = event.time
        end
      end
      
      -- Second pass: create reversed events
      local result = {}
      for i = #notes, 1, -1 do
        local note = notes[i]
        local new_start = total_duration - (note.start_time + note.duration)
        
        -- Add note_on
        table.insert(result, {
          type = "note_on",
          time = new_start,
          note = note.note,
          velocity = note.velocity
        })
        
        -- Add note_off
        table.insert(result, {
          type = "note_off",
          time = new_start + note.duration,
          note = note.note
        })
      end
      
      -- Add any non-note events at their relative positions
      for _, event in ipairs(events) do
        if event.type ~= "note_on" and event.type ~= "note_off" then
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          new_event.time = total_duration - event.time
          table.insert(result, new_event)
        end
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
      return result
    end
  },

  rotate = {
    name = "Rotate",
    description = "Rotate the order of notes while preserving their relative timing",
    params = {
      amount = {
        type = "integer",
        default = 1,
        min = -12,
        max = 12,
        step = 1
      }
    },
    fn = function(events, params)
      local amount = params.amount or 1
      
      -- Collect just the note events
      local notes = {}
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          table.insert(notes, event.note)
        end
      end
      
      -- Calculate rotation (handle wraparound)
      local note_count = #notes
      if note_count == 0 then return events end
      
      amount = amount % note_count
      if amount < 0 then
        amount = note_count + amount
      end
      
      -- Create lookup table for rotated notes
      local note_map = {}
      for i, note in ipairs(notes) do
        local new_pos = ((i - 1 + amount) % note_count) + 1
        note_map[note] = notes[new_pos]
      end
      
      -- Apply rotation to events
      local result = {}
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        
        if event.type == "note_on" or event.type == "note_off" then
          new_event.note = note_map[event.note]
        end
        
        table.insert(result, new_event)
      end
      
      return result
    end
  },

  skip = {
    name = "Skip",
    description = "Play every Nth note, skipping the ones in between",
    params = {
      n = {
        type = "integer",
        default = 2,
        min = 1,
        max = 16,
        step = 1
      },
      offset = {
        type = "integer",
        default = 0,
        min = 0,
        max = 15,
        step = 1
      }
    },
    fn = function(events, params)
      local n = params.n or 2
      local offset = params.offset or 0
      
      -- First collect note_on events to determine which notes to keep
      local notes_to_keep = {}
      local note_index = 0
      
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          if (note_index + offset) % n == 0 then
            notes_to_keep[event.note] = true
          end
          note_index = note_index + 1
        end
      end
      
      -- Create new sequence keeping only the selected notes
      local result = {}
      for _, event in ipairs(events) do
        if event.type == "note_on" or event.type == "note_off" then
          if notes_to_keep[event.note] then
            local new_event = {}
            for k, v in pairs(event) do
              new_event[k] = v
            end
            table.insert(result, new_event)
          end
        else
          -- Keep non-note events
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          table.insert(result, new_event)
        end
      end
      
      return result
    end
  }
}

return transforms 

-- Future Transforms:
-- 1. Simultaneously plays a transposed version of the motif. Only plays a subset of the notes. Contiguous, not random.

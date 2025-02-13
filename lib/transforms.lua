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
  }
}

return transforms 

-- Future Transforms:
-- 1. Simultaneously plays a transposed version of the motif. Only plays a subset of the notes. Contiguous, not random.

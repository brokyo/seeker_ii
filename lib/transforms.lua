-- transforms.lua
-- Transform System: An algorithmic garden for pattern manipulation
--
-- Core Responsibility:
-- Define a registry of available pattern transformations
--
-- Each transform provides:
-- 1. name: Human readable name
-- 2. description: What the transform does
-- 3. params: Parameter specifications with defaults/ranges
-- 4. fn: The transform implementation that takes (events, params)
--    and returns new transformed events

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

-- Transform Design Principles:
--
-- 1. Event-Based Architecture
--    - Work with time-ordered event tables
--    - Support multiple event types (note_on, note_off, etc)
--    - Preserve event relationships (e.g. note_on/note_off pairs)
--
-- 2. Timing Grid Preservation
--    - Transforms must maintain relationship to the original timing grid
--    - Options for timing modification:
--      a) Keep original time points
--      b) Apply fixed offset
--      c) Scale proportionally
--
-- 3. Transform Categories:
--    - Note Property Transforms (e.g., invert - changes pitch only)
--    - Timing Transforms (e.g., shift, speed)
--    - Pattern Transforms (e.g., reverse)
--
-- 4. Implementation Guidelines:
--    - Keep transforms simple and focused
--    - Preserve timing grid alignment
--    - Test with multiple loops
--    - Log state changes
--    - Document timing expectations

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
  
  invert = {
    name = "Invert",
    description = "Invert pitches around a center note",
    params = {
      center = {
        type = "integer",
        default = 60,
        min = 0,
        max = 127,
        step = 1
      }
    },
    fn = function(events, params)
      local center = params.center or 60
      local result = {}
      
      -- Log input state
      print("\n=== INVERT TRANSFORM INPUT ===")
      for i, event in ipairs(events) do
        if event.type == "note_on" then
          print(string.format("Note %d: pitch=%d time=%.2f", 
            i, event.note, event.time))
        end
      end
      
      -- Process all events
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        
        -- Only modify pitch for note events
        if event.type == "note_on" or event.type == "note_off" then
          -- Invert around center
          local distance = event.note - center
          new_event.note = center - distance
        end
        
        table.insert(result, new_event)
      end
      
      -- Log output state
      print("\n=== INVERT TRANSFORM OUTPUT ===")
      for i, event in ipairs(result) do
        if event.type == "note_on" then
          print(string.format("Note %d: pitch=%d time=%.2f", 
            i, event.note, event.time))
        end
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
  
  speed = {
    name = "Speed",
    description = "Modify the playback speed",
    params = {
      multiplier = {
        type = "continuous",
        default = 1.0,
        min = 0.25,
        max = 4.0,
        step = 0.05
      }
    },
    fn = function(events, params)
      local multiplier = params.multiplier or 1.0
      local result = {}
      
      -- Scale all event times
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        new_event.time = event.time / multiplier
        table.insert(result, new_event)
      end
      
      return result
    end
  },

  harmonize = {
    name = "Harmonize",
    description = "Probabilistically add harmonized notes",
    params = {
      probability = {
        type = "continuous",
        default = 0.5,
        min = 0.0,
        max = 1.0,
        step = 0.05  -- Optional: for finer control
      },
      interval = {
        type = "integer",
        default = 4,
        min = 1,
        max = 12,
        step = 1
      }
    },
    fn = function(events, params)
      local probability = params.probability or 0.5
      local interval = params.interval or 4
      local result = {}
      
      -- First copy all original events
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        table.insert(result, new_event)
        
        -- Probabilistically add harmonized notes for note_on events
        if event.type == "note_on" and math.random() < probability then
          -- Add harmonized note_on
          table.insert(result, {
            type = "note_on",
            time = event.time,
            note = event.note + interval,
            velocity = event.velocity
          })
          
          -- Find corresponding note_off and add harmonized note_off
          for j = 1, #events do
            if events[j].type == "note_off" and 
               events[j].note == event.note and
               events[j].time > event.time then
              table.insert(result, {
                type = "note_off",
                time = events[j].time,
                note = event.note + interval
              })
              break
            end
          end
        end
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
      return result
    end
  },

  echo = {
    name = "Echo",
    description = "Creates delayed copies of notes with musical variations",
    params = {
      echoes = {
        type = "number",
        min = 1,
        max = 4,
        default = 2,
        step = 1,
        formatter = function(param)
          return param == 1 and "1 echo" or param .. " echoes"
        end
      },
      interval = {
        type = "number",
        min = 1,
        max = 8,
        default = 4,
        step = 1,
        formatter = function(param)
          local intervals = {"+8ve", "+5th", "+4th", "+3rd", "-3rd", "-4th", "-5th", "-8ve"}
          return intervals[param] or "+8ve"
        end
      },
      decay = {
        type = "number",
        min = 1,
        max = 4,
        default = 2,
        step = 1,
        formatter = function(param)
          local styles = {"linear", "exponential", "bounce", "random"}
          return styles[param]
        end
      }
    },
    fn = function(events, params)
      local result = {}
      local interval_map = {12, 7, 5, 4, -4, -5, -7, -12} -- semitone mappings for intervals
      local interval = interval_map[params.interval]
      
      -- First copy all original events
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        table.insert(result, new_event)
        
        -- Add echoes for note_on events
        if event.type == "note_on" then
          local base_delay = 0.125 -- 1/32nd note base delay
          
          for echo = 1, params.echoes do
            local delay = base_delay * echo
            local velocity_factor = 1.0
            
            -- Different decay patterns
            if params.decay == 1 then -- linear
              velocity_factor = 1.0 - (echo / (params.echoes + 1))
            elseif params.decay == 2 then -- exponential
              velocity_factor = math.pow(0.7, echo)
            elseif params.decay == 3 then -- bounce
              velocity_factor = math.sin(math.pi * (echo / params.echoes))
            elseif params.decay == 4 then -- random
              velocity_factor = 0.4 + (math.random() * 0.6)
            end
            
            -- Add echo note_on with interval shift
            table.insert(result, {
              type = "note_on",
              time = event.time + delay,
              note = event.note + (interval * (echo % 2)), -- alternate between original and shifted
              velocity = event.velocity * velocity_factor
            })
            
            -- Find corresponding note_off and add echo note_off
            for j = 1, #events do
              if events[j].type == "note_off" and 
                 events[j].note == event.note and
                 events[j].time > event.time then
                table.insert(result, {
                  type = "note_off",
                  time = events[j].time + delay,
                  note = event.note + (interval * (echo % 2))
                })
                break
              end
            end
          end
        end
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
      return result
    end
  },

  arpeggio = {
    name = "Arpeggio",
    description = "Creates an arpeggio pattern with specified note divisions",
    params = {
      division = {
        type = "number",
        min = 1,
        max = 6,
        default = 3,  -- 1/16 by default
        step = 1,
        formatter = function(param) 
          local divisions = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32"}
          return divisions[param] or "1/16"
        end
      },
      pattern = {
        type = "number",
        min = 1,
        max = 4,
        default = 1,
        step = 1,
        formatter = function(param)
          local patterns = {"up", "down", "up-down", "looped random"}
          return patterns[param] or "up"
        end
      },
      loops = {
        type = "number",
        min = 1,
        max = 8,
        default = 2,
        step = 1,
        formatter = function(param)
          return param == 1 and "1 loop" or param .. " loops"
        end
      }
    },
    fn = function(events, params)
      local result = {}
      local notes = {}
      
      -- Map division option to actual time value (assuming 1.0 = quarter note)
      local division_values = {4.0, 2.0, 1.0, 0.5, 0.25, 0.125} -- 1/1, 1/2, 1/4, 1/8, 1/16, 1/32
      local grid_size = division_values[params.division]
      
      -- First collect all unique notes
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          table.insert(notes, {
            note = event.note,
            velocity = event.velocity
          })
        end
      end
      
      -- Sort notes by pitch
      table.sort(notes, function(a, b) return a.note < b.note end)
      
      -- Create pattern based on mode
      local pattern = {}
      if params.pattern == 1 then -- up
        pattern = notes
      elseif params.pattern == 2 then -- down
        for i = #notes, 1, -1 do
          table.insert(pattern, notes[i])
        end
      elseif params.pattern == 3 then -- up-down
        for _, note in ipairs(notes) do
          table.insert(pattern, note)
        end
        for i = #notes-1, 2, -1 do -- exclude first/last note to avoid repeats
          table.insert(pattern, notes[i])
        end
      elseif params.pattern == 4 then -- looped random
        -- Create N copies of the pattern for the specified number of loops
        for loop = 1, params.loops do
          local shuffled = {}
          -- Copy notes for this iteration
          for _, note in ipairs(notes) do
            table.insert(shuffled, {
              note = note.note,
              velocity = note.velocity
            })
          end
          -- Fisher-Yates shuffle
          for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
          end
          -- Add this loop's shuffled pattern
          for _, note in ipairs(shuffled) do
            table.insert(pattern, note)
          end
        end
      end
      
      -- Place notes with fixed grid spacing
      for i, note in ipairs(pattern) do
        local time = (i-1) * grid_size
        
        -- Add note_on
        table.insert(result, {
          type = "note_on",
          time = time,
          note = note.note,
          velocity = note.velocity
        })
        
        -- Add note_off just before next note
        table.insert(result, {
          type = "note_off",
          time = time + (grid_size * 0.95), -- 95% of grid size
          note = note.note
        })
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
      -- Calculate total duration based on number of notes and grid size
      local total_duration = #pattern * grid_size
      
      -- Log for debugging
      print("\n=== ARPEGGIO TRANSFORM ===")
      print(string.format("Grid size: %.3f", grid_size))
      print(string.format("Number of notes: %d", #pattern))
      print(string.format("New duration: %.3f", total_duration))
      
      return result
    end
  }
}

return transforms 

-- Future Transforms:
-- 1. Simultaneously plays a transposed version of the motif. Only plays a subset of the notes. Contiguous, not random.

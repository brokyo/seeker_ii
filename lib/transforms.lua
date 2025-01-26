-- transforms.lua
-- Transform System: An algorithmic garden for pattern manipulation
--
-- Core Responsibilities:
-- 1. Define and implement pattern transformations
-- 2. Provide a registry of available transforms
-- 3. Handle transform-specific parameter management
--
-- Each transform is a pure function that takes:
-- 1. events: Array of event tables with {time, type, note?, velocity?}
-- 2. params: Transform-specific parameters
-- Returns: New array of event tables

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
  
  invert = {
    name = "Invert",
    description = "Invert pitches around a center note",
    params = {
      center = {
        default = 60,
        min = 0,
        max = 127
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
        default = 1.0,
        min = 0.25,
        max = 4.0
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
        default = 0.5,
        min = 0.0,
        max = 1.0
      },
      interval = {
        default = 4,  -- Default to major third
        min = 1,
        max = 12
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
  }
}

--------------------------------------------------
-- Parameter Management
--------------------------------------------------

-- Get parameter spec for a transform
function transforms.get_params_spec(transform_name)
  local transform = transforms.available[transform_name]
  if not transform then return nil end
  return transform.params
end

-- Validate transform parameters
function transforms.validate_params(transform_name, params)
  local spec = transforms.get_params_spec(transform_name)
  if not spec then return false end
  
  -- Check each parameter against its spec
  for name, value in pairs(params) do
    local param_spec = spec[name]
    if param_spec then
      if value < param_spec.min or value > param_spec.max then
        return false
      end
    end
  end
  
  return true
end

--------------------------------------------------
-- Transform Application
--------------------------------------------------

-- Apply a transform by name
function transforms.apply(transform_name, events, params)
  local transform = transforms.available[transform_name]
  if not transform then
    print(string.format("Transform '%s' not found", transform_name))
    return events
  end
  
  -- Use default params where not specified
  local final_params = {}
  for name, spec in pairs(transform.params) do
    final_params[name] = params[name] or spec.default
  end
  
  -- Apply the transform
  return transform.fn(events, final_params)
end

return transforms 
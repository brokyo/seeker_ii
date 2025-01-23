-- transforms.lua
-- Transform System: An algorithmic garden for pattern manipulation
--
-- Core Responsibilities:
-- 1. Define and implement pattern transformations
-- 2. Provide a registry of available transforms
-- 3. Handle transform-specific parameter management
--
-- Each transform is a pure function that takes:
-- 1. source: Table of note arrays (pitches, times, etc.)
-- 2. params: Transform-specific parameters
-- Returns: New table of note arrays

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

-- Transform Design Principles:
--
-- 1. Timing Grid Preservation
--    - Transforms must maintain relationship to the original timing grid
--    - Avoid recalculating timing from scratch
--    - Options for timing modification:
--      a) Keep original time points (e.g., reverse - swap what plays when)
--      b) Apply fixed offset (e.g., shift - add constant to all times)
--      c) Scale proportionally (e.g., speed - multiply all times)
--
-- 2. Total Duration Handling
--    - Must explicitly account for how transform affects total_duration
--    - Common patterns:
--      a) Keep original: total_duration = source.total_duration
--      b) Add offset: total_duration = source.total_duration + offset
--      c) Scale: total_duration = source.total_duration * scale_factor
--
-- 3. Transform Categories & Implementation:
--    - Note Property Transforms (e.g., invert - changes pitch only)
--      * Modify specific properties
--      * Keep timing grid intact
--    - Timing Transforms (e.g., shift, speed)
--      * Modify timing in predictable ways
--      * Maintain proportional relationships
--    - Pattern Transforms (e.g., reverse)
--      * Reorder events while preserving grid
--      * Keep original time points, change what happens when
--
-- 4. Implementation Guidelines:
--    - Keep transforms simple and focused
--    - Preserve timing grid alignment for proper loop behavior
--    - Test with multiple loops to verify timing stability
--    - Log input/output state for debugging
--    - Document timing/duration expectations

transforms.available = {
  noop = {
    name = "No Operation",
    description = "Returns the exact same sequence with no changes",
    params = {
      -- Empty but properly structured params table
      -- This matches the pattern used by other transforms
    },
    fn = function(source, params)
      -- Create new result table to match transform interface
      local result = {
        pitches = {},
        velocities = {},
        times = {},
        durations = {},
        grid_positions = {},
        total_duration = source.total_duration,
        note_count = source.note_count
      }
      
      -- Copy all values exactly as they are
      for i = 1, source.note_count do
        result.pitches[i] = source.pitches[i]
        result.velocities[i] = source.velocities[i]
        result.times[i] = source.times[i]
        result.durations[i] = source.durations[i]
        if source.grid_positions[i] then
          result.grid_positions[i] = {
            x = source.grid_positions[i].x,
            y = source.grid_positions[i].y
          }
        end
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
    fn = function(source, params)
      -- Log input state
      print("\n=== SHIFT TRANSFORM INPUT ===")
      for i = 1, source.note_count do
        print(string.format("Note %d: pitch=%d time=%.2f", 
          i, source.pitches[i], source.times[i]))
      end

      local result = {
        pitches = {},
        velocities = {},
        times = {},
        durations = {},
        grid_positions = {},
        total_duration = source.total_duration + 1,  -- Extend duration for shift
        note_count = source.note_count
      }
      
      -- Copy everything but shift times forward by 1 beat
      for i = 1, source.note_count do
        result.pitches[i] = source.pitches[i]
        result.velocities[i] = source.velocities[i]
        result.times[i] = source.times[i] + 1  -- Add 1 beat to each note
        result.durations[i] = source.durations[i]
        if source.grid_positions[i] then
          result.grid_positions[i] = {
            x = source.grid_positions[i].x,
            y = source.grid_positions[i].y
          }
        end
      end

      -- Log output state
      print("\n=== SHIFT TRANSFORM OUTPUT ===")
      for i = 1, result.note_count do
        print(string.format("Note %d: pitch=%d time=%.2f", 
          i, result.pitches[i], result.times[i]))
      end
      
      return result
    end
  },
  
  reverse = {
    name = "Reverse",
    description = "Reverse the order of notes in time",
    params = {},
    fn = function(source, params)
      -- Log input state
      print("\n=== REVERSE TRANSFORM INPUT ===")
      for i = 1, source.note_count do
        print(string.format("Note %d: pitch=%d time=%.2f", 
          i, source.pitches[i], source.times[i]))
      end

      local result = {
        pitches = {},
        velocities = {},
        times = {},
        durations = {},
        grid_positions = {},
        total_duration = source.total_duration,  -- Keep original duration
        note_count = source.note_count
      }
      
      -- Just reverse the arrays in place, keeping original timing
      for i = 1, source.note_count do
        local rev_i = source.note_count - i + 1
        result.pitches[i] = source.pitches[rev_i]
        result.velocities[i] = source.velocities[rev_i]
        result.times[i] = source.times[i]  -- Keep original timing
        result.durations[i] = source.durations[rev_i]
        if source.grid_positions[rev_i] then
          result.grid_positions[i] = {
            x = source.grid_positions[rev_i].x,
            y = source.grid_positions[rev_i].y
          }
        end
      end

      -- Log output state
      print("\n=== REVERSE TRANSFORM OUTPUT ===")
      for i = 1, result.note_count do
        print(string.format("Note %d: pitch=%d time=%.2f", 
          i, result.pitches[i], result.times[i]))
      end
      
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
    fn = function(source, params)
      local result = {
        pitches = {},
        velocities = {},
        times = {},
        durations = {},
        grid_positions = {},
        total_duration = source.total_duration / params.multiplier,
        note_count = source.note_count
      }
      
      -- Scale all time values
      for i = 1, source.note_count do
        result.pitches[i] = source.pitches[i]
        result.velocities[i] = source.velocities[i]
        result.times[i] = source.times[i] / params.multiplier
        result.durations[i] = source.durations[i] / params.multiplier
        if source.grid_positions[i] then
          result.grid_positions[i] = {
            x = source.grid_positions[i].x,
            y = source.grid_positions[i].y
          }
        end
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
    fn = function(source, params)
      -- Create new arrays for transformed sequence
      local result = {
        pitches = {},
        velocities = {},
        times = {},
        durations = {},
        grid_positions = {},
        total_duration = source.total_duration,
        note_count = 0
      }
      
      -- Copy original notes first
      for i = 1, source.note_count do
        result.note_count = result.note_count + 1
        result.pitches[result.note_count] = source.pitches[i]
        result.velocities[result.note_count] = source.velocities[i]
        result.times[result.note_count] = source.times[i]
        result.durations[result.note_count] = source.durations[i]
        if source.grid_positions[i] then
          result.grid_positions[result.note_count] = {
            x = source.grid_positions[i].x,
            y = source.grid_positions[i].y
          }
        end
        
        -- Probabilistically add harmonized note
        if math.random() < params.probability then
          -- Add harmonized note
          result.note_count = result.note_count + 1
          result.pitches[result.note_count] = source.pitches[i] + params.interval
          result.velocities[result.note_count] = source.velocities[i]
          result.times[result.note_count] = source.times[i]
          result.durations[result.note_count] = source.durations[i]
          if source.grid_positions[i] then
            result.grid_positions[result.note_count] = {
              x = source.grid_positions[i].x,
              y = source.grid_positions[i].y
            }
          end
        end
      end
      
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
function transforms.apply(transform_name, source, params)
  local transform = transforms.available[transform_name]
  if not transform then
    print(string.format("Transform '%s' not found", transform_name))
    return source
  end
  
  -- Use default params where not specified
  local final_params = {}
  for name, spec in pairs(transform.params) do
    final_params[name] = params[name] or spec.default
  end
  
  -- Apply the transform
  return transform.fn(source, final_params)
end

return transforms 
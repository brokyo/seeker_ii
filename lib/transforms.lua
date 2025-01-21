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

transforms.available = {
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
      -- TODO: Implement inversion transform
      -- For each pitch, apply: center + (center - pitch)
      return source
    end
  },
  
  reverse = {
    name = "Reverse",
    description = "Reverse the order of notes in time",
    params = {},
    fn = function(source, params)
      -- TODO: Implement reverse transform
      -- Maintain note durations but reverse their order
      return source
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
      -- TODO: Implement speed transform
      -- Scale all time values by multiplier
      return source
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
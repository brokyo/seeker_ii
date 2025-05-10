-- motif_generator.lua
-- Core responsibility: Define generators and their parameter handling logic
-- State management is handled by the UI sections that use this module

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

-- Load generators
local generators = {
  starlight = include('lib/generators/starlight'),
  pulse = include('lib/generators/pulse'),
  pulsar = include('lib/generators/pulsar'),
  foundations = include('lib/generators/foundations')
}

-- Parameter type handlers with their update and format logic
local param_types = {
  integer = {
    update = function(value, spec)
      return util.clamp(math.floor(value + 0.5), spec.min, spec.max)
    end,
    format = function(value, spec)
      if spec.formatter then
        return spec.formatter(value)
      end
      return tostring(value)
    end
  },
  
  option = {
    update = function(value, spec)
      return util.clamp(value, 1, #spec.options)
    end,
    format = function(value, spec)
      return spec.options[value]
    end
  },

  number = {
    update = function(value, spec)
      -- Allow fractional values but still clamp to range
      return util.clamp(value, spec.min, spec.max)
    end,
    format = function(value, spec)
      if spec.formatter then
        return spec.formatter(value)
      end
      return string.format("%.3f", value)
    end
  },

  control = {
    update = function(value, spec)
      -- Controls are always integer values 0-100
      return util.clamp(math.floor(value + 0.5), spec.min or 0, spec.max or 100)
    end,
    format = function(value, spec)
      if spec.formatter then
        return spec.formatter(value)
      end
      return tostring(value) .. "%"
    end
  }
}

-- Helper method to add note events to the events table
local function add_note_event(events, note, time, duration, velocity)
  local pos = theory.note_to_grid(note)
  -- Note on
  table.insert(events, {
    time = time,
    type = "note_on",
    note = note,
    velocity = math.floor(velocity),  -- Ensure integer velocity
    x = pos and pos.x or nil,
    y = pos and pos.y or nil
  })
  -- Note off
  table.insert(events, {
    time = time + duration,
    type = "note_off",
    note = note,
    x = pos and pos.x or nil,
    y = pos and pos.y or nil
  })
end

-- Helper method to print motif details for debugging
local function debug_print_motif(motif_data, generator_id, params)
  print("\n=== Generated Motif ===")
  -- Print generator info
  local gen = generators[generator_id]
  print(string.format("Generator: %s - %s", gen.name, gen.description))
  
  -- Print parameters
  print("Parameters:")
  for param_id, value in pairs(params) do
    local spec = gen.params[param_id]
    local formatted = param_types[spec.type].format(value, spec)
    print(string.format("  %s: %s", param_id, formatted))
  end
  
  -- Print motif data
  print(string.format("\nDuration: %.2f", motif_data.duration))
  print("Events:")
  for i, event in ipairs(motif_data.events) do
    if event.type == "note_on" then
      print(string.format("  %.2fs: %s %s vel:%d pos:(%s,%s)", 
        event.time,
        event.type,
        musicutil.note_num_to_name(event.note, true),
        math.floor(event.velocity),  -- Floor velocity to ensure integer
        event.x or "-",
        event.y or "-"
      ))
    else
      print(string.format("  %.2fs: %s %s", 
        event.time,
        event.type,
        musicutil.note_num_to_name(event.note, true)
      ))
    end
  end
  print("====================\n")
end

-- Public API
local MotifGenerator = {}

-- Get list of available generators
function MotifGenerator.get_generators()
  local names = {}
  for name, gen in pairs(generators) do
    table.insert(names, {
      id = name,
      name = gen.name,
      description = gen.description
    })
  end
  table.sort(names, function(a, b) return a.id < b.id end)
  return names
end

-- Get a generator's specification
function MotifGenerator.get_generator_spec(generator_id)
  assert(generator_id, "Generator ID is required")
  local gen = generators[generator_id]
  assert(gen, string.format("Generator %s not found", generator_id))
  return gen
end

-- Get default parameter values for a generator
function MotifGenerator.get_default_params(generator_id)
  local gen = MotifGenerator.get_generator_spec(generator_id)
  local defaults = {}
  for id, spec in pairs(gen.params) do
    defaults[id] = spec.default
  end
  return defaults
end

-- Update a parameter value
function MotifGenerator.process_param_update(param_id, value, spec, is_delta, current_value)
  assert(spec, string.format("No parameter spec found for %s", param_id))
  local handler = param_types[spec.type]
  assert(handler, string.format("Unknown parameter type: %s", spec.type))
  
  if is_delta then
    value = current_value + (value * spec.step)
  end
  
  return handler.update(value, spec)
end

-- Format a parameter value for display
function MotifGenerator.format_param_value(value, spec)
  assert(spec, "Parameter spec is required for formatting")
  local handler = param_types[spec.type]
  assert(handler, string.format("Unknown parameter type: %s", spec.type))
  return handler.format(value, spec)
end

-- Generate a motif using the provided parameters
function MotifGenerator.generate(generator_id, params)
  local gen = MotifGenerator.get_generator_spec(generator_id)
  local motif_data = gen.generate(params, add_note_event)
  debug_print_motif(motif_data, generator_id, params)
  return motif_data
end

return MotifGenerator 
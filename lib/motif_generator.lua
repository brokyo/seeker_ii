-- motif_generator.lua
-- Core responsibility: Define generators and their parameter handling logic
-- State management is handled by the UI sections that use this module

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

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

-- Generator definitions with their parameters
local generators = {
  starlight = {
    name = "Starlight",
    description = "Generates ethereal, twinkling patterns",
    params = {
      note = {
        type = "integer",
        min = 1,
        max = 71,  -- Matches theory_utils.get_scale() 10 octaves
        default = 15,
        step = 1,
        formatter = function(value)
          local notes = theory.get_scale()
          local note = notes[value]
          return musicutil.note_num_to_name(note, true)
        end
      },
      style = {
        type = "option",
        options = {"Sparse", "Dense", "Echo"},
        default = 1,
        step = 1
      }
    },
    generate = function(params)
      local events = {}
      local notes = theory.get_scale()
      local root_idx = params.note
      local style = params.style  -- Using numeric index
      
      if style == 1 then  -- Sparse
        -- Distant, occasional twinkles
        local num_steps = math.random(5, 8)
        local high_intervals = {7, 11, 14, 16}
        
        for step = 1, num_steps do
          -- 10% chance of root note, 90% chance of higher interval
          local note_idx
          if math.random() < 0.1 then
            note_idx = root_idx
          else
            note_idx = root_idx + high_intervals[math.random(#high_intervals)]
          end
          local note = notes[note_idx]
          
          local pos = theory.note_to_grid(note)
          local duration = math.random() * 0.3 + 0.2  -- 200-500ms
          local velocity = math.random(40, 70)
          
          add_note_event(events, note, (step - 1) * 0.5, duration, velocity)
        end
        return { events = events, duration = num_steps * 0.5 }
        
      elseif style == 2 then  -- Dense
        -- Rapid constellation of notes
        local num_steps = math.random(12, 18)
        local high_intervals = {7, 11, 14, 16, 19}
        
        for step = 1, num_steps do
          -- 30% chance of root note, 70% chance of higher interval
          local note_idx
          if math.random() < 0.3 then
            note_idx = root_idx
          else
            note_idx = root_idx + high_intervals[math.random(#high_intervals)]
          end
          local note = notes[note_idx]
          
          local pos = theory.note_to_grid(note)
          local duration = math.random() * 0.15 + 0.05
          local velocity = math.random(70, 100)
            
          add_note_event(events, note, (step - 1) * 0.15, duration, velocity)
        end
        return { events = events, duration = num_steps * 0.15 }
        
      elseif style == 3 then  -- Echo
        -- Repeating notes with diminishing velocity
        local num_main_notes = math.random(3, 4)
        local high_intervals = {7, 11, 14, 16}
        local time = 0
        
        for main = 1, num_main_notes do
          local note_idx = root_idx + high_intervals[math.random(#high_intervals)]
          local note = notes[note_idx]
          
          local pos = theory.note_to_grid(note)
          local num_echoes = math.random(2, 3)
          local base_velocity = math.random(70, 90)
          
          for echo = 1, num_echoes do
            local velocity = base_velocity * (1 - (echo-1) * 0.3)
            local duration = math.random() * 0.2 + 0.1
            
            add_note_event(events, note, time, duration, velocity)
            
            time = time + 0.2
          end
          time = time + 0.3
        end
        return { events = events, duration = time }
      end
    end
  }
}

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
  local motif_data = gen.generate(params)
  debug_print_motif(motif_data, generator_id, params)
  return motif_data
end

return MotifGenerator 
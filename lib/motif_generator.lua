-- motif_generator.lua
-- Core responsibility: Generate sequences of timed note events
-- in a format compatible with motif_recorder.lua output

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')
local MotifGenerator = {}

-- State values for preserving UI selections
local state = {
  current_generator = nil,
  param_values = {}
}

-- Shared parameter definitions
local NOTE_PARAM = {
  type = "integer",
  min = 1,
  -- This is hardcoded to 71 as `theory_utils.get_scale()` generates 10 octaves. 
  -- For now, this is easier than changing the param system to support dynamic max values.
  max = 71,
  default = 15,
  formatter = function(param)
    local notes = theory.get_scale()
    local note = notes[param]
    return note and musicutil.note_num_to_name(note, true)
  end
}

-- TODO: Figure this out. Should probably come from `theory_utils.lua`
-- Helper to find first valid grid position for a note
local function find_grid_position(note)
  return theory.note_to_grid(note)
end

-- Helper method to add note events to the events table
local function add_note_event(events, note, time, duration, velocity)
  local pos = find_grid_position(note)
  -- Note on
  table.insert(events, {
    time = time,
    type = "note_on",
    note = note,
    velocity = velocity,
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
    params = {
      note = NOTE_PARAM,
      style = {
        type = "option",
        options = {"Sparse", "Dense", "Echo"},
        default = "Sparse",
        formatter = function(param)
          local options = {"Sparse", "Dense", "Echo"}
          return options[param]
        end
      }
    },
    generate = function(params)
      local events = {}
      local notes = theory.get_scale()
      local root_idx = params.note
      local style = params.style
      
      if style == "Sparse" then
        -- Distant, occasional twinkles
        local num_steps = math.random(5, 8)
        local high_intervals = {7, 11, 14, 16}
        
        for step = 1, num_steps do
          local note_idx = math.random() < 0.1 and root_idx or 
                          root_idx + high_intervals[math.random(#high_intervals)]
          local note = notes[note_idx]
          
          local pos = find_grid_position(note)
          local duration = math.random() * 0.3 + 0.2  -- 200-500ms
          local velocity = math.random(40, 70)
          
          add_note_event(events, note, (step - 1) * 0.5, duration, velocity)
        end
        return { events = events, duration = num_steps * 0.5 }
        
      elseif style == "Dense" then
        -- Rapid constellation of notes
        local num_steps = math.random(12, 18)
        local high_intervals = {7, 11, 14, 16, 19}
        
        for step = 1, num_steps do
          local note_idx = math.random() < 0.3 and root_idx or 
                          root_idx + high_intervals[math.random(#high_intervals)]
          local note = notes[note_idx]
          
          local pos = find_grid_position(note)
          local duration = math.random() * 0.15 + 0.05
          local velocity = math.random(70, 100)
            
          add_note_event(events, note, (step - 1) * 0.15, duration, velocity)
        end
        return { events = events, duration = num_steps * 0.15 }
        
      elseif style == "Echo" then
        -- Repeating notes with diminishing velocity
        local num_main_notes = math.random(3, 4)
        local high_intervals = {7, 11, 14, 16}
        local time = 0
        
        for main = 1, num_main_notes do
          local note_idx = root_idx + high_intervals[math.random(#high_intervals)]
          local note = notes[note_idx]
          
          local pos = find_grid_position(note)
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

-- Get list of available generators in a consistent order
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

-- Get current generator
function MotifGenerator.get_current()
  return state.current_generator
end

-- Get parameters for a generator
function MotifGenerator.get_params(generator_id)
  local gen = generators[generator_id]
  if not gen then return nil end
  
  local params = {}
  for id, spec in pairs(gen.params) do
    params[id] = {
      id = id,
      spec = spec,
      value = state.param_values[generator_id] and state.param_values[generator_id][id] or spec.default
    }
  end
  return params
end

-- Set current generator
function MotifGenerator.select_generator(generator_id)
  if not generators[generator_id] then return false end
  
  -- Initialize parameter values if needed
  if not state.param_values[generator_id] then
    state.param_values[generator_id] = {}
    for id, spec in pairs(generators[generator_id].params) do
      state.param_values[generator_id][id] = spec.default
    end
  end
  
  state.current_generator = generator_id
  return true
end

-- Update a parameter value
function MotifGenerator.set_param(param_id, value)
  if not state.current_generator then return false end
  
  local gen = generators[state.current_generator]
  local spec = gen.params[param_id]
  if not spec then return false end
  
  -- Handle different parameter types
  if spec.type == "integer" then
    value = math.floor(value + 0.5)
    value = util.clamp(value, spec.min, spec.max)
  elseif spec.type == "option" then
    -- For option types, value should be one of the valid options
    local valid = false
    for _, opt in ipairs(spec.options) do
      if opt == value then
        valid = true
        break
      end
    end
    if not valid then return false end
  end
  
  state.param_values[state.current_generator][param_id] = value
  return true
end

-- Helper to print a readable version of a motif for debugging
local function print_motif(motif, generator_name, params)
  print("\n=== Generated Motif ===")
  print(string.format("Generator: %s", generator_name))
  print("Parameters:")
  for id, value in pairs(params) do
    local gen = generators[state.current_generator]
    local spec = gen.params[id]
    local display_value = spec.formatter and spec.formatter(value) or value
    print(string.format("  %s: %s", id, display_value))
  end
  print(string.format("Duration: %.2f", motif.duration))
  print("Notes:")
  
  -- Group note_on/note_off events
  local notes = {}
  local note_id = 1
  
  for i = 1, #motif.events do
    local event = motif.events[i]
    if event.type == "note_on" then
      -- Look ahead for matching note_off
      local duration = nil
      for j = i + 1, #motif.events do
        local next_event = motif.events[j]
        if next_event.type == "note_off" and next_event.note == event.note then
          duration = next_event.time - event.time
          break
        end
      end
      
      if duration then
        table.insert(notes, {
          id = note_id,
          note = event.note,
          start = event.time,
          stop = event.time + duration,
          velocity = event.velocity
        })
        note_id = note_id + 1
      end
    end
  end
  
  -- Sort by start time
  table.sort(notes, function(a, b) return a.start < b.start end)
  
  for _, note in ipairs(notes) do
    print(string.format("%d: %s %.2f→%.2f vel=%d", 
      note.id,
      musicutil.note_num_to_name(note.note, true),
      note.start,
      note.stop,
      note.velocity
    ))
  end
  print(string.format("Total events: %d", #motif.events))
  print("====================\n")
end

-- Generate using current parameters
function MotifGenerator.generate()  
  local gen = generators[state.current_generator]
  local params = state.param_values[state.current_generator]

  local motif = gen.generate(params)
  print_motif(motif, gen.name, params)
  return motif
end

-- Initialize with first generator
MotifGenerator.select_generator("starlight")

return MotifGenerator 
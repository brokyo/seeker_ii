-- _template.lua
-- Template and best practices for creating new generators
-- Copy this file as a starting point for new generators

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

--[[ Generator Interface:
{
  name = "Human readable name",
  description = "Clear description of what this generator creates",
  params = {
    param_name = {
      -- Integer params (good for notes, counts, steps)
      type = "integer",
      min = number,
      max = number,
      default = number,
      step = number,
      formatter = function(value) -> string,  -- Optional
      
      -- Option params (good for modes, styles, patterns)
      type = "option",
      options = {"Option1", "Option2", ...},
      default = 1,  -- 1-based index into options
      step = 1,
      
      -- Number params (good for time, probability, intensity)
      type = "number",
      min = number,
      max = number,
      default = number,
      step = number,  -- Can be fractional for fine control
      formatter = function(value) -> string,  -- Optional
      
      -- Control params (good for musical expression)
      type = "control",
      min = 0,
      max = 100,
      default = 50,
      step = 1,
      formatter = function(value) -> string  -- Optional
    }
  },
  generate = function(params, add_note_event) -> { events = [], duration = number }
}
--]]

-- Example generator showing best practices
return {
  -- Clear, descriptive name and description
  name = "Generator Name",
  description = "Brief description of the musical patterns this creates",
  
  -- Define parameters with clear ranges and defaults
  params = {
    -- Example integer parameter (like a note)
    root = {
      type = "integer",
      min = 1,
      max = 71,
      default = 15,
      step = 1,
      formatter = function(value)
        local notes = theory.get_scale()
        local note = notes[value]
        return musicutil.note_num_to_name(note, true)
      end
    },
    
    -- Example option parameter (like a style/mode)
    style = {
      type = "option",
      options = {"Style1", "Style2", "Style3"},
      default = 1,
      step = 1
    }
  },
  
  -- Main generation function
  generate = function(params, add_note_event)
    -- Initialize empty events table
    local events = {}
    
    -- Get commonly needed values
    local notes = theory.get_scale()
    local root_idx = params.root
    local style = params.style  -- Numeric index into options
    
    -- Track time for event scheduling
    local time = 0
    local total_duration = 0  -- Track for return value
    
    -- Example pattern generation
    if style == 1 then  -- Style1
      -- 1. Define clear musical variables at the start
      local num_notes = 4
      local note_spacing = 0.25  -- Quarter notes
      local base_velocity = 80
      
      -- 2. Generate the pattern
      for i = 1, num_notes do
        -- Calculate musical values
        local note_idx = root_idx + (i-1)  -- Example: ascending pattern
        local note = notes[note_idx]
        local duration = 0.2
        local velocity = base_velocity
        
        -- Add the note event
        add_note_event(events, note, time, duration, velocity)
        
        -- Update timing
        time = time + note_spacing
      end
      
      total_duration = time
      
    elseif style == 2 then  -- Style2
      -- Different pattern logic here...
      
    else  -- Style3
      -- Different pattern logic here...
      
    end
    
    -- Return both the events and total duration
    return {
      events = events,
      duration = total_duration
    }
  end
}

--[[ Best Practices:
1. File Organization
   - Clear file name that describes the generator
   - Header comment explaining the generator's purpose
   - Required imports at the top
   - Single return table with all components

2. Parameters
   - Use descriptive parameter names
   - Set reasonable min/max values for integers
   - Provide clear option names
   - Use formatters for human-readable values

3. Generation Function
   - Initialize variables at the start
   - Use clear variable names
   - Break complex patterns into steps
   - Track time explicitly
   - Handle all style options
   - Return both events and duration

4. Musical Patterns
   - Define musical constants (intervals, durations, etc.) at the start
   - Use clear names for musical concepts
   - Consider velocity for expression
   - Use consistent time units (usually seconds)
   - Think about note spacing and overlap

5. Error Handling
   - Validate note indices before use
   - Ensure velocities are in valid range (0-127)
   - Return valid event structure always
--]] 
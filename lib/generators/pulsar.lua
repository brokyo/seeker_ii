-- pulsar.lua
-- Generator for steady, foundational rhythmic patterns
-- Acts as a rhythmic anchor point for other musical elements

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Pulsar",
  description = "Steady rhythmic core that anchors other musical elements",
  params = {
    note = {
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
    
    rate = {
      type = "option",
      options = {"1/2", "1", "2", "4", "8"},  -- Much longer intervals
      default = 2,  -- 1 bar
      step = 1
    },
    
    intensity = {
      type = "control",
      min = 0,
      max = 100,
      default = 70,
      step = 1,
      formatter = function(value)
        if value < 30 then return "Gentle"
        elseif value < 60 then return "Moderate"
        elseif value < 85 then return "Strong"
        else return "Intense"
        end
      end
    },
    
    variation = {
      type = "control",
      min = 0,
      max = 100,
      default = 20,
      step = 1,
      formatter = function(value)
        if value < 20 then return "Steady"
        elseif value < 50 then return "Breathing"
        elseif value < 80 then return "Flowing"
        else return "Dynamic"
        end
      end
    }
  },
  
  generate = function(params, add_note_event)
    local events = {}
    local notes = theory.get_scale()
    -- params.note is 1-based index into scale
    local note = notes[params.note]
    if not note then return { events = {}, duration = 0 } end  -- Safety check
    
    -- Convert intensity (0-100) to base velocity (30-110)
    local base_velocity = 30 + math.floor(params.intensity * 0.8)
    
    -- Calculate pattern length (8 bars for longer patterns)
    local pattern_length = 8.0
    local time = 0
    
    -- Convert rate option to duration in seconds
    local rate_values = {0.5, 1.0, 2.0, 4.0, 8.0}  -- Matches options array
    local main_pulse_rate = rate_values[params.rate]
    
    while time < pattern_length do
      -- Calculate main pulse velocity with variation
      local variation_amount = params.variation * 0.01
      local velocity_mod = 0
      
      if variation_amount > 0 then
        -- Create smooth variation using sine wave
        local phase = time / pattern_length * math.pi * 2
        velocity_mod = math.sin(phase) * (variation_amount * 20)
      end
      
      -- Main strong pulse
      local main_velocity = math.floor(base_velocity + velocity_mod)
      main_velocity = math.max(30, math.min(110, main_velocity))
      
      -- Add the main pulse - longer duration for emphasis
      local main_duration = main_pulse_rate * 0.4  -- 40% of the interval
      add_note_event(events, note, time, main_duration, main_velocity)
      
      -- Add subtle echo pulses between main beats if variation is high enough
      if variation_amount > 0.3 then  -- Only add echoes with moderate to high variation
        local num_echoes = math.floor(variation_amount * 3)  -- 1-3 echoes based on variation
        local echo_spacing = main_pulse_rate / (num_echoes + 1)
        
        for echo = 1, num_echoes do
          local echo_time = time + (echo * echo_spacing)
          if echo_time < pattern_length then
            -- Echo velocity decreases with each repeat
            local echo_velocity = math.floor(main_velocity * (0.4 - (echo * 0.1)))
            -- Shorter duration for echoes
            local echo_duration = echo_spacing * 0.3
            
            add_note_event(events, note, echo_time, echo_duration, echo_velocity)
          end
        end
      end
      
      -- Move to next main pulse
      time = time + main_pulse_rate
    end
    
    return { events = events, duration = pattern_length }
  end
} 
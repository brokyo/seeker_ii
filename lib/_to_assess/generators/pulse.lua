-- pulse.lua
-- Generator for rhythmic patterns ranging from simple to complex pulses

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Pulse",
  description = "Rhythmic patterns from heartbeats to complex waves",
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
    style = {
      type = "option",
      options = {"Heart", "Breath", "Wave"},  -- Renamed Tide to Wave for clarity
      default = 1,
      step = 1
    }
  },
  
  generate = function(params, add_note_event)
    local events = {}
    local notes = theory.get_scale()
    local root_idx = params.note
    local style = params.style
    local note = notes[root_idx]
    
    if style == 1 then  -- Heart
      -- Simple, steady pulse with subtle accent pattern
      local pattern_length = 4.0  -- 4 seconds total
      local time = 0
      
      -- Define the heartbeat pattern
      -- Each subarray represents [duration, velocity]
      local heart_pattern = {
        {0.25, 100},  -- Strong beat
        {0.25, 85},   -- Echo beat
        {0.50, 70},   -- Rest
      }
      
      -- Repeat the pattern to fill our time
      while time < pattern_length do
        for _, beat in ipairs(heart_pattern) do
          local duration = beat[1]
          local velocity = beat[2]
          
          -- Only add note if this isn't a rest
          if velocity > 0 then
            add_note_event(events, note, time, duration * 0.8, velocity)
          end
          
          time = time + duration
        end
      end
      
      return { events = events, duration = pattern_length }
      
    elseif style == 2 then  -- Breath
      -- Gradual swells in velocity, like breathing
      local breath_duration = 2.0  -- One complete breath
      local num_breaths = 2
      local time = 0
      
      for breath = 1, num_breaths do
        -- Each breath has 8 steps
        local steps_per_breath = 8
        local step_duration = breath_duration / steps_per_breath
        
        for step = 1, steps_per_breath do
          -- Create smooth velocity curve using sine wave
          local phase = (step-1) / steps_per_breath * math.pi * 2
          local velocity = math.floor(60 + math.sin(phase) * 40)
          
          -- Longer notes during inhale (first half), shorter during exhale
          local note_duration = step <= steps_per_breath/2 
            and step_duration * 0.9  -- Inhale
            or step_duration * 0.7   -- Exhale
          
          add_note_event(events, note, time, note_duration, velocity)
          time = time + step_duration
        end
      end
      
      return { events = events, duration = breath_duration * num_breaths }
      
    else  -- Wave
      -- Complex pattern with rising and falling intensity
      local time = 0
      
      -- Define wave sections with different intensities
      local wave_sections = {
        -- Each section: {num_pulses, base_velocity, duration}
        {3, 100, 0.5},  -- Strong opening
        {2, 70, 0.25},  -- Quick follow-up
        {4, 85, 0.3},   -- Building intensity
        {2, 60, 0.4},   -- Gentle fade
      }
      
      for _, section in ipairs(wave_sections) do
        local num_pulses = section[1]
        local base_velocity = section[2]
        local pulse_duration = section[3]
        
        for pulse = 1, num_pulses do
          -- Slight velocity variation within section
          local velocity = base_velocity + math.random(-10, 10)
          
          -- Ensure velocity stays in valid range
          velocity = math.max(1, math.min(127, velocity))
          
          add_note_event(events, note, time, pulse_duration * 0.8, velocity)
          time = time + pulse_duration
        end
      end
      
      -- Add final long note
      add_note_event(events, note, time, 0.8, 70)
      time = time + 0.8
      
      return { events = events, duration = time }
    end
  end
} 
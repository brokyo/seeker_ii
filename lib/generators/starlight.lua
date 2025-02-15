-- starlight.lua
-- Generator for celestial-inspired musical patterns

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Starlight",
  description = "Celestial patterns inspired by the night sky",
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
      options = {"Constellation", "Nebula", "Pulsar"},
      default = 1,
      step = 1
    }
  },
  generate = function(params, add_note_event)
    local events = {}
    local notes = theory.get_scale()
    local root_idx = params.note
    local style = params.style  -- Using numeric index
    
    if style == 1 then  -- Constellation
      -- A pattern of connected bright points
      local num_stars = math.random(6, 9)
      -- Use wider intervals for more space between notes
      local intervals = {0, 4, 7, 11, 14, 16, 19}
      local time = 0
      local last_interval = 0  -- Track last interval for connected movement
      
      for star = 1, num_stars do
        -- Choose interval near the last one for connected movement
        local interval_options = {}
        for _, interval in ipairs(intervals) do
          if math.abs(interval - last_interval) <= 7 then
            table.insert(interval_options, interval)
          end
        end
        
        if #interval_options == 0 then
          interval_options = intervals
        end
        
        local interval = interval_options[math.random(#interval_options)]
        last_interval = interval
        local note_idx = root_idx + interval
        local note = notes[note_idx]
        
        -- Longer notes for main stars, shorter for connecting ones
        local is_main_star = star % 2 == 1
        local duration = is_main_star and 0.4 or 0.2
        local velocity = is_main_star and math.random(70, 85) or math.random(45, 60)
        
        add_note_event(events, note, time, duration, velocity)
        
        -- Variable time between stars
        time = time + (is_main_star and 0.5 or 0.3)
      end
      
      return { events = events, duration = time }
      
    elseif style == 2 then  -- Nebula
      -- Cloudy, overlapping notes with harmonic relationships
      local duration = 4.0
      local time = 0
      -- Use harmonically related intervals for ethereal sound
      local base_intervals = {0, 4, 7, 11, 14}
      
      while time < duration do
        -- Play 2-3 notes together for cloud-like effect
        local num_simultaneous = math.random(2, 3)
        
        for i = 1, num_simultaneous do
          local interval = base_intervals[math.random(#base_intervals)]
          -- Occasionally transpose up an octave
          if math.random() < 0.4 then
            interval = interval + 12
          end
          
          local note_idx = root_idx + interval
          local note = notes[note_idx]
          
          -- Overlapping note durations
          local note_duration = math.random() * 0.4 + 0.3
          -- Gentle velocities with slight variation
          local velocity = math.random(40, 60)
          
          add_note_event(events, note, time, note_duration, velocity)
        end
        
        -- Small random time increments
        time = time + math.random() * 0.2 + 0.1
      end
      
      return { events = events, duration = duration }
      
    else  -- Pulsar
      -- Regular pulses with intensity variations
      local num_pulses = math.random(4, 6)
      local notes_per_pulse = 3
      local time = 0
      -- Use close intervals for focused energy
      local intervals = {0, 2, 4}
      
      for pulse = 1, num_pulses do
        local base_velocity = math.random(70, 90)
        
        for note_num = 1, notes_per_pulse do
          local interval = intervals[math.random(#intervals)]
          local note_idx = root_idx + interval
          local note = notes[note_idx]
          
          -- Quick, staccato notes
          local duration = 0.1
          -- Velocity decreases through each pulse
          local velocity = base_velocity * (1 - (note_num-1)/notes_per_pulse * 0.4)
          
          add_note_event(events, note, time, duration, velocity)
          time = time + 0.1
        end
        
        -- Gap between pulses
        time = time + 0.4
      end
      
      return { events = events, duration = time }
    end
  end
} 
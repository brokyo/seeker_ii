  orbit = {
    name = "Orbit",
    description = "Celestial patterns circling a central note",
    params = {
      note = NOTE_PARAM,
      style = {
        type = "option",
        options = {"Cycle", "Binary", "Pulsar"},
        default = "Cycle",
        formatter = function(param)
          local options = {"Cycle", "Binary", "Pulsar"}
          return options[param]
        end
      }
    },
    generate = function(params)
      local events = {}
      local notes = theory.get_scale()
      local root_idx = params.note
      local style = params.style
      
      if style == "Cycle" then
        -- Simple orbital pattern using scale degrees around root
        local orbit_intervals = {0, 2, 4, 2}  -- Up and down pattern
        local num_cycles = math.random(2, 3)
        local step_duration = 0.25
        
        for cycle = 1, num_cycles do
          for step, interval in ipairs(orbit_intervals) do
            local note_idx = root_idx + interval
            local note = notes[note_idx]
            
            if note then
              local pos = find_grid_position(note)
              local time = ((cycle-1) * #orbit_intervals + (step-1)) * step_duration
              -- Gentle velocity changes based on position in cycle
              local velocity = math.floor(75 + math.sin(step/#orbit_intervals * math.pi * 2) * 15)
              
              table.insert(events, {
                time = time,
                type = "note_on",
                note = note,
                velocity = velocity,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = time + (step_duration * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
            end
          end
        end
        return { events = events, duration = num_cycles * #orbit_intervals * step_duration }
        
      elseif style == "Binary" then
        -- Two interweaving patterns
        local orbit1 = {0, 4, 7}  -- First pattern (root, third, fifth)
        local orbit2 = {2, 5, 9}  -- Second pattern (offset intervals)
        local num_cycles = math.random(2, 3)
        local step_duration = 0.2
        
        for cycle = 1, num_cycles do
          -- First orbit
          for i, interval in ipairs(orbit1) do
            local note_idx = root_idx + interval
            local note = notes[note_idx]
            
            if note then
              local pos = find_grid_position(note)
              local time = ((cycle-1) * (#orbit1 + #orbit2) + (i-1) * 2) * step_duration
              
              table.insert(events, {
                time = time,
                type = "note_on",
                note = note,
                velocity = math.random(70, 85),
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = time + (step_duration * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
            end
          end
          
          -- Second orbit
          for i, interval in ipairs(orbit2) do
            local note_idx = root_idx + interval
            local note = notes[note_idx]
            
            if note then
              local pos = find_grid_position(note)
              local time = ((cycle-1) * (#orbit1 + #orbit2) + (i-1) * 2 + 1) * step_duration
              
              table.insert(events, {
                time = time,
                type = "note_on",
                note = note,
                velocity = math.random(60, 75), -- Slightly quieter
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = time + (step_duration * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
            end
          end
        end
        return { events = events, duration = num_cycles * (#orbit1 + #orbit2) * step_duration }
        
      else -- Pulsar
        -- Regular pattern with intensity pulses
        local base_intervals = {0, 4, 7, 11}  -- Extended chord
        local num_pulses = math.random(3, 4)
        local notes_per_pulse = 6
        local step_duration = 0.15
        local time = 0
        
        for pulse = 1, num_pulses do
          -- Each pulse starts strong and fades
          local base_velocity = math.random(85, 100)
          
          for step = 1, notes_per_pulse do
            local interval = base_intervals[math.random(#base_intervals)]
            local note_idx = root_idx + interval
            local note = notes[note_idx]
            
            if note then
              local pos = find_grid_position(note)
              -- Velocity fades over the pulse
              local velocity = base_velocity * (1 - (step-1)/notes_per_pulse * 0.7)
              
              table.insert(events, {
                time = time,
                type = "note_on",
                note = note,
                velocity = velocity,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = time + (step_duration * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              time = time + step_duration
            end
          end
          
          -- Add space between pulses
          time = time + step_duration * 2
        end
        return { events = events, duration = time }
      end
    end
  },
  
  pulse = {
    name = "Pulse",
    description = "Rhythmic patterns from simple to complex",
    params = {
      note = NOTE_PARAM,
      style = {
        type = "option",
        options = {"Heart", "Breath", "Tide"},
        default = "Heart",
        formatter = function(param)
          local options = {"Heart", "Breath", "Tide"}
          return options[param]
        end
      }
    },
    generate = function(params)
      local events = {}
      local notes = theory.get_scale()
      local root_idx = params.note
      local style = params.style
      local note = notes[root_idx]  -- Base note for all patterns
      
      if style == "Heart" then
        -- Simple, steady pulse with subtle accent pattern (like a heartbeat)
        local num_beats = 16
        local step_duration = 0.25  -- Quarter notes
        
        for step = 1, num_beats do
          if note then
            local pos = find_grid_position(note)
            -- Accent every 4th beat, slight emphasis on beat 2
            local velocity = (step % 4 == 1) and 100 or
                           (step % 4 == 2) and 85 or 70
            
            table.insert(events, {
              time = (step - 1) * step_duration,
              type = "note_on",
              note = note,
              velocity = velocity,
              x = pos and pos.x or nil,
              y = pos and pos.y or nil
            })
            
            table.insert(events, {
              time = (step - 1) * step_duration + (step_duration * 0.5),
              type = "note_off",
              note = note,
              x = pos and pos.x or nil,
              y = pos and pos.y or nil
            })
          end
        end
        return { events = events, duration = num_beats * step_duration }
        
      elseif style == "Breath" then
        -- Gradual swells in velocity, like breathing
        local num_breaths = 4
        local steps_per_breath = 8
        local step_duration = 0.125  -- Eighth notes
        
        for breath = 1, num_breaths do
          for step = 1, steps_per_breath do
            if note then
              local pos = find_grid_position(note)
              -- Sine wave for velocity to create natural swell
              local phase = (step-1) / steps_per_breath * math.pi * 2
              local velocity = math.floor(70 + math.sin(phase) * 30)
              
              table.insert(events, {
                time = ((breath-1) * steps_per_breath + (step-1)) * step_duration,
                type = "note_on",
                note = note,
                velocity = velocity,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = ((breath-1) * steps_per_breath + (step-1)) * step_duration + (step_duration * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
            end
          end
        end
        return { events = events, duration = num_breaths * steps_per_breath * step_duration }
        
      else -- Tide
        -- Long cycle with mini-patterns within
        local pattern = {
          {dur = 0.5, vel = 100},  -- Strong hit
          {dur = 0.25, vel = 70},  -- Quick follow-up
          {dur = 0.25, vel = 70},
          {dur = 0.5, vel = 85},   -- Medium accent
          {dur = 0.25, vel = 70},
          {dur = 0.25, vel = 70}
        }
        local num_cycles = 2
        local time = 0
        
        for cycle = 1, num_cycles do
          for _, beat in ipairs(pattern) do
            if note then
              local pos = find_grid_position(note)
              
              table.insert(events, {
                time = time,
                type = "note_on",
                note = note,
                velocity = beat.vel,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              table.insert(events, {
                time = time + (beat.dur * 0.8),
                type = "note_off",
                note = note,
                x = pos and pos.x or nil,
                y = pos and pos.y or nil
              })
              
              time = time + beat.dur
            end
          end
        end
        return { events = events, duration = time }
      end
    end
  }
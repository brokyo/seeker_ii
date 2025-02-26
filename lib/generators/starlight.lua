-- starlight.lua
-- Generator for celestial-inspired musical patterns

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Starlight",
  description = "Celestial patterns in the night sky",
  params = {
    style = {
      type = "option",
      options = {"Constellation", "Nebula", "Pulsar"},
      default = 1
    },
    root = {
      type = "integer",
      min = 1,
      max = 16,
      default = 1,
      formatter = function(param) return tostring(param) end
    }
  },
  generate = function(params, add_note_event)
    local events = {}
    local style = params.style
    local root_x = params.root
    local root_y = 8  -- Start from bottom row
    
    -- Helper to get valid positions near a point
    local function get_nearby_positions(x, y, max_distance)
      local positions = {}
      for test_x = math.max(1, x - max_distance), math.min(16, x + max_distance) do
        for test_y = math.max(1, y - max_distance), math.min(8, y + max_distance) do
          -- Skip the exact point
          if test_x ~= x or test_y ~= y then
            table.insert(positions, {x = test_x, y = test_y})
          end
        end
      end
      return positions
    end

    if style == 1 then  -- Constellation
      -- A pattern of connected bright points
      local num_stars = math.random(6, 9)
      local time = 0
      local last_pos = {x = root_x, y = root_y}
      
      for star = 1, num_stars do
        -- Get valid positions near the last star
        local nearby = get_nearby_positions(last_pos.x, last_pos.y, 3)
        if #nearby == 0 then
          -- If no nearby positions, reset to root
          last_pos = {x = root_x, y = root_y}
          nearby = get_nearby_positions(last_pos.x, last_pos.y, 3)
        end
        
        -- Pick a random nearby position
        local pos = nearby[math.random(#nearby)]
        last_pos = pos
        
        -- Convert position to note
        local note = theory.grid_to_note(pos.x, pos.y, 4)  -- Use octave 4 as default
        
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
      -- Cloudy, overlapping notes in nearby positions
      local duration = 4.0
      local time = 0
      local last_positions = {}  -- Track recent positions to create clusters
      
      while time < duration do
        -- Get positions near recent positions or root
        local valid_positions
        if #last_positions > 0 then
          local center = last_positions[math.random(#last_positions)]
          valid_positions = get_nearby_positions(center.x, center.y, 2)
        else
          valid_positions = get_nearby_positions(root_x, root_y, 3)
        end
        
        -- Play 2-3 notes together for cloud-like effect
        local num_simultaneous = math.random(2, 3)
        
        for i = 1, num_simultaneous do
          if #valid_positions > 0 then
            -- Pick a random position
            local pos_idx = math.random(#valid_positions)
            local pos = valid_positions[pos_idx]
            table.remove(valid_positions, pos_idx)
            
            -- Add to recent positions, keeping last 3
            table.insert(last_positions, pos)
            if #last_positions > 3 then
              table.remove(last_positions, 1)
            end
            
            -- Convert position to note
            local note = theory.grid_to_note(pos.x, pos.y, 4)
            
            -- Overlapping note durations
            local note_duration = math.random() * 0.4 + 0.3
            -- Gentle velocities with slight variation
            local velocity = math.random(40, 60)
            
            add_note_event(events, note, time, note_duration, velocity)
          end
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
      
      for pulse = 1, num_pulses do
        local base_velocity = math.random(70, 90)
        local pulse_positions = get_nearby_positions(root_x, root_y, 2)
        
        for note_num = 1, notes_per_pulse do
          if #pulse_positions > 0 then
            -- Pick a random position
            local pos_idx = math.random(#pulse_positions)
            local pos = pulse_positions[pos_idx]
            table.remove(pulse_positions, pos_idx)
            
            -- Convert position to note
            local note = theory.grid_to_note(pos.x, pos.y, 4)
            
            -- Quick, staccato notes
            local duration = 0.1
            -- Velocity decreases through each pulse
            local velocity = base_velocity * (1 - (note_num-1)/notes_per_pulse * 0.4)
            
            add_note_event(events, note, time, duration, velocity)
            time = time + 0.1
          end
        end
        
        -- Gap between pulses
        time = time + 0.4
      end
      
      return { events = events, duration = time }
    end
  end
} 
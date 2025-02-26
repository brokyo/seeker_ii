-- starlight.lua
-- Generator for celestial-inspired musical patterns

local theory = include('lib/theory_utils')
local musicutil = require('musicutil')

return {
  name = "Starlight",
  description = "Celestial patterns in the night sky",
  params = {
    style = {
      name = "Style",
      type = "option",
      options = {"Constellation", "Nebula", "Pulsar"},
      default = 1,
      step = 1
    },
    root = {
      name = "Root Position",
      type = "number",
      min = 1,
      max = 16,
      default = 1,
      step = 1,
      formatter = function(param) return tostring(param) end
    }
  },
  generate = function(params, add_note_event)
    local events = {}
    local style = params.style
    local root_x = params.root
    local root_y = 8  -- Start from bottom row
    
    -- Movement patterns for different styles
    local movements = {
      -- Constellation: Move in lines/angles
      [1] = {
        {dx = 1, dy = -1},   -- up-right
        {dx = 1, dy = 0},    -- right
        {dx = 1, dy = 1},    -- down-right
        {dx = -1, dy = -1},  -- up-left
        {dx = -1, dy = 0},   -- left
        {dx = -1, dy = 1}    -- down-left
      },
      -- Nebula: Cluster movements
      [2] = {
        {dx = 1, dy = 0},    -- right
        {dx = -1, dy = 0},   -- left
        {dx = 0, dy = 1},    -- down
        {dx = 0, dy = -1},   -- up
        {dx = 1, dy = 1},    -- down-right
        {dx = -1, dy = -1}   -- up-left
      },
      -- Pulsar: Radial movements
      [3] = {
        {dx = 2, dy = 0},    -- far right
        {dx = -2, dy = 0},   -- far left
        {dx = 1, dy = 1},    -- down-right
        {dx = -1, dy = 1},   -- down-left
        {dx = 1, dy = -1},   -- up-right
        {dx = -1, dy = -1}   -- up-left
      }
    }

    if style == 1 then  -- Constellation
      -- Create a connected pattern of stars
      local num_stars = math.random(6, 9)
      local time = 0
      local x, y = root_x, root_y
      
      for star = 1, num_stars do
        -- Pick a movement that keeps us on the grid
        local valid_moves = {}
        for _, move in ipairs(movements[1]) do
          local new_x = x + move.dx
          local new_y = y + move.dy
          if new_x >= 1 and new_x <= 16 and new_y >= 1 and new_y <= 8 then
            table.insert(valid_moves, move)
          end
        end
        
        if #valid_moves > 0 then
          -- Choose random valid movement
          local move = valid_moves[math.random(#valid_moves)]
          x = x + move.dx
          y = y + move.dy
          
          -- Get note at this position
          local note = theory.grid_to_note(x, y, 4)
          
          -- Longer notes for main stars, shorter for connecting ones
          local is_main_star = star % 2 == 1
          local duration = is_main_star and 0.4 or 0.2
          local velocity = is_main_star and math.random(70, 85) or math.random(45, 60)
          
          add_note_event(events, note, time, duration, velocity)
          
          -- Variable time between stars
          time = time + (is_main_star and 0.5 or 0.3)
        end
      end
      
      return { events = events, duration = time }
      
    elseif style == 2 then  -- Nebula
      -- Create clusters of overlapping notes
      local duration = 4.0
      local time = 0
      local x, y = root_x, root_y
      
      while time < duration do
        -- Play 2-3 notes in cluster
        local num_notes = math.random(2, 3)
        
        for i = 1, num_notes do
          -- Move to nearby position
          local move = movements[2][math.random(#movements[2])]
          local new_x = util.clamp(x + move.dx, 1, 16)
          local new_y = util.clamp(y + move.dy, 1, 8)
          x, y = new_x, new_y
          
          -- Get note at this position
          local note = theory.grid_to_note(x, y, 4)
          
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
      -- Create radiating patterns from center
      local num_pulses = math.random(4, 6)
      local notes_per_pulse = 3
      local time = 0
      
      for pulse = 1, num_pulses do
        local base_velocity = math.random(70, 90)
        local x, y = root_x, root_y  -- Start each pulse from root
        
        for note_num = 1, notes_per_pulse do
          -- Move outward from center
          local move = movements[3][math.random(#movements[3])]
          local new_x = util.clamp(x + move.dx, 1, 16)
          local new_y = util.clamp(y + move.dy, 1, 8)
          x, y = new_x, new_y
          
          -- Get note at this position
          local note = theory.grid_to_note(x, y, 4)
          
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
-- transforms.lua
-- Transform System: An algorithmic garden for pattern manipulation

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

transforms.available = {
  noop = {
    name = "No Operation",
    ui_name = "None",
    ui_order = 1,
    description = "Returns the exact same sequence with no changes",
    params = {},
    fn = function(events, params)
      -- Deep copy events
      local result = {}
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        table.insert(result, new_event)
      end
      return result
    end
  },
  
  overdub_filter = {
    name = "Overdub Filter",
    ui_name = "Overdub Filter",
    ui_order = 2,
    description = "Filter events to include only specific overdub rounds",
    params = {
      mode = {
        type = "option",
        default = 1,
        options = {"Up to", "Only", "Except"}
      },
      round = {
        type = "integer",
        default = 1,
        min = 1,
        max = 10,  -- Hard coded to 10 because I don't have a working way to set dynamic parameters
        step = 1
      }
    },
    fn = function(events, params)
      -- Find the maximum generations in the events
      local max_generation = 1
      for _, event in ipairs(events) do
        local generation = event.generation or 1
        if generation > max_generation then
          max_generation = generation
        end
      end
      
      -- Clamp the target generation to the maximum found
      local mode = params.mode or 1
      local target_generation = params.round or 1
      if target_generation > max_generation then
        target_generation = max_generation
      end
      
      local result = {}
      
      for _, event in ipairs(events) do
        local generation = event.generation or 1
        local include = false
        
        if mode == 1 then
          -- "Up to" - include generations <= target
          include = (generation <= target_generation)
        elseif mode == 2 then
          -- "Only" - include only the target generation
          include = (generation == target_generation)
        elseif mode == 3 then
          -- "Except" - include everything except target
          include = (generation ~= target_generation)
        end
        
        if include then
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          table.insert(result, new_event)
        end
      end
      
      return result
    end
  },
  
  resonate = {
    name = "Resonate",
    ui_name = "Harmonize",
    ui_order = 3,
    description = "Adds subtle harmonic overtones that sustain and blend with the melody",
    params = {
      third_chance = {
        order = 1,
        type = "number",
        default = 0.3,
        min = 0,
        max = 1,
        step = 0.1
      },
      third_volume = {
        order = 2,
        type = "number",
        default = 0.5,
        min = 0.1,
        max = 1,
        step = 0.1
      },
      octave_chance = {
        order = 3,
        type = "number",
        default = 0.2,
        min = 0,
        max = 1,
        step = 0.1
      },
      octave_volume = {
        order = 4,
        type = "number",
        default = 0.5,
        min = 0.1,
        max = 1,
        step = 0.1
      }
    },
    fn = function(events, params)
      local third_chance = params.third_chance or 0.3
      local third_volume = params.third_volume or 0.5
      local octave_chance = params.octave_chance or 0.2
      local octave_volume = params.octave_volume or 0.5
      
      -- Built-in humanization constants
      local TIMING_VARIATION = 0.015  -- 15ms maximum timing variation
      local THIRD_VELOCITY_VARIATION = 0.1   -- ±10% velocity variation for third
      local OCTAVE_VELOCITY_VARIATION = 0.15 -- ±15% velocity variation for octave
      
      -- Helper function for subtle randomization
      local function humanize_value(base_value, range)
        return base_value + (math.random() * 2 - 1) * range
      end
      
      local result = {}
      local active_harmonics = {}
      
      for _, event in ipairs(events) do
        -- Copy original event
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        table.insert(result, new_event)
        
        if event.type == "note_on" then
          local note_id = event.note
          -- Store timing variations to reuse in note_off
          active_harmonics[note_id] = {
            has_third = math.random() < third_chance,
            has_octave = math.random() < octave_chance,
            third_delay = humanize_value(0, TIMING_VARIATION),
            octave_delay = humanize_value(0, TIMING_VARIATION)
          }
          
          if active_harmonics[note_id].has_third then
            local third_velocity = math.floor(
              event.velocity * 
              humanize_value(third_volume, THIRD_VELOCITY_VARIATION)
            )
            
            -- Add slight pre-delay and longer sustain for third
            table.insert(result, {
              type = "note_on",
              time = event.time + active_harmonics[note_id].third_delay,
              note = event.note + 16,
              velocity = third_velocity
            })
          end
          
          if active_harmonics[note_id].has_octave then
            local octave_velocity = math.floor(
              event.velocity * 
              humanize_value(octave_volume, OCTAVE_VELOCITY_VARIATION)
            )
            
            table.insert(result, {
              type = "note_on",
              time = event.time + active_harmonics[note_id].octave_delay,
              note = event.note - 12,
              velocity = octave_velocity
            })
          end
        end
        
        if event.type == "note_off" then
          local note_id = event.note
          
          if active_harmonics[note_id] then
            if active_harmonics[note_id].has_third then
              table.insert(result, {
                type = "note_off",
                time = event.time + active_harmonics[note_id].third_delay + 0.1, -- Extra sustain
                note = event.note + 16
              })
            end
            
            if active_harmonics[note_id].has_octave then
              table.insert(result, {
                type = "note_off",
                time = event.time + active_harmonics[note_id].octave_delay + 0.05, -- Slight sustain
                note = event.note - 12
              })
            end
            
            active_harmonics[note_id] = nil
          end
        end
      end
      
      table.sort(result, function(a, b) return a.time < b.time end)
      return result
    end
  },
  
  transpose = {
    name = "Transpose",
    ui_name = "Transpose",
    ui_order = 4,
    description = "Shift all notes up or down by a number of semitones",
    params = {
      amount = {
        type = "integer",  -- Explicitly specify parameter type
        default = 0,
        min = -24,
        max = 24,
        step = 1  -- Optional: specify custom step size if needed
      }
    },
    fn = function(events, params)
      local amount = params.amount or 0
      local result = {}
      
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        
        -- Only modify pitch for note events
        if event.type == "note_on" or event.type == "note_off" then
          new_event.note = event.note + amount
        end
        
        table.insert(result, new_event)
      end
      
      return result
    end
  },
  
  rotate = {
    name = "Rotate",
    ui_name = "Rotate",
    ui_order = 5,
    description = "Rotate the order of notes while preserving their relative timing",
    params = {
      amount = {
        type = "integer",
        default = 1,
        min = -12,
        max = 12,
        step = 1
      }
    },
    fn = function(events, params)
      local amount = params.amount or 1
      
      -- Collect just the note events
      local notes = {}
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          table.insert(notes, event.note)
        end
      end
      
      -- Calculate rotation (handle wraparound)
      local note_count = #notes
      if note_count == 0 then return events end
      
      amount = amount % note_count
      if amount < 0 then
        amount = note_count + amount
      end
      
      -- Create lookup table for rotated notes
      local note_map = {}
      for i, note in ipairs(notes) do
        local new_pos = ((i - 1 + amount) % note_count) + 1
        note_map[note] = notes[new_pos]
      end
      
      -- Apply rotation to events
      local result = {}
      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end
        
        if event.type == "note_on" or event.type == "note_off" then
          new_event.note = note_map[event.note]
        end
        
        table.insert(result, new_event)
      end
      
      return result
    end
  },
  
  reverse = {
    name = "Reverse",
    ui_name = "Reverse",
    ui_order = 6,
    description = "Reverse the order of notes in time while preserving note durations",
    params = {},
    fn = function(events, params)
      -- First pass: collect note_on/note_off pairs and their durations
      local notes = {}
      local total_duration = 0
      
      for i, event in ipairs(events) do
        if event.type == "note_on" then
          notes[#notes + 1] = {
            note = event.note,
            velocity = event.velocity,
            start_time = event.time,
            duration = nil -- Will be filled when we find note_off
          }
        elseif event.type == "note_off" then
          -- Find matching note_on
          for _, note in ipairs(notes) do
            if note.note == event.note and note.duration == nil then
              note.duration = event.time - note.start_time
              break
            end
          end
        end
        -- Track total duration for any non-note events
        if event.time > total_duration then
          total_duration = event.time
        end
      end
      
      -- Second pass: create reversed events
      local result = {}
      for i = #notes, 1, -1 do
        local note = notes[i]
        local new_start = total_duration - (note.start_time + note.duration)
        
        -- Add note_on
        table.insert(result, {
          type = "note_on",
          time = new_start,
          note = note.note,
          velocity = note.velocity
        })
        
        -- Add note_off
        table.insert(result, {
          type = "note_off",
          time = new_start + note.duration,
          note = note.note
        })
      end
      
      -- Add any non-note events at their relative positions
      for _, event in ipairs(events) do
        if event.type ~= "note_on" and event.type ~= "note_off" then
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          new_event.time = total_duration - event.time
          table.insert(result, new_event)
        end
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
      return result
    end
  },

  skip = {
    name = "Skip",
    ui_name = "Ratchet",
    ui_order = 7,
    description = "Play every Nth note, skipping the ones in between",
    params = {
      n = {
        type = "integer",
        default = 2,
        min = 1,
        max = 16,
        step = 1
      },
      offset = {
        type = "integer",
        default = 0,
        min = 0,
        max = 15,
        step = 1
      }
    },
    fn = function(events, params)
      local n = params.n or 2
      local offset = params.offset or 0
      
      -- First collect note_on events to determine which notes to keep
      local notes_to_keep = {}
      local note_index = 0
      
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          if (note_index + offset) % n == 0 then
            notes_to_keep[event.note] = true
          end
          note_index = note_index + 1
        end
      end
      
      -- Create new sequence keeping only the selected notes
      local result = {}
      for _, event in ipairs(events) do
        if event.type == "note_on" or event.type == "note_off" then
          if notes_to_keep[event.note] then
            local new_event = {}
            for k, v in pairs(event) do
              new_event[k] = v
            end
            table.insert(result, new_event)
          end
        else
          -- Keep non-note events
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          table.insert(result, new_event)
        end
      end
      
      return result
    end
  }
}

-- Function to build the ordered list of transform UI names
function transforms.build_ui_names()
  -- Collect all transforms with their ui_order
  local ordered_transforms = {}
  for id, transform in pairs(transforms.available) do
    table.insert(ordered_transforms, {
      id = id,
      ui_name = transform.ui_name,
      ui_order = transform.ui_order or 99  -- Default to end if no order specified
    })
  end
  
  -- Sort by ui_order
  table.sort(ordered_transforms, function(a, b) 
    return a.ui_order < b.ui_order
  end)
  
  -- Extract just the UI names in order
  local ui_names = {}
  for _, transform in ipairs(ordered_transforms) do
    table.insert(ui_names, transform.ui_name)
  end
  
  return ui_names
end

-- Build the list of transform UI names
transforms.ui_names = transforms.build_ui_names()

-- Lookup function to find transform ID by UI name
function transforms.get_transform_id_by_ui_name(ui_name)
  for id, transform in pairs(transforms.available) do
    if transform.ui_name == ui_name then
      return id
    end
  end
  return "noop"  -- Default to noop if not found
end

return transforms 

-- Future Transforms:
-- 1. Simultaneously plays a transposed version of the motif. Only plays a subset of the notes. Contiguous, not random.

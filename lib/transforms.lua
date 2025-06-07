-- transforms.lua
-- Changes motifs on a schedule. Repository for all transforms. Called by @stage_config.lua. Params created there, too.

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

transforms.available = {
  none = {
    name = "No Operation",
    ui_name = "None",
    ui_order = 1,
    description = "Returns the exact same sequence with no changes",
    fn = function(events, lane_id, stage_id)
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
    fn = function(events, lane_id, stage_id)
      local mode = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_overdub_filter_mode")
      local target_generation = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_overdub_filter_round")
      
      print("overdub filter")
      -- Find the maximum generations in the events
      local max_generation = 1
      for _, event in ipairs(events) do
        local generation = event.generation or 1
        if generation > max_generation then
          max_generation = generation
        end
      end
      
      -- Clamp the target generation to the maximum found
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
    description = "Adds subtle harmonic overtones",
    fn = function(events, lane_id, stage_id)
      -- Read params directly inside the transform
      local sub_octave_chance = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_sub_octave_chance") / 100
      local sub_octave_volume = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_sub_octave_volume") / 100
      local fifth_chance = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_fifth_above_chance") / 100
      local fifth_volume = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_fifth_above_volume") / 100
      local octave_chance = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_octave_above_chance") / 100
      local octave_volume = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_octave_above_volume") / 100
      
      -- Built-in humanization constants
      local TIMING_VARIATION = 0.015  -- 15ms maximum timing variation
      local FIFTH_VELOCITY_VARIATION = 0.1   -- ±10% velocity variation for fifth
      local OCTAVE_VELOCITY_VARIATION = 0.15 -- ±15% velocity variation for octave
      local SUB_OCTAVE_VELOCITY_VARIATION = 0.2 -- ±20% velocity variation for sub-octave
      
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
            has_sub_octave = math.random() < sub_octave_chance,
            has_fifth = math.random() < fifth_chance,
            has_octave = math.random() < octave_chance,
            sub_octave_delay = humanize_value(0, TIMING_VARIATION),
            fifth_delay = humanize_value(0, TIMING_VARIATION),
            octave_delay = humanize_value(0, TIMING_VARIATION)
          }
          
          -- Add sub-octave harmonic (one octave below)
          if active_harmonics[note_id].has_sub_octave then
            local sub_octave_velocity = math.floor(
              event.velocity * 
              humanize_value(sub_octave_volume, SUB_OCTAVE_VELOCITY_VARIATION)
            )
            
            table.insert(result, {
              type = "note_on",
              time = event.time + active_harmonics[note_id].sub_octave_delay,
              note = event.note - 12, -- One octave below
              velocity = sub_octave_velocity
            })
          end
          
          -- Add perfect fifth above
          if active_harmonics[note_id].has_fifth then
            local fifth_velocity = math.floor(
              event.velocity * 
              humanize_value(fifth_volume, FIFTH_VELOCITY_VARIATION)
            )
            
            table.insert(result, {
              type = "note_on",
              time = event.time + active_harmonics[note_id].fifth_delay,
              note = event.note + 7, -- Perfect fifth above
              velocity = fifth_velocity
            })
          end
          
          -- Add octave above
          if active_harmonics[note_id].has_octave then
            local octave_velocity = math.floor(
              event.velocity * 
              humanize_value(octave_volume, OCTAVE_VELOCITY_VARIATION)
            )
            
            table.insert(result, {
              type = "note_on",
              time = event.time + active_harmonics[note_id].octave_delay,
              note = event.note + 12, -- One octave above
              velocity = octave_velocity
            })
          end
        end
        
        if event.type == "note_off" then
          local note_id = event.note
          
          if active_harmonics[note_id] then
            -- Add sub-octave note_off
            if active_harmonics[note_id].has_sub_octave then
              table.insert(result, {
                type = "note_off",
                time = event.time + active_harmonics[note_id].sub_octave_delay,
                note = event.note - 12
              })
            end
            
            -- Add fifth note_off
            if active_harmonics[note_id].has_fifth then
              table.insert(result, {
                type = "note_off",
                time = event.time + active_harmonics[note_id].fifth_delay + 0.05, -- Slight sustain
                note = event.note + 7
              })
            end
            
            -- Add octave note_off
            if active_harmonics[note_id].has_octave then
              table.insert(result, {
                type = "note_off",
                time = event.time + active_harmonics[note_id].octave_delay,
                note = event.note + 12
              })
            end
            
            -- Clean up tracking
            active_harmonics[note_id] = nil
          end
        end
      end
      
      -- Sort by time to maintain proper event ordering
      table.sort(result, function(a, b) return a.time < b.time end)
      
      return result
    end
  },
  
  transpose = {
    name = "Transpose",
    ui_name = "Transpose",
    ui_order = 4,
    description = "Shift all notes up or down by a number of semitones",
    fn = function(events, lane_id, stage_id)
      local amount = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_transpose_amount")
      
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
    fn = function(events, lane_id, stage_id)
      local amount = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_rotate_amount")
      
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
    fn = function(events, lane_id, stage_id)
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
    ui_name = "Skip",
    ui_order = 7,
    description = "Play every Nth note, skipping the ones in between",
    fn = function(events, lane_id, stage_id)
      local n = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_skip_interval")
      local offset = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_skip_offset")
      
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
  },

  ratchet = {
    name = "Ratchet", 
    ui_name = "Ratchet", 
    ui_order = 8,
    description = "Repeat notes with probability and timing variations",
    fn = function(events, lane_id, stage_id)
      local repeat_chance = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_ratchet_chance") / 100
      local max_repeats = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_ratchet_max_repeats")
      local timing_division_string = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_ratchet_timing")
      
      -- Helper function to convert division string to beats (same as eurorack_output.lua)
      local function division_to_beats(div)
        -- Handle integer values (1, 2, 3, etc)
        if tonumber(div) then
          return tonumber(div)
        end
        
        -- Handle fraction values (1/4, 1/16, etc)
        local num, den = div:match("(%d+)/(%d+)")
        if num and den then
          return tonumber(num)/tonumber(den)
        end
        
        return 0.25 -- default to 1/4 note
      end
      
      local timing_division_beats = division_to_beats(timing_division_string)
      
      local result = {}
      local note_pairs = {}
      local note_counter = {}  -- Track multiple instances of same note
      
      -- First pass: collect note_on/note_off pairs with unique IDs
      for _, event in ipairs(events) do
        if event.type == "note_on" then
          -- Create unique ID for each note occurrence
          note_counter[event.note] = (note_counter[event.note] or 0) + 1
          local unique_id = event.note .. "_" .. note_counter[event.note]
          
          note_pairs[unique_id] = {
            note_on = event,
            note_off = nil,
            duration = nil,
            note = event.note,
            instance = note_counter[event.note]
          }
        elseif event.type == "note_off" then
          -- Find the most recent unmatched note_on for this note
          local matched_id = nil
          local highest_instance = 0
          
          for id, pair in pairs(note_pairs) do
            if pair.note == event.note and pair.note_off == nil and pair.instance > highest_instance then
              matched_id = id
              highest_instance = pair.instance
            end
          end
          
          if matched_id then
            note_pairs[matched_id].note_off = event
            note_pairs[matched_id].duration = event.time - note_pairs[matched_id].note_on.time
          end
        end
      end
      
      -- Second pass: create ratcheted events
      for unique_id, pair in pairs(note_pairs) do
        local original_note_on = pair.note_on
        local original_note_off = pair.note_off
        local duration = pair.duration or 0.1 -- Default duration if no note_off found
        
        -- Decide if this note gets ratcheted
        if math.random() < repeat_chance then
          local num_repeats = math.random(1, max_repeats)
          
          -- Use burst-style timing like eurorack_output.lua
          -- timing_division_beats now represents the time window for the entire ratchet burst
          local ratchet_window = timing_division_beats -- Time window for all ratchets
          local ratchet_interval = ratchet_window / num_repeats -- Time between each ratchet
          
          for i = 0, num_repeats - 1 do
            local repeat_time = original_note_on.time + (i * ratchet_interval)
            local repeat_velocity = math.floor(original_note_on.velocity * (1 - i * 0.1)) -- Decay velocity
            
            -- Add note_on with all original fields preserved
            local new_note_on = {}
            for k, v in pairs(original_note_on) do
              new_note_on[k] = v
            end
            new_note_on.time = repeat_time
            new_note_on.velocity = math.max(repeat_velocity, 20) -- Minimum velocity
            table.insert(result, new_note_on)
            
            -- Add note_off with all original fields preserved
            local new_note_off = {}
            if original_note_off then
              for k, v in pairs(original_note_off) do
                new_note_off[k] = v
              end
            else
              -- Create note_off from note_on if none existed
              for k, v in pairs(original_note_on) do
                new_note_off[k] = v
              end
              new_note_off.type = "note_off"
              new_note_off.velocity = nil -- note_off doesn't have velocity
            end
            -- Use a shorter, fixed duration for ratchets based on interval
            new_note_off.time = repeat_time + (ratchet_interval * 0.8) -- 80% of interval
            table.insert(result, new_note_off)
          end
        else
          -- Keep original note unchanged with all fields preserved
          local new_note_on = {}
          for k, v in pairs(original_note_on) do
            new_note_on[k] = v
          end
          table.insert(result, new_note_on)
          
          if original_note_off then
            local new_note_off = {}
            for k, v in pairs(original_note_off) do
              new_note_off[k] = v
            end
            table.insert(result, new_note_off)
          end
        end
      end
      
      -- Add any non-note events with all fields preserved
      for _, event in ipairs(events) do
        if event.type ~= "note_on" and event.type ~= "note_off" then
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          table.insert(result, new_event)
        end
      end
      
      -- Sort by time
      table.sort(result, function(a, b) return a.time < b.time end)
      
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
  return "none"  -- Default to none if not found
end

return transforms 

-- Future Transforms:
-- 1. Simultaneously plays a transposed version of the motif. Only plays a subset of the notes. Contiguous, not random.

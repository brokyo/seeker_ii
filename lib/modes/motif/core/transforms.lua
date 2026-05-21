-- tape_transforms.lua
-- Tape mode transforms (time-based event modifications)
-- Called by Lane:prepare_stage() for tape mode stages

local musicutil = require('musicutil')
local theory = include('lib/modes/motif/core/theory')
local Extend = include('lib/modes/motif/core/extend')

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

transforms.available = {
  none = {
    name = "No Operation",
    ui_name = "None",
    ui_order = 1,
    description = "Pass-through with no changes.\n\nThe motif plays exactly as recorded. Use this for stages that should play the original sequence.",
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
  
  extend = {
    name = "Extend",
    ui_name = "Extend",
    ui_order = 3,
    description = "Factor oracle continuation.\n\nLearns beat-level patterns from the motif and generates new material by recombining real fragments. Every output fragment existed in the original — the ordering is new.\n\nFidelity: How much it recombines vs replays.\nEntropy: How much notes drift over time.\nMutate Cycle: How quickly entropy breathes in and out (0 = off).",
    fn = function(events, lane_id, stage_id)
      local prefix = "lane_" .. lane_id .. "_stage_" .. stage_id
      local fidelity = params:get(prefix .. "_extend_fidelity") / 100
      local entropy = params:get(prefix .. "_extend_entropy") / 100
      local reseed = params:get(prefix .. "_extend_reseed")

      local lane = _seeker.lanes[lane_id]
      local duration = lane.motif:get_duration()

      local slice_data = Extend.slice_events(events, duration)
      if #slice_data.slices < 2 then return events end
      local context = Extend.build_oracle(slice_data)

      local num_beats = math.floor(duration)
      local gen_events, gen_duration = Extend.generate(context, num_beats, fidelity, {})

      if entropy > 0 and reseed > 0 then
        local stage = lane.stages[lane.current_stage_index]
        local loop_count = stage and stage.current_loop or 0
        local depth = Extend.triangle_depth(loop_count, reseed)
        if depth > 0 then
          local scale = theory.get_scale()
          Extend.mutate_events(gen_events, depth, {
            pitch = entropy * 100,
            density = entropy * 50,
            displace = entropy * 30,
          }, scale)
        end
      end

      return gen_events
    end
  },

  overdub_filter = {
    name = "Overdub Filter",
    ui_name = "Overdub Filter",
    ui_order = 2,
    description = "Filter notes by recording layer.\n\nUp To: Play layers 1 through N.\nOnly: Play just layer N.\nExcept: Play all except layer N.\n\nGreat for gradually revealing or hiding overdubbed parts.",
    fn = function(events, lane_id, stage_id)
      local mode = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_overdub_filter_mode")
      local target_generation = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_overdub_filter_round")

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
    ui_order = 4,
    description = "Layer harmonic intervals over notes.\n\nSub Octave: One octave below.\nFifth Above: Perfect fifth.\nOctave Above: One octave up.\n\nEach has independent chance and volume. Timing and velocity are subtly humanized.",
    fn = function(events, lane_id, stage_id)
      -- Helper function to convert option to chance percentage
      local function option_to_chance(option_value)
        local chance_map = {0.0, 0.25, 0.50, 0.75, 1.0} -- Off, Low, Medium, High, Always
        return chance_map[option_value]
      end

      -- Read params directly inside the transform
      local sub_octave_chance = option_to_chance(params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_sub_octave_chance"))
      local sub_octave_volume = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_sub_octave_volume") / 100
      local fifth_chance = option_to_chance(params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_fifth_above_chance"))
      local fifth_volume = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_fifth_above_volume") / 100
      local octave_chance = option_to_chance(params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_harmonize_octave_above_chance"))
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

      -- First pass: collect note_on/note_off pairs to determine harmonic structure
      local note_pairs = {}
      local note_counter = {}

      for _, event in ipairs(events) do
        if event.type == "note_on" then
          -- Create unique ID for each note occurrence
          note_counter[event.note] = (note_counter[event.note] or 0) + 1
          local unique_id = event.note .. "_" .. note_counter[event.note]

          note_pairs[unique_id] = {
            note_on = event,
            note_off = nil,
            note = event.note,
            instance = note_counter[event.note],
            harmonics = {
              has_sub_octave = math.random() < sub_octave_chance,
              has_fifth = math.random() < fifth_chance,
              has_octave = math.random() < octave_chance,
              sub_octave_delay = humanize_value(0, TIMING_VARIATION),
              fifth_delay = humanize_value(0, TIMING_VARIATION),
              octave_delay = humanize_value(0, TIMING_VARIATION)
            }
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
          end
        end
      end

      -- Second pass: generate harmonized events
      local result = {}

      for _, pair in pairs(note_pairs) do
        local original_note_on = pair.note_on
        local original_note_off = pair.note_off
        local harmonics = pair.harmonics

        -- Add original note_on
        local original_note_on_copy = {}
        for k, v in pairs(original_note_on) do
          original_note_on_copy[k] = v
        end
        table.insert(result, original_note_on_copy)

        -- Add harmonic note_ons
        if harmonics.has_sub_octave then
          local sub_octave_velocity = math.floor(
            original_note_on.velocity *
            humanize_value(sub_octave_volume, SUB_OCTAVE_VELOCITY_VARIATION)
          )

          -- Exclude generation to prevent recursive harmonization
          local sub_octave_on = {}
          for k, v in pairs(original_note_on) do
            if k ~= "generation" then
              sub_octave_on[k] = v
            end
          end
          sub_octave_on.time = original_note_on.time + harmonics.sub_octave_delay
          sub_octave_on.note = original_note_on.note - 12
          sub_octave_on.velocity = sub_octave_velocity
          table.insert(result, sub_octave_on)
        end

        if harmonics.has_fifth then
          local fifth_velocity = math.floor(
            original_note_on.velocity *
            humanize_value(fifth_volume, FIFTH_VELOCITY_VARIATION)
          )

          -- Exclude generation to prevent recursive harmonization
          local fifth_on = {}
          for k, v in pairs(original_note_on) do
            if k ~= "generation" then
              fifth_on[k] = v
            end
          end
          fifth_on.time = original_note_on.time + harmonics.fifth_delay
          fifth_on.note = original_note_on.note + 7
          fifth_on.velocity = fifth_velocity
          table.insert(result, fifth_on)
        end

        if harmonics.has_octave then
          local octave_velocity = math.floor(
            original_note_on.velocity *
            humanize_value(octave_volume, OCTAVE_VELOCITY_VARIATION)
          )

          -- Exclude generation to prevent recursive harmonization
          local octave_on = {}
          for k, v in pairs(original_note_on) do
            if k ~= "generation" then
              octave_on[k] = v
            end
          end
          octave_on.time = original_note_on.time + harmonics.octave_delay
          octave_on.note = original_note_on.note + 12
          octave_on.velocity = octave_velocity
          table.insert(result, octave_on)
        end

        -- Add original note_off if it exists
        if original_note_off then
          local original_note_off_copy = {}
          for k, v in pairs(original_note_off) do
            original_note_off_copy[k] = v
          end
          table.insert(result, original_note_off_copy)

          -- Add harmonic note_offs
          if harmonics.has_sub_octave then
            -- Exclude generation to prevent recursive harmonization
            local sub_octave_off = {}
            for k, v in pairs(original_note_off) do
              if k ~= "generation" then
                sub_octave_off[k] = v
              end
            end
            sub_octave_off.time = original_note_off.time + harmonics.sub_octave_delay
            sub_octave_off.note = original_note_on.note - 12
            table.insert(result, sub_octave_off)
          end

          if harmonics.has_fifth then
            -- Exclude generation to prevent recursive harmonization
            local fifth_off = {}
            for k, v in pairs(original_note_off) do
              if k ~= "generation" then
                fifth_off[k] = v
              end
            end
            fifth_off.time = original_note_off.time + harmonics.fifth_delay + 0.05 -- Fifth sustains 50ms longer
            fifth_off.note = original_note_on.note + 7
            table.insert(result, fifth_off)
          end

          if harmonics.has_octave then
            -- Exclude generation to prevent recursive harmonization
            local octave_off = {}
            for k, v in pairs(original_note_off) do
              if k ~= "generation" then
                octave_off[k] = v
              end
            end
            octave_off.time = original_note_off.time + harmonics.octave_delay
            octave_off.note = original_note_on.note + 12
            table.insert(result, octave_off)
          end
        end
      end

      -- Add any non-note events
      for _, event in ipairs(events) do
        if event.type ~= "note_on" and event.type ~= "note_off" then
          local new_event = {}
          for k, v in pairs(event) do
            new_event[k] = v
          end
          table.insert(result, new_event)
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
    ui_order = 5,
    description = "Shift all notes by scale degrees.\n\nPositive values move up the scale, negative down. Notes stay in key. +1 = next scale note, +7 = one octave up in a 7-note scale.\n\nUse across stages for chord progressions or melodic variation.",
    fn = function(events, lane_id, stage_id)
      local amount = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_transpose_amount")

      local result = {}

      for _, event in ipairs(events) do
        local new_event = {}
        for k, v in pairs(event) do
          new_event[k] = v
        end

        -- Transpose note events by scale degrees
        if event.type == "note_on" or event.type == "note_off" then
          new_event.note = theory.transpose_by_scale_degrees(event.note, amount)
        end

        table.insert(result, new_event)
      end

      return result
    end
  },
  
  hosono = {
    name = "Hosono",
    ui_name = "Hosono",
    ui_order = 6,
    description = "Generative gap material.\n\nDiscards the recorded motif and generates sparse, scale-locked notes from scratch. Different each time the stage plays.\n\nDensity: How many notes per beat.\nRange: Octave spread around the root.\nGate: Note length.\nVelocity: Dynamic range of generated notes.",
    fn = function(events, lane_id, stage_id)
      local prefix = "lane_" .. lane_id .. "_stage_" .. stage_id
      local density = params:get(prefix .. "_hosono_density") / 100
      local range_octaves = params:get(prefix .. "_hosono_range")
      local vel_min = params:get(prefix .. "_hosono_vel_min")
      local vel_max = params:get(prefix .. "_hosono_vel_max")
      local gate_pct = params:get(prefix .. "_hosono_gate") / 100
      local division_idx = params:get(prefix .. "_hosono_division")
      local division_values = {0.0625, 0.125, 0.25, 0.5, 1}
      local division = division_values[division_idx] or 0.125

      local scale = theory.get_scale()
      local root = params:get("root_note") - 1
      local base_octave = 4
      local center = root + (base_octave * 12)
      local half_range = range_octaves * 12

      local note_pool = {}
      for _, n in ipairs(scale) do
        if n >= center - half_range and n <= center + half_range then
          table.insert(note_pool, n)
        end
      end
      if #note_pool == 0 then return {} end

      local lane = _seeker.lanes[lane_id]
      local duration = lane and lane.motif and lane.motif:get_duration() or 4
      local result = {}
      local time = 0

      while time < duration do
        if math.random() < density then
          local note = note_pool[math.random(#note_pool)]
          local velocity = math.random(vel_min, vel_max)
          local gate_time = division * gate_pct

          table.insert(result, {
            type = "note_on",
            time = time,
            note = note,
            velocity = velocity,
            is_playback = false,
          })
          table.insert(result, {
            type = "note_off",
            time = time + gate_time,
            note = note,
          })
        end
        time = time + division
      end

      return result
    end
  },

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

-- Get transform description by UI index (1-based param value)
function transforms.get_description_by_ui_index(ui_index)
  local ui_name = transforms.ui_names[ui_index]
  if not ui_name then return nil end
  local id = transforms.get_transform_id_by_ui_name(ui_name)
  return transforms.available[id] and transforms.available[id].description
end

return transforms

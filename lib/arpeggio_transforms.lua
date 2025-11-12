-- arpeggio_transforms.lua
-- Transforms for arpeggio mode (step-based sequencer)
-- Applies scale-relative harmony and rhythmic variations to step sequences

local arpeggio_utils = include("lib/arpeggio_utils")
local musicutil = require('musicutil')

local arpeggio_transforms = {}

-- Apply arpeggio variations to events
-- Reads stage-specific parameters for scale degree, pattern, direction, inversion
function arpeggio_transforms.apply(events, lane_id, stage_id)
  -- Read stage-specific arpeggio parameters
  local scale_degree = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_scale_degree")
  local pattern_preset = params:string("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_pattern")
  local direction = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_direction")
  local inversion = params:get("lane_" .. lane_id .. "_stage_" .. stage_id .. "_arpeggio_inversion")

  -- Get global scale settings
  local scale_type_index = params:get("scale_type")
  local scale_type_name = musicutil.SCALES[scale_type_index].name
  local root_note = params:get("root_note")

  -- Calculate semitone offset for scale degree
  local semitone_offset = arpeggio_utils.scale_degree_to_semitones(scale_degree, scale_type_name, root_note)

  -- First pass: Apply transposition and inversion
  local transposed_events = {}
  for _, event in ipairs(events) do
    local new_event = {}
    for k, v in pairs(event) do
      new_event[k] = v
    end

    -- Apply to note events
    if event.type == "note_on" or event.type == "note_off" then
      new_event.note = event.note + semitone_offset + inversion
    end

    table.insert(transposed_events, new_event)
  end

  -- Second pass: Apply pattern preset filter
  -- Note: This requires events to have 'step' field from recording
  local num_steps = 0
  for _, event in ipairs(transposed_events) do
    if event.step and event.step > num_steps then
      num_steps = event.step
    end
  end

  local filtered_events = transposed_events
  if num_steps > 0 and pattern_preset then
    filtered_events = arpeggio_utils.apply_pattern_preset(transposed_events, pattern_preset, num_steps)
  end

  -- Third pass: Apply direction (reorder events)
  if direction == 2 then
    -- Down: Reverse event order
    filtered_events = reverse_events_order(filtered_events)
  elseif direction == 3 then
    -- Up-Down: Palindrome
    filtered_events = create_palindrome(filtered_events, false)
  elseif direction == 4 then
    -- Down-Up: Reverse palindrome
    filtered_events = create_palindrome(filtered_events, true)
  elseif direction == 5 then
    -- Random: Shuffle
    filtered_events = shuffle_events(filtered_events)
  end
  -- direction == 1 (Up) is default, no change needed

  return filtered_events
end

-- Helper functions for direction changes

function reverse_events_order(events)
  local pairs = group_note_pairs(events)

  local reversed_pairs = {}
  for i = #pairs, 1, -1 do
    table.insert(reversed_pairs, pairs[i])
  end

  return rebuild_events_from_pairs(reversed_pairs)
end

function create_palindrome(events, reverse_first)
  local pairs = group_note_pairs(events)

  if reverse_first then
    local reversed = {}
    for i = #pairs, 1, -1 do
      table.insert(reversed, pairs[i])
    end
    pairs = reversed
  end

  -- Create palindrome (go up then down, skip duplicating first/last)
  local palindrome = {}
  for i = 1, #pairs do
    table.insert(palindrome, pairs[i])
  end
  for i = #pairs - 1, 2, -1 do
    table.insert(palindrome, pairs[i])
  end

  return rebuild_events_from_pairs(palindrome)
end

function shuffle_events(events)
  local pairs = group_note_pairs(events)

  -- Fisher-Yates shuffle
  for i = #pairs, 2, -1 do
    local j = math.random(i)
    pairs[i], pairs[j] = pairs[j], pairs[i]
  end

  return rebuild_events_from_pairs(pairs)
end

function group_note_pairs(events)
  local pairs = {}
  local note_counter = {}
  local pending_pairs = {}

  for _, event in ipairs(events) do
    if event.type == "note_on" then
      note_counter[event.note] = (note_counter[event.note] or 0) + 1
      local unique_id = event.note .. "_" .. note_counter[event.note]

      pending_pairs[unique_id] = {
        note_on = event,
        note_off = nil,
        note = event.note,
        instance = note_counter[event.note],
        original_time = event.time,
        duration = nil
      }
    elseif event.type == "note_off" then
      -- Find matching note_on
      local matched_id = nil
      local highest_instance = 0

      for id, pair in pairs(pending_pairs) do
        if pair.note == event.note and pair.note_off == nil and pair.instance > highest_instance then
          matched_id = id
          highest_instance = pair.instance
        end
      end

      if matched_id then
        pending_pairs[matched_id].note_off = event
        pending_pairs[matched_id].duration = event.time - pending_pairs[matched_id].note_on.time
        table.insert(pairs, pending_pairs[matched_id])
        pending_pairs[matched_id] = nil
      end
    end
  end

  -- Add any unpaired note_ons
  for _, pair in pairs(pending_pairs) do
    pair.duration = 0.1  -- Default duration
    table.insert(pairs, pair)
  end

  -- Sort by original time
  table.sort(pairs, function(a, b) return a.original_time < b.original_time end)

  return pairs
end

function rebuild_events_from_pairs(pairs)
  local result = {}
  local current_time = 0

  for _, pair in ipairs(pairs) do
    local note_on = pair.note_on
    local note_off = pair.note_off
    local duration = pair.duration or 0.1

    -- Calculate new timing (preserve inter-onset intervals)
    local inter_onset = pair.note_on.time - (pairs[_ - 1] and pairs[_ - 1].note_on.time or 0)
    if _ > 1 then
      current_time = current_time + inter_onset
    end

    -- Add note_on
    local new_note_on = {}
    for k, v in pairs(note_on) do
      new_note_on[k] = v
    end
    new_note_on.time = current_time
    table.insert(result, new_note_on)

    -- Add note_off
    if note_off then
      local new_note_off = {}
      for k, v in pairs(note_off) do
        new_note_off[k] = v
      end
      new_note_off.time = current_time + duration
      table.insert(result, new_note_off)
    end
  end

  -- Sort by time
  table.sort(result, function(a, b) return a.time < b.time end)

  return result
end

return arpeggio_transforms

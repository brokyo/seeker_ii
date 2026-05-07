-- lane_handlers.lua
-- Registry for mode-specific lane behavior.
-- Each motif type (Tape, Composer, Sampler, Form) registers a handler table
-- that lane.lua dispatches to during playback.
--
-- Handler callbacks (all optional):
--   prepare_stage(lane, stage)           — Transform/generate events for stage
--   on_stage_start(lane, stage_index, start_time) — Visual feedback on stage transition
--   is_muted(lane_id)                    — Performance mute check
--   get_velocity_multiplier(lane_id)     — Performance velocity scaling
--   note_positions(lane, note, event)    — Grid positions for a note (multi-position lookup)
--   get_active_positions(lane)           — Active note visualization positions
--   note_key(note, event)               — Key for active_notes table (step-based vs note-based)
--   trail_mode                           — "fade" (default) or "immediate"

local lane_handlers = {}

local handlers = {}

function lane_handlers.register(motif_type, handler_table)
  handlers[motif_type] = handler_table
end

function lane_handlers.get(motif_type)
  return handlers[motif_type]
end

-- Shared utility: pre-quantize events before transforms run.
-- Applies quantization and swing to note times, preserving note durations.
-- Used by Tape and Sampler prepare_stage handlers.
function lane_handlers.pre_quantize_events(events, lane_id)
  local quantize_option = params:get("lane_" .. lane_id .. "_quantize")
  local quantize_values = {0, 1/8, 1/4, 1/2, 1}
  local quantize_interval = quantize_values[quantize_option]

  if quantize_interval <= 0 then
    return
  end

  local swing_amount = params:get("lane_" .. lane_id .. "_swing") / 100

  local note_trigger_counts = {}
  local note_timing_offsets = {}

  -- First pass: calculate offsets for note_on events
  for _, event in ipairs(events) do
    if event.type == "note_on" then
      note_trigger_counts[event.note] = (note_trigger_counts[event.note] or 0) + 1
      local note_instance_id = event.note .. "_" .. note_trigger_counts[event.note]

      local original_time = event.time
      local quantized_time = math.floor(original_time / quantize_interval + 0.5) * quantize_interval
      local total_offset = quantized_time - original_time

      -- Apply swing to even subdivisions
      if swing_amount > 0 then
        local subdivision_position = quantized_time / quantize_interval
        local subdivision_index = math.floor(subdivision_position + 0.5)

        if subdivision_index % 2 == 0 then
          local swing_offset = quantize_interval * swing_amount * 0.5
          quantized_time = quantized_time + swing_offset
          total_offset = total_offset + swing_offset
        end
      end

      event.time = quantized_time
      note_timing_offsets[note_instance_id] = total_offset
    end
  end

  -- Reset counter for note_off pass
  note_trigger_counts = {}

  -- Second pass: apply same offsets to note_off events
  for _, event in ipairs(events) do
    if event.type == "note_off" then
      note_trigger_counts[event.note] = (note_trigger_counts[event.note] or 0) + 1
      local note_instance_id = event.note .. "_" .. note_trigger_counts[event.note]
      local offset = note_timing_offsets[note_instance_id] or 0
      event.time = event.time + offset
    end
  end
end

return lane_handlers

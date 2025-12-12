-- transforms.lua
-- Sampler mode transforms (motif event modifications)
-- Called by Lane:prepare_stage() for sampler mode stages
-- Transforms receive events array, modify it, and return it (matching tape pattern)
-- Part of lib/modes/motif/types/sampler/

local transforms = {}

--------------------------------------------------
-- Transform Registry
--------------------------------------------------

transforms.available = {
  none = {
    name = "No Operation",
    ui_name = "None",
    ui_order = 1,
    description = "No changes to events",
    fn = function(events, lane_id, stage_id)
      return events
    end
  },

  scatter = {
    name = "Scatter",
    ui_name = "Scatter",
    ui_order = 2,
    description = "Chaotic micro-loops: amount controls drift, size controls minimum chop length",
    fn = function(events, lane_id, stage_id)
      local scatter_amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_scatter_amount") / 100
      local scatter_size = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_scatter_size") / 100

      if scatter_amount == 0 then return events end
      if not events then return events end

      local sample_duration = _seeker.sampler.get_sample_duration(lane_id)
      if sample_duration <= 0 then return events end

      for _, event in ipairs(events) do
        if event.type == "note_on" and event.start_pos and event.stop_pos then
          local original_duration = event.stop_pos - event.start_pos

          -- Calculate random offset within scatter_amount percentage of chop duration
          local max_offset = original_duration * scatter_amount
          local offset = (math.random() * 2 - 1) * max_offset

          -- New start position, clamped to buffer
          local new_start = math.max(0, math.min(event.start_pos + offset, sample_duration - 0.001))

          -- Scale original duration by scatter_size parameter (0-100%)
          local target_duration = original_duration * scatter_size
          local min_duration = 0.005  -- 5ms floor for audible content
          local new_duration = math.max(min_duration, target_duration)

          -- Calculate stop, ensuring it doesn't exceed buffer
          local new_stop = math.min(new_start + new_duration, sample_duration)

          -- Adjust start position if stop hits buffer boundary
          if new_stop - new_start < min_duration then
            new_start = math.max(0, new_stop - min_duration)
          end

          event.start_pos = new_start
          event.stop_pos = new_stop
        end
      end

      return events
    end
  },

  slide = {
    name = "Slide",
    ui_name = "Slide",
    ui_order = 3,
    description = "Shift chop windows through buffer while preserving duration",
    fn = function(events, lane_id, stage_id)
      local slide_amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_slide_amount") / 100
      local slide_wrap = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_slide_wrap") == 2

      if slide_amount == 0 then return events end
      if not events then return events end

      local sample_duration = _seeker.sampler.get_sample_duration(lane_id)
      if sample_duration <= 0 then return events end

      for _, event in ipairs(events) do
        if event.type == "note_on" and event.start_pos and event.stop_pos then
          local duration = event.stop_pos - event.start_pos

          -- Slide range based on sample duration
          local max_offset = sample_duration * slide_amount
          local offset = (math.random() * 2 - 1) * max_offset

          local new_start = event.start_pos + offset
          local new_stop = new_start + duration

          if slide_wrap then
            -- Wrap around buffer boundaries
            new_start = new_start % sample_duration
            new_stop = new_start + duration
            -- Truncate at buffer end when wrap would exceed duration
            if new_stop > sample_duration then
              new_stop = sample_duration
            end
          else
            -- Clamp to buffer boundaries
            if new_start < 0 then
              new_start = 0
              new_stop = duration
            elseif new_stop > sample_duration then
              new_stop = sample_duration
              new_start = sample_duration - duration
            end
          end

          event.start_pos = new_start
          event.stop_pos = new_stop
        end
      end

      return events
    end
  },

  reverse = {
    name = "Reverse",
    ui_name = "Reverse",
    ui_order = 4,
    description = "Flip playback direction with probability per event",
    fn = function(events, lane_id, stage_id)
      local probability = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_reverse_prob") / 100

      if probability == 0 then return events end
      if not events then return events end

      for _, event in ipairs(events) do
        if event.type == "note_on" and event.rate and math.random() < probability then
          event.rate = -event.rate
        end
      end

      return events
    end
  },

  pan_spread = {
    name = "Pan Spread",
    ui_name = "Pan Spread",
    ui_order = 5,
    description = "Randomly offset pan from recorded value",
    fn = function(events, lane_id, stage_id)
      local probability = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_pan_prob") / 100
      local range = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_pan_range") / 100

      if probability == 0 or range == 0 then return events end
      if not events then return events end

      for _, event in ipairs(events) do
        if event.type == "note_on" and event.pan and math.random() < probability then
          local offset = (math.random() * 2 - 1) * range
          event.pan = util.clamp(event.pan + offset, -1, 1)
        end
      end

      return events
    end
  },

  filter_drift = {
    name = "Filter Drift",
    ui_name = "Filter Drift",
    ui_order = 6,
    description = "Progressively darken or brighten filter across stages",
    fn = function(events, lane_id, stage_id)
      local direction = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_filter_drift_direction")
      local amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_filter_drift_amount") / 100

      if amount == 0 then return events end
      if not events then return events end

      local MIN_LPF = 20
      local MAX_LPF = 20000

      for _, event in ipairs(events) do
        if event.type == "note_on" and event.lpf then
          local current_lpf = event.lpf

          if direction == 1 then
            -- Darken: move toward minimum (multiply to reduce)
            local new_lpf = current_lpf * (1 - amount * 0.5)
            event.lpf = math.max(MIN_LPF, new_lpf)
          else
            -- Brighten: move toward maximum
            local new_lpf = current_lpf + (MAX_LPF - current_lpf) * amount * 0.5
            event.lpf = math.min(MAX_LPF, new_lpf)
          end
        end
      end

      return events
    end
  },

}

-- Build ordered list of transform UI names
function transforms.build_ui_names()
  local ordered_transforms = {}
  for id, transform in pairs(transforms.available) do
    table.insert(ordered_transforms, {
      id = id,
      ui_name = transform.ui_name,
      ui_order = transform.ui_order or 99
    })
  end

  table.sort(ordered_transforms, function(a, b)
    return a.ui_order < b.ui_order
  end)

  local ui_names = {}
  for _, transform in ipairs(ordered_transforms) do
    table.insert(ui_names, transform.ui_name)
  end

  return ui_names
end

transforms.ui_names = transforms.build_ui_names()

-- Lookup function to find transform ID by UI name
function transforms.get_transform_id_by_ui_name(ui_name)
  for id, transform in pairs(transforms.available) do
    if transform.ui_name == ui_name then
      return id
    end
  end
  return "none"
end

return transforms

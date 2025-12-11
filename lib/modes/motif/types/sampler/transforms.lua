-- transforms.lua
-- Sampler mode transforms (chop parameter modifications)
-- Called by Lane:prepare_stage() for sampler mode stages
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
    description = "Returns chops with no changes",
    fn = function(lane_id, stage_id)
      -- No operation - chops remain as they are
      return
    end
  },

  scatter = {
    name = "Scatter",
    ui_name = "Scatter",
    ui_order = 2,
    description = "Chaotic micro-loops: amount controls drift, size controls minimum chop length",
    fn = function(lane_id, stage_id)
      local scatter_amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_scatter_amount") / 100
      local scatter_size = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_scatter_size") / 100

      if scatter_amount == 0 then return end
      if not _seeker.sampler then return end

      local sample_duration = _seeker.sampler.get_sample_duration(lane_id)
      if sample_duration <= 0 then return end

      for pad = 1, 16 do
        local chop = _seeker.sampler.get_chop(lane_id, pad)

        if chop then
          local original_duration = chop.stop_pos - chop.start_pos

          -- Calculate random offset within scatter_amount percentage of chop duration
          local max_offset = original_duration * scatter_amount
          local offset = (math.random() * 2 - 1) * max_offset

          -- New start position, clamped to buffer
          local new_start = math.max(0, math.min(chop.start_pos + offset, sample_duration - 0.001))

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

          _seeker.sampler.update_chop(lane_id, pad, 'start_pos', new_start)
          _seeker.sampler.update_chop(lane_id, pad, 'stop_pos', new_stop)
        end
      end
    end
  },

  slide = {
    name = "Slide",
    ui_name = "Slide",
    ui_order = 3,
    description = "Shift chop windows through buffer while preserving duration",
    fn = function(lane_id, stage_id)
      local slide_amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_slide_amount") / 100
      local slide_wrap = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_slide_wrap") == 2

      if slide_amount == 0 then return end
      if not _seeker.sampler then return end

      local sample_duration = _seeker.sampler.get_sample_duration(lane_id)
      if sample_duration <= 0 then return end

      for pad = 1, 16 do
        local chop = _seeker.sampler.get_chop(lane_id, pad)

        if chop then
          local duration = chop.stop_pos - chop.start_pos

          -- Slide range based on sample duration
          local max_offset = sample_duration * slide_amount
          local offset = (math.random() * 2 - 1) * max_offset

          local new_start = chop.start_pos + offset
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

          _seeker.sampler.update_chop(lane_id, pad, 'start_pos', new_start)
          _seeker.sampler.update_chop(lane_id, pad, 'stop_pos', new_stop)
        end
      end
    end
  },

  reverse = {
    name = "Reverse",
    ui_name = "Reverse",
    ui_order = 4,
    description = "Flip playback direction with probability per pad",
    fn = function(lane_id, stage_id)
      local probability = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_reverse_prob") / 100

      if probability == 0 then return end
      if not _seeker.sampler then return end

      for pad = 1, 16 do
        if math.random() < probability then
          local chop = _seeker.sampler.get_chop(lane_id, pad)
          if chop then
            -- Flip the rate sign
            local new_rate = -chop.rate
            _seeker.sampler.update_chop(lane_id, pad, 'rate', new_rate)
          end
        end
      end
    end
  },

  pan_spread = {
    name = "Pan Spread",
    ui_name = "Pan Spread",
    ui_order = 5,
    description = "Randomly distribute pads across stereo field",
    fn = function(lane_id, stage_id)
      local probability = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_pan_prob") / 100
      local range = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_pan_range") / 100

      if probability == 0 or range == 0 then return end
      if not _seeker.sampler then return end

      for pad = 1, 16 do
        if math.random() < probability then
          local chop = _seeker.sampler.get_chop(lane_id, pad)
          if chop then
            -- Random pan within range (-range to +range)
            local new_pan = (math.random() * 2 - 1) * range
            _seeker.sampler.update_chop(lane_id, pad, 'pan', new_pan)
          end
        end
      end
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

-- Apply transform for a stage (called from Lane:prepare_stage)
function transforms.apply(lane_id, stage_id)
  local transform_ui_name = params:string("lane_" .. lane_id .. "_sampler_transform_stage_" .. stage_id)
  local transform_id = transforms.get_transform_id_by_ui_name(transform_ui_name)

  if transform_id and transform_id ~= "none" then
    local transform = transforms.available[transform_id]
    if transform and transform.fn then
      transform.fn(lane_id, stage_id)
    end
  end
end

-- Reset chops to genesis (called when reset_motif is enabled)
function transforms.reset_to_genesis(lane_id)
  if _seeker.sampler then
    _seeker.sampler.reset_lane_to_genesis(lane_id)
  end
end

return transforms

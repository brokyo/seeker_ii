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
    description = "Randomize chop start positions within a percentage of current values (compounds)",
    fn = function(lane_id, stage_id)
      local scatter_amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_scatter_amount") / 100

      if scatter_amount == 0 then return end
      if not _seeker.sampler then return end

      local sample_duration = _seeker.sampler.get_sample_duration(lane_id)
      if sample_duration <= 0 then return end

      -- Scatter each pad's start position from its current value
      for pad = 1, 16 do
        local chop = _seeker.sampler.get_chop(lane_id, pad)

        if chop then
          -- Calculate scatter range based on current start_pos (compounds across stages)
          local current_start = chop.start_pos
          local max_offset = current_start * scatter_amount

          -- Random offset within range
          local offset = (math.random() * 2 - 1) * max_offset

          -- Apply offset, clamped to valid range
          local new_start = math.max(0, math.min(current_start + offset, sample_duration - 0.01))

          -- Update the working chop
          _seeker.sampler.update_chop(lane_id, pad, 'start_pos', new_start)

          -- Ensure stop_pos stays after start_pos
          if chop.stop_pos <= new_start then
            local new_stop = math.min(new_start + 0.1, sample_duration)
            _seeker.sampler.update_chop(lane_id, pad, 'stop_pos', new_stop)
          end
        end
      end
    end
  },

  reverse = {
    name = "Reverse",
    ui_name = "Reverse",
    ui_order = 3,
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
    ui_order = 4,
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

  filter_sweep = {
    name = "Filter Sweep",
    ui_name = "Filter Sweep",
    ui_order = 5,
    description = "Progressive lowpass filter movement across stages",
    fn = function(lane_id, stage_id)
      local direction = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_filter_direction")
      local amount = params:get("lane_" .. lane_id .. "_sampler_stage_" .. stage_id .. "_filter_amount") / 100

      if amount == 0 then return end
      if not _seeker.sampler then return end

      for pad = 1, 16 do
        local chop = _seeker.sampler.get_chop(lane_id, pad)
        if chop then
          -- Enable lowpass filter if not already set
          if not chop.filter_type or chop.filter_type == 1 then
            _seeker.sampler.update_chop(lane_id, pad, 'filter_type', 2) -- Lowpass
          end

          local current_lpf = chop.lpf or 20000
          local new_lpf

          if direction == 1 then -- Down (close filter)
            -- Multiply by (1 - amount) to reduce
            new_lpf = current_lpf * (1 - amount)
            new_lpf = math.max(100, new_lpf) -- Floor at 100Hz
          else -- Up (open filter)
            -- Multiply by (1 + amount) to increase
            new_lpf = current_lpf * (1 + amount)
            new_lpf = math.min(20000, new_lpf) -- Ceiling at 20kHz
          end

          _seeker.sampler.update_chop(lane_id, pad, 'lpf', new_lpf)
        end
      end
    end
  }
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

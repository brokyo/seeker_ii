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

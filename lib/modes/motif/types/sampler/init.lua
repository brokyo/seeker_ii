-- init.lua
-- Sampler type module entry point
-- Consolidates all sampler components and provides auto-registration

local Sampler = {}

local sampler_transforms = include("lib/modes/motif/types/sampler/transforms")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")

local modules = {
  keyboard = include("lib/modes/motif/types/sampler/keyboard"),
  velocity = include("lib/modes/motif/types/sampler/velocity"),
  stage_nav = include("lib/modes/motif/types/sampler/stage_nav"),
  playback = include("lib/modes/motif/types/sampler/playback"),
  create = include("lib/modes/motif/types/sampler/create"),
  clear = include("lib/modes/motif/types/sampler/clear"),
  perform = include("lib/modes/motif/types/sampler/perform"),
  stage_config = include("lib/modes/motif/types/sampler/stage_config"),
  chop_config = include("lib/modes/motif/types/sampler/chop_config")
}

-- Maps component name to screen section ID
local SECTION_IDS = {
  velocity = "SAMPLER_VELOCITY",
  playback = "SAMPLER_PLAYBACK",
  create = "SAMPLER_CREATE",
  clear = "SAMPLER_CLEAR",
  perform = "SAMPLER_PERFORM",
  stage_config = "SAMPLER_STAGE_CONFIG",
  chop_config = "SAMPLER_CHOP_CONFIG"
}

function Sampler.init()
  local instance = {
    sections = {},
    grids = {}
  }

  for name, module in pairs(modules) do
    instance[name] = module.init()

    -- Auto-build screen sections table
    if instance[name].screen and SECTION_IDS[name] then
      instance.sections[SECTION_IDS[name]] = instance[name].screen
    end

    -- Auto-build grid components table
    if instance[name].grid then
      instance.grids[name] = instance[name].grid
    end
  end

  -- Register lane handler for Sampler (motif_type 3)
  lane_handlers.register(3, {
    prepare_stage = function(lane, stage)
      local reset_motif = params:get("lane_" .. lane.id .. "_stage_" .. stage.id .. "_reset_motif") == 2
      if reset_motif then
        lane.motif:reset_to_genesis()
      end
      lane_handlers.pre_quantize_events(lane.motif.events, lane.id)
      local transform_ui_name = params:string("lane_" .. lane.id .. "_sampler_transform_stage_" .. stage.id)
      local transform_id = sampler_transforms.get_transform_id_by_ui_name(transform_ui_name)
      if transform_id and transform_id ~= "none" then
        local transform = sampler_transforms.available[transform_id]
        lane.motif.events = transform.fn(lane.motif.events, lane.id, stage.id)
      end
    end,

    on_stage_start = function(lane, stage_index, start_time)
      local sc = _seeker.sampler_type and _seeker.sampler_type.stage_config
      if sc and sc.grid then
        _seeker.conductor.insert_event({
          time = start_time,
          lane_id = lane.id,
          callback = function()
            sc.grid:trigger_stage_blink(stage_index)
          end
        })
      end
    end,

    is_muted = function(lane_id)
      local perf = _seeker.sampler_type and _seeker.sampler_type.perform
      return perf and perf.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      local perf = _seeker.sampler_type and _seeker.sampler_type.perform
      return perf and perf.get_velocity_multiplier(lane_id) or 1.0
    end,

    note_positions = function(lane, note, event)
      -- Sampler events carry positions from recording
      return {{x = event.x, y = event.y}}
    end,

    get_active_positions = function(lane)
      local positions = {}
      for _, note in pairs(lane.active_notes) do
        if note.positions then
          for _, pos in ipairs(note.positions) do
            table.insert(positions, {x = pos.x, y = pos.y})
          end
        end
      end
      return positions
    end,

    trail_mode = "fade"
  })

  return instance
end

return Sampler

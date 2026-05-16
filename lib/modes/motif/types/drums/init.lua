-- init.lua
-- Drums type module entry point.
-- 4-lane polymetric step sequencer with per-step note/velocity/ratchet.

local Drums = {}

local DrumsType = include("lib/modes/motif/types/drums/type")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")
local DrumsPerform = include("lib/modes/motif/types/drums/perform")
local LaneMap = include("lib/lanes/lane_map")

local StepGrid = include("lib/modes/motif/types/drums/step_grid")

local modules = {
  home = include("lib/modes/motif/types/drums/home"),
  step_grid = StepGrid,
  perform = include("lib/modes/motif/types/drums/perform"),
}

function Drums.init()
  local instance = {
    sections = {},
    type = DrumsType
  }

  modules.home.set_step_grid_ref(StepGrid)

  for name, module in pairs(modules) do
    instance[name] = module.init()

    if name == "home" and instance[name].sections then
      for section_id, screen in pairs(instance[name].sections) do
        instance.sections[section_id] = screen
      end
    end
  end

  local ROWS_PER_LANE = 2
  local function lane_start_row(lane_id)
    local local_index = lane_id - LaneMap.OFFSETS.drums
    return (local_index - 1) * ROWS_PER_LANE + 1
  end

  lane_handlers.register(2, {
    prepare_stage = function(lane, stage)
      local reseed = params:get("lane_" .. lane.id .. "_drum_reseed")
      if reseed > 0 and stage.current_loop > 0 and stage.current_loop % reseed == 0 then
        StepGrid.apply_pattern(lane.id)
      end
    end,

    is_muted = function(lane_id)
      return DrumsPerform.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      return DrumsPerform.get_velocity_multiplier(lane_id)
    end,

    note_positions = function(lane, note, event)
      if event.step and event.x and event.y then
        return {{x = event.x, y = event.y}}
      end
      local row = lane_start_row(lane.id)
      return {{x = 1, y = row}}
    end,

    get_active_positions = function(lane)
      return {}
    end,

    trail_mode = "immediate"
  })

  return instance
end

return Drums

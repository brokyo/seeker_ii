-- init.lua
-- Drums type module entry point.
-- 4-lane polymetric step sequencer with shape-preserving mutation engine.

local Drums = {}

local DrumsType = include("lib/modes/motif/types/drums/type")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")
local DrumsPerform = include("lib/modes/motif/types/drums/perform")
local LaneMap = include("lib/lanes/lane_map")
local StepGrid = include("lib/modes/motif/types/drums/step_grid")
local theory = include("lib/modes/motif/core/theory")

local modules = {
  home = include("lib/modes/motif/types/drums/home"),
  step_grid = StepGrid,
  perform = DrumsPerform,
}

function Drums.init()
  local instance = {
    sections = {},
    type = DrumsType,
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

  local function lane_start_row(lane_id)
    local local_index = lane_id - LaneMap.OFFSETS.drums
    return (local_index - 1) * 2 + 1
  end

  instance.apply_motif = function(lane_id)
    StepGrid.apply_motif(lane_id)
  end

  lane_handlers.register(2, {
    prepare_stage = function(lane, stage)
      local lane_id = lane.id
      local half_cycle = params:get("lane_" .. lane_id .. "_drum_reseed")
      if half_cycle == 0 then return end

      local displace = params:get("lane_" .. lane_id .. "_drum_mutate_displace")
      local pitch = params:get("lane_" .. lane_id .. "_drum_mutate_pitch")
      local density = params:get("lane_" .. lane_id .. "_drum_mutate_density")
      if displace == 0 and pitch == 0 and density == 0 then return end

      StepGrid.increment_mutation_loop(lane_id)
      local loop_count = StepGrid.get_mutation_loop_count(lane_id)
      local depth = StepGrid.triangle_depth(loop_count, half_cycle)
      if depth == 0 then return end

      local gen = StepGrid.get_genesis(lane_id)
      local scale = theory.get_scale()
      local length = params:get("lane_" .. lane_id .. "_drum_length")

      local mutated = StepGrid.mutate_steps(gen, depth, {
        displace = displace,
        pitch = pitch,
        density = density,
      }, lane_id, StepGrid.get_cycle_counter(lane_id), scale, length)

      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = (local_index - 1) * 2 + 1

      local events, duration = StepGrid.build_motif(mutated, {
        length       = length,
        division     = StepGrid.get_division(lane_id),
        gate_pct     = StepGrid.get_gate_pct(lane_id),
        swing        = params:get("lane_" .. lane_id .. "_drum_swing") / 100,
        probability  = params:get("lane_" .. lane_id .. "_drum_probability"),
        default_note = StepGrid.get_voice_note(lane_id),
        row_start    = row_start,
      })

      lane.motif.events = events
      lane.motif.duration = duration
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

    trail_mode = "immediate",
  })

  return instance
end

return Drums

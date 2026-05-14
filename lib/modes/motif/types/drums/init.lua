-- init.lua
-- Drums type module entry point.
-- Step sequencer trigger lanes with per-voice routing.

local Drums = {}

local DrumsType = include("lib/modes/motif/types/drums/type")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")
local DrumsPerform = include("lib/modes/motif/types/drums/perform")
local LaneMap = include("lib/lanes/lane_map")

local StepGrid = include("lib/modes/motif/types/drums/step_grid")

local modules = {
  home = include("lib/modes/motif/types/drums/home"),
  step_grid = StepGrid,
  playback = include("lib/modes/motif/types/drums/playback"),
  clear = include("lib/modes/motif/types/drums/clear"),
  perform = include("lib/modes/motif/types/drums/perform"),
}

local SECTION_IDS = {
  home = "DRUMS_HOME",
  playback = "DRUMS_PLAYBACK",
  clear = "DRUMS_CLEAR",
  perform = "DRUMS_PERFORM",
}

function Drums.init()
  local instance = {
    sections = {},
    grids = {},
    type = DrumsType
  }

  for name, module in pairs(modules) do
    instance[name] = module.init()

    if instance[name].screen and SECTION_IDS[name] then
      instance.sections[SECTION_IDS[name]] = instance[name].screen
    end

    if instance[name].grid then
      instance.grids[name] = instance[name].grid
    end
  end

  lane_handlers.register(2, {
    prepare_stage = function(lane, stage) end,

    is_muted = function(lane_id)
      return DrumsPerform.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      return DrumsPerform.get_velocity_multiplier(lane_id)
    end,

    note_positions = function(lane, note, event)
      if event.step then
        return {{x = event.step, y = 3}}
      end
      return {{x = event.x or 1, y = event.y or 3}}
    end,

    get_active_positions = function(lane)
      return {}
    end,

    trail_mode = "immediate"
  })

  return instance
end

return Drums

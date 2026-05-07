-- init.lua
-- Tape type module entry point
-- Consolidates all tape components and provides auto-registration

local Tape = {}

local TapeType = include("lib/modes/motif/types/tape/type")
local tape_transform = include("lib/modes/motif/types/tape/transform")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")

local modules = {
  keyboard = include("lib/modes/motif/types/tape/keyboard"),
  velocity = include("lib/modes/motif/types/tape/velocity"),
  tuning = include("lib/modes/motif/types/tape/tuning"),
  stage_nav = include("lib/modes/motif/types/tape/stage_nav"),
  playback = include("lib/modes/motif/types/tape/playback"),
  create = include("lib/modes/motif/types/tape/create"),
  clear = include("lib/modes/motif/types/tape/clear"),
  perform = include("lib/modes/motif/types/tape/perform"),
  stage_config = include("lib/modes/motif/types/tape/stage_config")
}

-- Maps component name to screen section ID
local SECTION_IDS = {
  velocity = "TAPE_VELOCITY",
  tuning = "TAPE_TUNING",
  stage_nav = "TAPE_STAGE_NAV",
  playback = "TAPE_PLAYBACK",
  create = "TAPE_CREATE",
  clear = "TAPE_CLEAR",
  perform = "TAPE_PERFORM",
  stage_config = "TAPE_STAGE_CONFIG"
}

function Tape.init()
  local instance = {
    sections = {},
    grids = {},
    type = TapeType
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

  -- Register lane handler for Tape (motif_type 1)
  lane_handlers.register(1, {
    prepare_stage = function(lane, stage)
      local reset_motif = params:get("lane_" .. lane.id .. "_stage_" .. stage.id .. "_reset_motif") == 2
      if reset_motif then
        lane.motif:reset_to_genesis()
      end
      lane_handlers.pre_quantize_events(lane.motif.events, lane.id)
      tape_transform.apply_transform(lane.id, stage.id, lane.motif)
    end,

    on_stage_start = function(lane, stage_index, start_time)
      local sc = _seeker.tape and _seeker.tape.stage_config
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
      local perf = _seeker.tape and _seeker.tape.perform
      return perf and perf.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      local perf = _seeker.tape and _seeker.tape.perform
      return perf and perf.get_velocity_multiplier(lane_id) or 1.0
    end,

    note_positions = function(lane, note, event)
      local keyboard = _seeker.tape.type.get_keyboard()
      return keyboard.note_to_positions(note) or {{x = event.x, y = event.y}}
    end,

    get_active_positions = function(lane)
      local positions = {}
      local keyboard = _seeker.tape.type.get_keyboard()
      for _, note in pairs(lane.active_notes) do
        local current_positions = keyboard.note_to_positions(note.note)
        if current_positions then
          for _, pos in ipairs(current_positions) do
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

return Tape

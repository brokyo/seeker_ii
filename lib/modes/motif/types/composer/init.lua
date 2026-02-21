-- init.lua
-- Composer type module entry point
-- Consolidates all composer components and provides auto-registration

local Composer = {}

local composer_generator = include("lib/modes/motif/types/composer/generator")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")

local modules = {
  keyboard = include("lib/modes/motif/types/composer/keyboard"),
  expression_stages = include("lib/modes/motif/types/composer/expression_stages"),
  harmonic_stages = include("lib/modes/motif/types/composer/harmonic_stages"),
  playback = include("lib/modes/motif/types/composer/playback"),
  create = include("lib/modes/motif/types/composer/create"),
  clear = include("lib/modes/motif/types/composer/clear"),
  perform = include("lib/modes/motif/types/composer/perform")
}

-- Maps component name to screen section ID
local SECTION_IDS = {
  expression_stages = "COMPOSER_EXPRESSION_STAGES",
  harmonic_stages = "COMPOSER_HARMONIC_STAGES",
  playback = "COMPOSER_PLAYBACK",
  create = "COMPOSER_CREATE",
  clear = "COMPOSER_CLEAR",
  perform = "COMPOSER_PERFORM"
}

function Composer.init()
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

    -- Auto-build grid components table (playback, perform, keyboard only)
    local GRID_COMPONENTS = {playback = true, perform = true, keyboard = true}
    if instance[name].grid and GRID_COMPONENTS[name] then
      instance.grids[name] = instance[name].grid
    end
  end

  -- Register lane handler for Composer (motif_type 2)
  lane_handlers.register(2, {
    prepare_stage = function(lane, stage)
      composer_generator.prepare_stage(lane.id, stage.id, lane.motif)
    end,

    -- No on_stage_start: composer has no stage config blink

    is_muted = function(lane_id)
      local perf = _seeker.composer and _seeker.composer.perform
      return perf and perf.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      local perf = _seeker.composer and _seeker.composer.perform
      return perf and perf.get_velocity_multiplier(lane_id) or 1.0
    end,

    note_positions = function(lane, note, event)
      -- Composer events carry their own position
      return {{x = event.x, y = event.y}}
    end,

    note_key = function(note, event)
      -- Step-based key allows multiple simultaneous chord notes
      if event.step then
        return "step_" .. event.step
      end
      return note
    end,

    get_active_positions = function(lane)
      local positions = {}
      if not lane.playing then
        return positions
      end
      local composer_keyboard = _seeker.composer.keyboard.grid
      for _, note in pairs(lane.active_notes) do
        local current_positions = composer_keyboard.note_to_positions(note.note)
        if current_positions then
          for _, pos in ipairs(current_positions) do
            table.insert(positions, {x = pos.x, y = pos.y, note = note.note})
          end
        end
      end
      return positions
    end,

    trail_mode = "immediate"
  })

  return instance
end

return Composer

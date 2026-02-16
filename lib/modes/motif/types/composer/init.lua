-- init.lua
-- Composer type module entry point
-- Consolidates all composer components and provides auto-registration

local Composer = {}

local modules = {
  keyboard = include("lib/modes/motif/types/composer/keyboard"),
  expression_stages = include("lib/modes/motif/types/composer/expression_stages"),
  harmonic_stages = include("lib/modes/motif/types/composer/harmonic_stages"),
  cycling = include("lib/modes/motif/types/composer/cycling"),
  playback = include("lib/modes/motif/types/composer/playback"),
  create = include("lib/modes/motif/types/composer/create"),
  clear = include("lib/modes/motif/types/composer/clear"),
  perform = include("lib/modes/motif/types/composer/perform")
}

-- Maps component name to screen section ID
local SECTION_IDS = {
  expression_stages = "COMPOSER_EXPRESSION_STAGES",
  harmonic_stages = "COMPOSER_HARMONIC_STAGES",
  cycling = "COMPOSER_CYCLING",
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

    -- Auto-build grid components table (only cycling, playback, perform, keyboard)
    local GRID_COMPONENTS = {cycling = true, playback = true, perform = true, keyboard = true}
    if instance[name].grid and GRID_COMPONENTS[name] then
      instance.grids[name] = instance[name].grid
    end
  end

  -- Expose cycling param snapshot save/load functions
  instance.cycling_save_params = modules.cycling.save_cycling_params
  instance.cycling_load_params = modules.cycling.load_cycling_params
  instance.cycling_cycle_stage_strum = modules.cycling.cycle_stage_strum
  instance.cycling_cycle_stage_voicing = modules.cycling.cycle_stage_voicing
  instance.cycling_cycle_stage_chord_len = modules.cycling.cycle_stage_chord_len
  instance.cycling_cycle_stage_degree = modules.cycling.cycle_stage_degree
  instance.cycling_rebuild = modules.cycling.rebuild
  instance.cycling_randomize = modules.cycling.randomize

  return instance
end

return Composer

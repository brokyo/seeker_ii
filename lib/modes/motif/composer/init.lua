-- init.lua
-- Composer type module entry point
-- Consolidates all composer components and provides auto-registration

local Composer = {}

local modules = {
  keyboard = include("lib/modes/motif/composer/keyboard"),
  expression_stages = include("lib/modes/motif/composer/expression_stages"),
  harmonic_stages = include("lib/modes/motif/composer/harmonic_stages"),
  playback = include("lib/modes/motif/composer/playback"),
  create = include("lib/modes/motif/composer/create"),
  clear = include("lib/modes/motif/composer/clear"),
  perform = include("lib/modes/motif/composer/perform")
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

    -- Auto-build grid components table
    if instance[name].grid then
      instance.grids[name] = instance[name].grid
    end
  end

  return instance
end

return Composer

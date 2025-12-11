-- init.lua
-- Sampler type module entry point
-- Consolidates all sampler components and provides auto-registration

local Sampler = {}

local modules = {
  keyboard = include("lib/modes/motif/sampler/keyboard"),
  velocity = include("lib/modes/motif/sampler/velocity"),
  stage_nav = include("lib/modes/motif/sampler/stage_nav"),
  playback = include("lib/modes/motif/sampler/playback"),
  create = include("lib/modes/motif/sampler/create"),
  clear = include("lib/modes/motif/sampler/clear"),
  perform = include("lib/modes/motif/sampler/perform"),
  stage_config = include("lib/modes/motif/sampler/stage_config"),
  chop_config = include("lib/modes/motif/sampler/chop_config")
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

  return instance
end

return Sampler

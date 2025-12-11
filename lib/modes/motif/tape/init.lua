-- init.lua
-- Tape type module entry point
-- Consolidates all tape components and provides auto-registration

local Tape = {}

local modules = {
  keyboard = include("lib/modes/motif/tape/keyboard"),
  velocity = include("lib/modes/motif/tape/velocity"),
  stage_nav = include("lib/modes/motif/tape/stage_nav"),
  playback = include("lib/modes/motif/tape/playback"),
  create = include("lib/modes/motif/tape/create"),
  clear = include("lib/modes/motif/tape/clear"),
  perform = include("lib/modes/motif/tape/perform"),
  stage_config = include("lib/modes/motif/tape/stage_config")
}

-- Maps component name to screen section ID
local SECTION_IDS = {
  velocity = "TAPE_VELOCITY",
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

return Tape

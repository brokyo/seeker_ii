-- grid_mode_registry.lua
-- Central registry for all grid modes
-- Defines mode properties, button positions, sections, and implementations

local GridModeRegistry = {}

-- Mode definitions
GridModeRegistry.MODES = {
  WTAPE = {
    button = { x = 13, y = 2 },
    default_section = "WTAPE",
    sections = { "WTAPE", "WTAPE_PLAYBACK", "WTAPE_RECORD", "WTAPE_FF", "WTAPE_REWIND", "WTAPE_REVERSE", "WTAPE_LOOP_ACTIVE", "WTAPE_FRIPPERTRONICS", "WTAPE_DECAY" },
    path = "lib/grid/layouts/wtape_mode"
  },

  OSC_CONFIG = {
    button = { x = 14, y = 2 },
    default_section = "OSC_CONFIG",
    sections = { "OSC_CONFIG", "OSC_FLOAT", "OSC_LFO", "OSC_TRIGGER" },
    path = "lib/grid/layouts/osc_config_mode"
  },

  EURORACK_OUTPUT = {
    button = { x = 15, y = 2 },
    default_section = "EURORACK_CONFIG",
    sections = { "EURORACK_CONFIG", "CROW_OUTPUT", "TXO_TR_OUTPUT", "TXO_CV_OUTPUT" },
    path = "lib/grid/layouts/eurorack_mode"
  },

  music = {
    button = { x = 16, y = 2 },
    default_section = "MOTIF",
    sub_modes = {
      tape = {
        button = { x = 15, y = 3 },
        default_section = "TAPE_HOME",
        path = "lib/grid/layouts/keyboard_mode",
      },
      composer = {
        button = { x = 16, y = 3 },
        default_section = "COMPOSER_HOME",
        path = "lib/grid/layouts/composer_mode",
      },
    },
    sections = {
      -- Voice config (parent)
      "MOTIF",
      -- Tape sub-mode
      "TAPE_HOME", "LANE", "STAGE", "LANE_CONFIG",
      "TAPE_VELOCITY", "TAPE_STAGE_NAV", "TAPE_PLAYBACK", "TAPE_CREATE",
      "TAPE_CLEAR", "TAPE_PERFORM", "TAPE_STAGE_CONFIG",
      "SAMPLER_CHOP_CONFIG", "SAMPLER_CREATE", "SAMPLER_STAGE_CONFIG",
      "SAMPLER_PLAYBACK", "SAMPLER_CLEAR", "SAMPLER_VELOCITY", "SAMPLER_PERFORM",
      -- Composer sub-mode
      "COMPOSER_HOME", "COMPOSER_LIVE", "COMPOSER_PROGRESSION", "COMPOSER_PLAYBACK", "COMPOSER_VOICE", "COMPOSER_PARAMS",
    },
  },

  CONFIG = {
    button = { x = 16, y = 1 },
    default_section = "CONFIG",
    sections = { "CONFIG" },
    path = "lib/grid/layouts/config_mode"
  }
}

-- Build section-to-sub_mode lookup for modes with sub_modes
-- Returns which sub_mode a section belongs to (nil for parent-level sections like MOTIF)
local _section_to_sub_mode = {}
for mode_id, config in pairs(GridModeRegistry.MODES) do
  if config.sub_modes then
    for sub_id, sub_config in pairs(config.sub_modes) do
      for _, section in ipairs(config.sections) do
        -- Composer sections start with COMPOSER_, motif owns LANE/STAGE/TAPE_*/SAMPLER_*
        if sub_id == "composer" then
          if section:sub(1, 9) == "COMPOSER_" then
            _section_to_sub_mode[section] = { mode = mode_id, sub_mode = sub_id }
          end
        elseif sub_id == "tape" then
          -- Motif owns LANE, STAGE, LANE_CONFIG, TAPE_*, SAMPLER_*
          if section == "LANE" or section == "STAGE" or section == "LANE_CONFIG"
             or section:sub(1, 5) == "TAPE_" or section:sub(1, 8) == "SAMPLER_" then
            _section_to_sub_mode[section] = { mode = mode_id, sub_mode = sub_id }
          end
        end
      end
    end
  end
end

-- Get mode configuration by ID
function GridModeRegistry.get_mode(mode_id)
  return GridModeRegistry.MODES[mode_id]
end

-- Get which mode a section belongs to
function GridModeRegistry.get_mode_for_section(section)
  for mode_id, config in pairs(GridModeRegistry.MODES) do
    for _, s in ipairs(config.sections) do
      if s == section then
        return mode_id
      end
    end
  end
  return nil
end

-- Get which sub-mode a section belongs to (nil for parent-level sections)
function GridModeRegistry.get_sub_mode_for_section(section)
  local entry = _section_to_sub_mode[section]
  if entry then return entry.sub_mode end
  return nil
end

-- Check if a section belongs to a mode
function GridModeRegistry.section_belongs_to_mode(section, mode_id)
  local config = GridModeRegistry.MODES[mode_id]
  if not config then return false end

  for _, s in ipairs(config.sections) do
    if s == section then return true end
  end
  return false
end

-- Get all mode IDs in button order (left to right)
function GridModeRegistry.get_ordered_mode_ids()
  local modes_with_pos = {}
  for mode_id, config in pairs(GridModeRegistry.MODES) do
    table.insert(modes_with_pos, {
      id = mode_id,
      x = config.button.x
    })
  end

  table.sort(modes_with_pos, function(a, b) return a.x < b.x end)

  local ordered = {}
  for _, m in ipairs(modes_with_pos) do
    table.insert(ordered, m.id)
  end
  return ordered
end

return GridModeRegistry

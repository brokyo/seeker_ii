-- grid_mode_registry.lua
-- Central registry for all grid modes
-- Defines mode properties, button positions, sections, and implementations

local GridModeRegistry = {}

-- Mode definitions
GridModeRegistry.MODES = {
  WTAPE = {
    button = { x = 13, y = 2 },
    default_section = "WTAPE",
    sections = { "WTAPE", "WTAPE_PLAYBACK", "WTAPE_RECORD", "WTAPE_FF", "WTAPE_REWIND", "WTAPE_LOOP_START", "WTAPE_LOOP_END", "WTAPE_REVERSE", "WTAPE_LOOP_ACTIVE" },
    path = "lib/grid/modes/wtape_mode"
  },

  OSC_CONFIG = {
    button = { x = 14, y = 2 },
    default_section = "OSC_CONFIG",
    sections = { "OSC_CONFIG", "OSC_FLOAT", "OSC_LFO", "OSC_TRIGGER" },
    path = "lib/grid/modes/osc_config_mode"
  },

  EURORACK_OUTPUT = {
    button = { x = 15, y = 2 },
    default_section = "EURORACK_CONFIG",
    sections = { "EURORACK_CONFIG", "CROW_OUTPUT", "TXO_TR_OUTPUT", "TXO_CV_OUTPUT" },
    path = "lib/grid/modes/eurorack_mode"
  },

  KEYBOARD = {
    button = { x = 16, y = 2 },
    default_section = "KEYBOARD",
    sections = {
      "KEYBOARD",
      "LANE",
      "STAGE",
      "MOTIF",
      "CREATE_MOTIF",
      "VELOCITY",
      "TUNING",
      "LANE_CONFIG",
      "TAPE_STAGE_CONFIG",
      "SAMPLER_PAD_CONFIG",
      "SAMPLER_CREATOR",
      "SAMPLER_STAGE_CONFIG",
      "SAMPLER_PLAYBACK",
      "SAMPLER_CLEAR",
      "SAMPLER_VELOCITY",
      "SAMPLER_PERFORMANCE",
      "EXPRESSION_CONFIG",
      "HARMONIC_CONFIG",
      "CLEAR_MOTIF"
    },
    path = "lib/grid/modes/keyboard_mode"
  },

  CONFIG = {
    button = { x = 16, y = 1 },
    default_section = "CONFIG",
    sections = { "CONFIG" },
    path = "lib/grid/modes/config_mode"
  }
}

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

-- Composer mode initialization
-- Top-level grid mode for algorithmic chord progressions.
-- Grid handles lane buttons + per-lane stages directly.
-- Lane button cycles through COMPOSER_LIVE, COMPOSER_PLAYBACK, COMPOSER_VOICE sections.

local NornsUI = include("lib/ui/base/norns_ui")
local Composer = include("lib/modes/composer/composer")
local LiveView = include("lib/modes/composer/live_view")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")

-- Voice parameter modules (same registry as lane_config)
local VOICES = {
    include("lib/modes/motif/infrastructure/voices/mx_samples"),
    include("lib/modes/motif/infrastructure/voices/disting"),
    include("lib/modes/motif/infrastructure/voices/disting_nt"),
    include("lib/modes/motif/infrastructure/voices/eurorack_cv"),
    include("lib/modes/motif/infrastructure/voices/just_friends"),
    include("lib/modes/motif/infrastructure/voices/midi"),
    include("lib/modes/motif/infrastructure/voices/osc"),
    include("lib/modes/motif/infrastructure/voices/txo_osc"),
    include("lib/modes/motif/infrastructure/voices/wsyn"),
}

---------------------------------------------------------------
-- COMPOSER_HOME: landing screen for composer sub-mode
---------------------------------------------------------------
local function create_home_section()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_HOME",
    name = "Composer Config",
    description = "Algorithmic chord progressions across lanes.",
    params = {}
  })

  return norns_ui
end

---------------------------------------------------------------
-- COMPOSER_PLAYBACK: speed, volume, swing for the focused lane
---------------------------------------------------------------
local function create_playback_section()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_PLAYBACK",
    name = "Playback",
    description = "Lane playback controls: volume, speed, octave offset.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    self.name = "Playback"
    self.params = {
      { id = "lane_" .. lane_idx .. "_volume", arc_multi_float = {0.1, 0.05, 0.01} },
      { id = "lane_" .. lane_idx .. "_speed" },
      { id = "lane_" .. lane_idx .. "_octave_offset" },
      { id = "lane_" .. lane_idx .. "_swing", arc_multi_float = {5, 2, 1} },
    }
  end

  return norns_ui
end

---------------------------------------------------------------
-- COMPOSER_VOICE: voice routing for the focused lane
---------------------------------------------------------------
local function create_voice_section()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_VOICE",
    name = "Voice",
    description = "Voice routing: select output destination and configure voice parameters.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local visible_voice = params:get("lane_" .. lane_idx .. "_visible_voice")
    self.name = "Voice"

    local param_table = {
      { id = "lane_" .. lane_idx .. "_visible_voice" },
    }

    local voice_module = VOICES[visible_voice]
    if voice_module and voice_module.get_ui_params then
      local voice_params = voice_module.get_ui_params(lane_idx)
      for _, entry in ipairs(voice_params) do
        table.insert(param_table, entry)
      end
    end

    self.params = param_table
  end

  return norns_ui
end

---------------------------------------------------------------
-- COMPOSER_PARAMS: chord shape, texture, and structure
---------------------------------------------------------------
local function create_params_section()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_PARAMS",
    name = "Composer",
    description = "Chord progression shape, texture, and structure.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    self.name = "Composer"
    self.params = {
      { separator = true, title = "Structure" },
      { id = "rc_composer_start" },
      { id = "rc_composer_movement" },
      { id = "rc_composer_stages" },
      { id = "rc_composer_beats" },
      { separator = true, title = "Harmony" },
      { id = "rc_composer_chord_len" },
      { id = "rc_composer_spread_voices" },
      { separator = true, title = "Articulation" },
      { id = "rc_composer_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_composer_strum_order" },
      { id = "rc_composer_gate" },
      { id = "rc_composer_loops" },
    }
  end

  return norns_ui
end

---------------------------------------------------------------
-- ComposerMode
---------------------------------------------------------------
local ComposerMode = {}

function ComposerMode.init()
  local instance = {
    sections = {},
    grids = {}
  }

  -- Create params first (needed before live_view builds PageState)
  Composer.create_params()

  -- Initialize live view (creates screen UI, grid UI, PageState)
  LiveView.init(Composer)

  -- Store core reference for RC and other modules
  instance.composer = Composer

  -- Register screen sections
  instance.sections["COMPOSER_HOME"] = create_home_section()
  instance.sections["COMPOSER_LIVE"] = LiveView.screen
  instance.sections["COMPOSER_PROGRESSION"] = LiveView.progression_screen
  instance.sections["COMPOSER_PLAYBACK"] = create_playback_section()
  instance.sections["COMPOSER_VOICE"] = create_voice_section()
  instance.sections["COMPOSER_PARAMS"] = create_params_section()

  -- Register grid
  instance.grids.composer = LiveView.grid

  -- Register lane handler for Composer (motif_type 4)
  -- Note: prepare_stage is a no-op because Composer writes to rc_stage_motifs,
  -- which lane.lua loads directly before reaching the handler.
  lane_handlers.register(4, {
    prepare_stage = function(lane, stage) end,

    is_muted = function(lane_id)
      return false
    end,

    get_velocity_multiplier = function(lane_id)
      return 1.0
    end,

    note_positions = function(lane, note, event)
      return {{x = event.x, y = event.y}}
    end,

    note_key = function(note, event)
      if event.step then
        return "step_" .. event.step
      end
      return note
    end,

    get_active_positions = function(lane)
      return {}
    end,

    trail_mode = "immediate"
  })

  return instance
end

return ComposerMode

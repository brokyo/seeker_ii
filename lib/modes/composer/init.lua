-- Composer mode initialization
-- Integrates with keyboard_mode via type_registry (motif_type 4).
-- Degree grid replaces the keyboard area. Standard lane buttons at 13-16.

local NornsUI = include("lib/ui/base/norns_ui")
local Composer = include("lib/modes/composer/composer")
local LiveView = include("lib/modes/composer/live_view")
local DegreeGrid = include("lib/modes/composer/degree_grid")
local PitchDisplay = include("lib/modes/composer/pitch_display")
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
      { id = "rc_composer_rotation" },
      { separator = true, title = "Articulation" },
      { id = "rc_composer_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_composer_strum_order" },
      { id = "rc_composer_gate" },
      { id = "rc_composer_loops" },
      { separator = true, title = "Actions" },
      { id = "rc_composer_randomize", is_action = true },
      { id = "rc_composer_smooth", is_action = true },
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
  }

  -- Create params first (needed before live_view builds PageState)
  Composer.create_params()

  -- Initialize live view (creates screen UI, PageState — no grid)
  LiveView.init(Composer)

  -- Initialize grid components
  local degree_grid = DegreeGrid.init()
  local pitch_display = PitchDisplay.init()

  -- Store core references
  instance.composer = Composer
  instance.live_view = LiveView
  instance.degree_grid = degree_grid
  instance.pitch_display = pitch_display

  -- Register screen sections
  instance.sections["COMPOSER_LIVE"] = LiveView.screen
  instance.sections["COMPOSER_PROGRESSION"] = LiveView.progression_screen
  instance.sections["COMPOSER_PLAYBACK"] = create_playback_section()
  instance.sections["COMPOSER_VOICE"] = create_voice_section()
  instance.sections["COMPOSER_PARAMS"] = create_params_section()

  -- Register lane handler for Composer (motif_type 4)
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

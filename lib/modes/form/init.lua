-- Form mode initialization
-- Form sub-mode for motif: algorithmic chord progressions.
-- Grid handles lane buttons + per-lane stages directly.
-- Lane button cycles through FORM_LIVE, FORM_PLAYBACK, FORM_VOICE sections.

local NornsUI = include("lib/ui/base/norns_ui")
local Form = include("lib/modes/motif/types/composer/cycling")
local composer_generator = include("lib/modes/motif/types/composer/generator")
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

local VOICE_NAMES = {}
for _, voice in ipairs(VOICES) do
    table.insert(VOICE_NAMES, voice.name)
end

---------------------------------------------------------------
-- FORM_PLAYBACK: speed, octave, volume for the focused lane
---------------------------------------------------------------
local function create_playback_section()
  local norns_ui = NornsUI.new({
    id = "FORM_PLAYBACK",
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
-- FORM_VOICE: voice routing for the focused lane
---------------------------------------------------------------
local function create_voice_section()
  local norns_ui = NornsUI.new({
    id = "FORM_VOICE",
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

    -- Voice-specific params from the selected voice module
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
-- FORM_PARAMS: chord shape, texture, and structure params
---------------------------------------------------------------
local function create_params_section()
  local norns_ui = NornsUI.new({
    id = "FORM_PARAMS",
    name = "Form",
    description = "Chord progression shape, texture, and structure.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    self.name = "Form"
    self.params = {
      { separator = true, title = "Form Settings" },
      { id = "rc_form_start" },
      { id = "rc_form_movement" },
      { id = "rc_form_stages" },
      { id = "rc_form_beats" },
      { separator = true, title = "Harmony" },
      { id = "rc_form_chord_len" },
      { id = "rc_form_voicing" },
      { id = "rc_form_rotation" },
      { separator = true, title = "Articulation" },
      { id = "rc_form_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_form_strum_order" },
      { id = "rc_form_loops" },
    }
  end

  return norns_ui
end

---------------------------------------------------------------
-- FormMode
---------------------------------------------------------------
local FormMode = {}

function FormMode.init()
  local instance = {
    sections = {},
    grids = {}
  }

  -- Initialize form component (creates params, screen UI, grid UI)
  instance.form = Form.init()

  -- Register screen sections
  instance.sections["FORM_LIVE"] = instance.form.screen
  instance.sections["FORM_PLAYBACK"] = create_playback_section()
  instance.sections["FORM_VOICE"] = create_voice_section()
  instance.sections["FORM_PARAMS"] = create_params_section()

  -- Register grid
  instance.grids.form = instance.form.grid

  -- Register lane handler for Form (motif_type 4)
  -- Form shares Composer's generator and keyboard but has its own mode identity.
  lane_handlers.register(4, {
    prepare_stage = function(lane, stage)
      composer_generator.prepare_stage(lane.id, stage.id, lane.motif)
    end,

    -- No on_stage_start: form has no stage config blink (stages managed by grid)

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
      local positions = {}
      if not lane.playing then
        return positions
      end
      local composer_keyboard = _seeker.composer and _seeker.composer.keyboard and _seeker.composer.keyboard.grid
      if not composer_keyboard then return positions end
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

return FormMode

-- home.lua
-- Drums screen sections. Lane button cycles Timing/Config.
-- Long-press a step on the grid to open per-step editor (DRUMS_HOME).

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")
local musicutil = require('musicutil')
local theory = include("lib/modes/motif/core/theory")
local StepGrid = include("lib/modes/motif/types/drums/step_grid")

local DrumsHome = {}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function midi_to_scale_position(midi)
  local scale = theory.get_scale()
  for i, n in ipairs(scale) do
    if n == midi then return i end
    if n > midi then return math.max(1, i - 1) end
  end
  return #scale
end

local function scale_position_to_midi(pos)
  local scale = theory.get_scale()
  return scale[math.max(1, math.min(pos, #scale))]
end

local function get_drums_lane()
  local focused = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(focused)
  if sub_mode == "drums" then return focused end
  return LaneMap.to_flat("drums", 1)
end

local function lane_label(lane_id)
  return "D" .. (lane_id - LaneMap.OFFSETS.drums)
end

------------------------------------------------------------------------
-- DRUMS_TIMING: division, gate length
------------------------------------------------------------------------

local function create_timing_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_TIMING",
    name = "Timing",
    description = "Step timing: division and gate length.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Timing"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_length" },
      { id = "lane_" .. lane_id .. "_drum_division" },
      { id = "lane_" .. lane_id .. "_drum_voice_note" },
      { id = "lane_" .. lane_id .. "_drum_gate_length", arc_multi_float = {10, 5, 1} },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

------------------------------------------------------------------------
-- DRUMS_HOME: per-step editor (note, velocity)
------------------------------------------------------------------------

local function create_step_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Step",
    description = "Per-step note and velocity.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    local step = StepGrid.get_selected_step(lane_id)
    local s = StepGrid.get_step(lane_id, step)
    local step_label = "Step " .. step .. (s.active and " *" or " o")

    local voice_midi = scale_position_to_midi(params:get("lane_" .. lane_id .. "_drum_voice_note"))
    local midi = s.note or voice_midi
    params:set("drum_step_note", midi_to_scale_position(midi), true)
    params:set("drum_step_velocity", s.velocity, true)

    self.name = lane_label(lane_id) .. " " .. step_label
    self.params = {
      { id = "drum_step_note" },
      { id = "drum_step_velocity" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

------------------------------------------------------------------------
-- Virtual params for per-step editing
------------------------------------------------------------------------

local function get_focused_drums_lane()
  local lane_id = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(lane_id)
  if sub_mode ~= "drums" then return nil end
  return lane_id
end

local function create_step_edit_params()
  params:add_group("drum_step_edit", "DRUM STEP EDIT", 2)

  params:add_number("drum_step_note", "Step Note", 1, 128, 36,
    function(param)
      local midi = scale_position_to_midi(param:get())
      return midi and musicutil.note_num_to_name(midi, true) or "?"
    end)
  params:set_action("drum_step_note", function(value)
    local lane_id = get_focused_drums_lane()
    if not lane_id then return end
    local midi = scale_position_to_midi(value)
    local s = StepGrid.get_step(lane_id, StepGrid.get_selected_step(lane_id))
    if s then
      local voice_midi = scale_position_to_midi(params:get("lane_" .. lane_id .. "_drum_voice_note"))
      s.note = (midi == voice_midi) and nil or midi
      StepGrid.apply_motif(lane_id)
    end
  end)

  params:add_number("drum_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("drum_step_velocity", function(value)
    local lane_id = get_focused_drums_lane()
    if not lane_id then return end
    local s = StepGrid.get_step(lane_id, StepGrid.get_selected_step(lane_id))
    if s then
      s.velocity = value
      StepGrid.apply_motif(lane_id)
    end
  end)
end

------------------------------------------------------------------------
-- Section cycling and init
------------------------------------------------------------------------

DrumsHome.LANE_SECTIONS = {"DRUMS_TIMING", "LANE_CONFIG"}

function DrumsHome.init()
  create_step_edit_params()

  local timing_screen = create_timing_screen()
  local step_screen = create_step_screen()

  return {
    screen = step_screen,
    sections = {
      DRUMS_HOME = step_screen,
      DRUMS_TIMING = timing_screen,
    }
  }
end

return DrumsHome

-- home.lua
-- Drums screen sections. Lane button cycles Timing/Mutation/Config.
-- Long-press a step on the grid to open per-step editor (DRUMS_HOME).

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")
local musicutil = require('musicutil')
local theory = include("lib/modes/motif/core/theory")

local DrumsHome = {}

local _step_state = nil

function DrumsHome.set_step_state_ref(ref)
  _step_state = ref
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local function get_scale_pitch_classes()
  local scale = theory.get_scale()
  local classes = {}
  local seen = {}
  for _, midi in ipairs(scale) do
    local pc = midi % 12
    if not seen[pc] then
      seen[pc] = true
      classes[#classes + 1] = pc
    end
  end
  table.sort(classes)
  return classes
end

local function midi_to_note_and_octave(midi)
  local pc = midi % 12
  local octave = math.floor(midi / 12)
  local classes = get_scale_pitch_classes()
  local note_idx = 1
  for i, c in ipairs(classes) do
    if c == pc then note_idx = i; break end
    if c > pc then note_idx = math.max(1, i - 1); break end
  end
  return note_idx, octave
end

local function note_and_octave_to_midi(note_idx, octave)
  local classes = get_scale_pitch_classes()
  local pc = classes[math.max(1, math.min(note_idx, #classes))]
  return pc + octave * 12
end

local function get_drums_lane()
  local focused = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(focused)
  if sub_mode == "drums" then return focused end
  return LaneMap.to_flat("drums", 1)
end

local function get_focused_drums_lane()
  local lane_id = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(lane_id)
  if sub_mode ~= "drums" then return nil end
  return lane_id
end

local function lane_label(lane_id)
  return "D" .. (lane_id - LaneMap.OFFSETS.drums)
end

------------------------------------------------------------------------
-- Hold indicator overlay
------------------------------------------------------------------------

local function draw_hold_overlay()
  local held = _step_state and _step_state.held_step
  if not held then return end
  local grid_comp = _seeker.drums_type and _seeker.drums_type.grid and _seeker.drums_type.grid.grid
  if not grid_comp then return end
  local press = grid_comp.press_state.pressed_keys[string.format("%d,%d",
    ((held.step - 1) % 8) + 1,
    (held.lane_id - LaneMap.OFFSETS.drums - 1) * 2 + 1 + math.floor((held.step - 1) / 8))]
  if not press then return end
  local progress = math.min((util.time() - press.start_time) / grid_comp.long_press_threshold, 1.0)
  local bar_width = math.floor(progress * 128)
  screen.level(math.floor(progress * 15))
  screen.rect(0, 0, bar_width, 2)
  screen.fill()
  if progress >= 1.0 then
    screen.level(15)
    screen.move(64, 30)
    screen.text_center(lane_label(held.lane_id) .. " Step " .. held.step)
  end
end

------------------------------------------------------------------------
-- DRUMS_TIMING: division, gate, swing, probability
------------------------------------------------------------------------

local function create_timing_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_TIMING",
    name = "Timing",
    description = "Step timing: division, gate, swing, probability.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Timing"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_length" },
      { id = "lane_" .. lane_id .. "_drum_division" },
      { id = "lane_" .. lane_id .. "_drum_gate_length", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_drum_swing", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_drum_probability", arc_multi_float = {10, 5, 1} },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  local original_draw_timing = norns_ui.draw
  norns_ui.draw = function(self)
    original_draw_timing(self)
    draw_hold_overlay()
  end

  return norns_ui
end

------------------------------------------------------------------------
-- DRUMS_HOME: per-step editor (note, octave, velocity, ratchet)
------------------------------------------------------------------------

local function create_step_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Step",
    description = "Per-step note, octave, velocity, and ratchet.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    local step = _step_state.get_selected_step(lane_id)
    local s = _step_state.get_active_step(lane_id, step)
    local viewing_resp = _step_state.is_viewing_response(lane_id)
    local layer_label = viewing_resp and "Resp" or "Call"
    local step_label = layer_label .. " " .. step .. (s.active and " *" or " o")

    local default_note = _step_state.get_default_note()
    local midi = s.note or default_note
    local note_idx, octave = midi_to_note_and_octave(midi)

    params:set("drum_step_note", note_idx, true)
    params:set("drum_step_octave", octave, true)
    params:set("drum_step_velocity", s.velocity, true)
    params:set("drum_step_ratchet", s.ratchet or 1, true)

    self.name = lane_label(lane_id) .. " " .. step_label
    self.params = {
      { id = "drum_step_note" },
      { id = "drum_step_octave" },
      { id = "drum_step_velocity" },
      { id = "drum_step_ratchet" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  local original_draw_step = norns_ui.draw
  norns_ui.draw = function(self)
    original_draw_step(self)
    draw_hold_overlay()
  end

  return norns_ui
end

------------------------------------------------------------------------
-- DRUMS_MUTATION: mutation cycle and intensities
------------------------------------------------------------------------

local function create_mutation_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_MUTATION",
    name = "Mutation",
    description = "Shape-preserving pattern mutation. Cycle sets the journey length, intensities control what changes.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Mutation"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_reseed" },
      { id = "lane_" .. lane_id .. "_drum_mutate_displace", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_drum_mutate_pitch", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_drum_mutate_density", arc_multi_float = {10, 5, 1} },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  local original_draw_mutation = norns_ui.draw
  norns_ui.draw = function(self)
    original_draw_mutation(self)
    draw_hold_overlay()
  end

  return norns_ui
end

------------------------------------------------------------------------
-- DRUMS_CALL: call config, loop count, edit toggle
------------------------------------------------------------------------

local function create_call_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_CALL",
    name = "Call",
    description = "Call pattern settings. Edit Call locks the grid to show the call pattern.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Call"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_cr_active" },
      { id = "lane_" .. lane_id .. "_drum_cr_call_loops" },
      { id = "lane_" .. lane_id .. "_drum_cr_edit_call" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  local original_draw_call = norns_ui.draw
  norns_ui.draw = function(self)
    original_draw_call(self)
    draw_hold_overlay()
  end

  return norns_ui
end

------------------------------------------------------------------------
-- DRUMS_RESPONSE: response strategy, loop count, edit toggle
------------------------------------------------------------------------

local function create_response_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_RESPONSE",
    name = "Response",
    description = "Response pattern settings. Strategy selects how the response is generated. Edit Response locks the grid to show the response pattern.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    local strategy_name = _step_state.get_cr_strategy_name(lane_id)
    self.name = lane_label(lane_id) .. " Response (" .. strategy_name .. ")"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_cr_strategy" },
      { id = "lane_" .. lane_id .. "_drum_cr_resp_loops" },
      { id = "lane_" .. lane_id .. "_drum_cr_edit_resp" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  local original_draw_resp = norns_ui.draw
  norns_ui.draw = function(self)
    original_draw_resp(self)
    draw_hold_overlay()
  end

  return norns_ui
end

------------------------------------------------------------------------
-- Virtual params for per-step editing
------------------------------------------------------------------------

local function apply_note_change()
  local lane_id = get_focused_drums_lane()
  if not lane_id then return end
  local s = _step_state.get_active_step(lane_id, _step_state.get_selected_step(lane_id))
  if not s then return end
  local midi = note_and_octave_to_midi(params:get("drum_step_note"), params:get("drum_step_octave"))
  local default_note = _step_state.get_default_note()
  s.note = (midi == default_note) and nil or midi
  if not _step_state.is_viewing_response(lane_id) then
    _step_state.snapshot_genesis(lane_id)
  end
  _step_state.apply_motif(lane_id)
end

local function create_step_edit_params()
  params:add_group("drum_step_edit", "DRUM STEP EDIT", 4)

  params:add_number("drum_step_note", "Note", 1, 12, 1,
    function(param)
      local classes = get_scale_pitch_classes()
      local idx = math.max(1, math.min(param:get(), #classes))
      return NOTE_NAMES[classes[idx] + 1]
    end)
  params:set_action("drum_step_note", function(value)
    local classes = get_scale_pitch_classes()
    if value > #classes then params:set("drum_step_note", #classes, true); return end
    apply_note_change()
  end)

  params:add_number("drum_step_octave", "Octave", 0, 8, 4)
  params:set_action("drum_step_octave", function()
    apply_note_change()
  end)

  params:add_number("drum_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("drum_step_velocity", function(value)
    local lane_id = get_focused_drums_lane()
    if not lane_id then return end
    local s = _step_state.get_active_step(lane_id, _step_state.get_selected_step(lane_id))
    if s then
      s.velocity = value
      if not _step_state.is_viewing_response(lane_id) then
        _step_state.snapshot_genesis(lane_id)
      end
      _step_state.apply_motif(lane_id)
    end
  end)

  params:add_number("drum_step_ratchet", "Ratchet", 1, 8, 1)
  params:set_action("drum_step_ratchet", function(value)
    local lane_id = get_focused_drums_lane()
    if not lane_id then return end
    local s = _step_state.get_active_step(lane_id, _step_state.get_selected_step(lane_id))
    if s then
      s.ratchet = value
      if not _step_state.is_viewing_response(lane_id) then
        _step_state.snapshot_genesis(lane_id)
      end
      _step_state.apply_motif(lane_id)
    end
  end)
end

------------------------------------------------------------------------
-- Section cycling and init
------------------------------------------------------------------------

DrumsHome.LANE_SECTIONS = {"DRUMS_TIMING", "DRUMS_MUTATION", "LANE_CONFIG"}

function DrumsHome.init()
  create_step_edit_params()

  local timing_screen = create_timing_screen()
  local step_screen = create_step_screen()
  local mutation_screen = create_mutation_screen()
  local call_screen = create_call_screen()
  local response_screen = create_response_screen()

  return {
    screen = step_screen,
    sections = {
      DRUMS_HOME = step_screen,
      DRUMS_TIMING = timing_screen,
      DRUMS_MUTATION = mutation_screen,
      DRUMS_CALL = call_screen,
      DRUMS_RESPONSE = response_screen,
    }
  }
end

return DrumsHome

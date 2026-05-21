-- home.lua
-- Dialogue screen sections. Lane button cycles Timing/Mutation/Config.
-- Long-press a step on the grid to open per-step editor (DIALOGUE_HOME).

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")
local musicutil = require('musicutil')
local theory = include("lib/modes/motif/core/theory")

local DialogueHome = {}

local _step_state = nil

function DialogueHome.set_step_state_ref(ref)
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

local function get_dialogue_lane()
  local focused = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(focused)
  if sub_mode == "dialogue" then return focused end
  return LaneMap.to_flat("dialogue", 1)
end

local function get_focused_dialogue_lane()
  local lane_id = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(lane_id)
  if sub_mode ~= "dialogue" then return nil end
  return lane_id
end

local function lane_label(lane_id)
  return "D" .. (lane_id - LaneMap.OFFSETS.dialogue)
end

------------------------------------------------------------------------
-- DIALOGUE_TIMING: division, gate, swing, probability
------------------------------------------------------------------------

local function create_timing_screen()
  local norns_ui = NornsUI.new({
    id = "DIALOGUE_TIMING",
    name = "Timing",
    description = "Step timing: division, gate, swing, probability.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_dialogue_lane()
    self.name = lane_label(lane_id) .. " Timing"
    self.params = {
      { id = "lane_" .. lane_id .. "_dialogue_base_octave" },
      { id = "lane_" .. lane_id .. "_dialogue_length" },
      { id = "lane_" .. lane_id .. "_dialogue_interval" },
      { id = "lane_" .. lane_id .. "_dialogue_modifier" },
      { id = "lane_" .. lane_id .. "_dialogue_gate_length", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_dialogue_swing", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_dialogue_probability", arc_multi_float = {10, 5, 1} },
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
-- DIALOGUE_HOME: per-step editor (note, octave, velocity, ratchet)
------------------------------------------------------------------------

local function create_step_screen()
  local norns_ui = NornsUI.new({
    id = "DIALOGUE_HOME",
    name = "Step",
    description = "Per-step note, octave, velocity, and ratchet.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_dialogue_lane()
    local step = _step_state.get_selected_step(lane_id)
    local s = _step_state.get_active_step(lane_id, step)
    local viewing_resp = _step_state.is_viewing_response(lane_id)
    local layer_label = viewing_resp and "Resp" or "Call"
    local step_label = layer_label .. " " .. step .. (s.active and " *" or " o")

    local default_note = _step_state.get_default_note(lane_id)
    local midi = s.note or default_note
    local note_idx, octave = midi_to_note_and_octave(midi)

    params:set("dialogue_step_note", note_idx, true)
    params:set("dialogue_step_octave", octave, true)
    params:set("dialogue_step_velocity", s.velocity, true)
    params:set("dialogue_step_ratchet", s.ratchet or 1, true)

    self.name = lane_label(lane_id) .. " " .. step_label
    self.params = {
      { id = "dialogue_step_note" },
      { id = "dialogue_step_octave" },
      { id = "dialogue_step_velocity" },
      { id = "dialogue_step_ratchet" },
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
-- DIALOGUE_MUTATION: mutation cycle and intensities
------------------------------------------------------------------------

local function create_mutation_screen()
  local norns_ui = NornsUI.new({
    id = "DIALOGUE_MUTATION",
    name = "Mutation",
    description = "Shape-preserving pattern mutation. Cycle sets the journey length, intensities control what changes.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_dialogue_lane()
    self.name = lane_label(lane_id) .. " Mutation"
    self.params = {
      { id = "lane_" .. lane_id .. "_dialogue_reseed" },
      { id = "lane_" .. lane_id .. "_dialogue_mutate_displace", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_dialogue_mutate_pitch", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_dialogue_mutate_density", arc_multi_float = {10, 5, 1} },
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
-- DIALOGUE_CALL: call config, loop count, edit toggle
------------------------------------------------------------------------

local function create_call_screen()
  local norns_ui = NornsUI.new({
    id = "DIALOGUE_CALL",
    name = "Call",
    description = "Call pattern settings. Edit Call locks the grid to show the call pattern.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_dialogue_lane()
    self.name = lane_label(lane_id) .. " Call"
    self.params = {
      { id = "lane_" .. lane_id .. "_dialogue_cr_active" },
      { id = "lane_" .. lane_id .. "_stage_1_loops" },
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
-- DIALOGUE_RESPONSE: response strategy, loop count, edit toggle
------------------------------------------------------------------------

local function create_response_screen()
  local norns_ui = NornsUI.new({
    id = "DIALOGUE_RESPONSE",
    name = "Response",
    description = "Response settings. The oracle generates responses by recombining fragments of the call pattern. Fidelity controls how much it recombines.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_dialogue_lane()
    self.name = lane_label(lane_id) .. " Response (Oracle)"
    self.params = {
      { id = "lane_" .. lane_id .. "_dialogue_extend_fidelity", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_dialogue_extend_entropy", arc_multi_float = {10, 5, 1} },
      { id = "lane_" .. lane_id .. "_stage_2_loops" },
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

local function apply_note_change()
  local lane_id = get_focused_dialogue_lane()
  if not lane_id then return end
  local s = _step_state.get_active_step(lane_id, _step_state.get_selected_step(lane_id))
  if not s then return end
  local midi = note_and_octave_to_midi(params:get("dialogue_step_note"), params:get("dialogue_step_octave"))
  local default_note = _step_state.get_default_note(lane_id)
  s.note = (midi == default_note) and nil or midi
  if not _step_state.is_viewing_response(lane_id) then
    _step_state.snapshot_genesis(lane_id)
  end
  _step_state.apply_motif(lane_id)
end

local function create_step_edit_params()
  params:add_group("dialogue_step_edit", "DRUM STEP EDIT", 4)

  params:add_number("dialogue_step_note", "Note", 1, 12, 1,
    function(param)
      local classes = get_scale_pitch_classes()
      local idx = math.max(1, math.min(param:get(), #classes))
      return NOTE_NAMES[classes[idx] + 1]
    end)
  params:set_action("dialogue_step_note", function(value)
    local classes = get_scale_pitch_classes()
    if value > #classes then params:set("dialogue_step_note", #classes, true); return end
    apply_note_change()
  end)

  params:add_number("dialogue_step_octave", "Octave", 0, 8, 4)
  params:set_action("dialogue_step_octave", function()
    apply_note_change()
  end)

  params:add_number("dialogue_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("dialogue_step_velocity", function(value)
    local lane_id = get_focused_dialogue_lane()
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

  params:add_number("dialogue_step_ratchet", "Ratchet", 1, 8, 1)
  params:set_action("dialogue_step_ratchet", function(value)
    local lane_id = get_focused_dialogue_lane()
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

DialogueHome.LANE_SECTIONS = {"DIALOGUE_TIMING", "DIALOGUE_MUTATION", "LANE_CONFIG"}

function DialogueHome.init()
  create_step_edit_params()

  local timing_screen = create_timing_screen()
  local step_screen = create_step_screen()
  local mutation_screen = create_mutation_screen()
  local call_screen = create_call_screen()
  local response_screen = create_response_screen()

  return {
    screen = step_screen,
    sections = {
      DIALOGUE_HOME = step_screen,
      DIALOGUE_TIMING = timing_screen,
      DIALOGUE_MUTATION = mutation_screen,
      DIALOGUE_CALL = call_screen,
      DIALOGUE_RESPONSE = response_screen,
    }
  }
end

return DialogueHome

-- home.lua
-- Drums screen sections. Lane button cycles Pattern/Timing/Voice.
-- Step tap goes to per-step editor (DRUMS_HOME).

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")

local DrumsHome = {}

local _step_grid = nil
local function get_step_grid()
  if not _step_grid then
    _step_grid = include("lib/modes/motif/types/drums/step_grid")
  end
  return _step_grid
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

---------------------------------------------------------------
-- DRUMS_PATTERN: length, hits, distribution, rotation
---------------------------------------------------------------
local function create_pattern_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_PATTERN",
    name = "Pattern",
    description = "Euclidean pattern shape: length, hits, distribution, rotation.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Pattern"
    self.params = {
      { id = "lane_" .. lane_id .. "_drum_length" },
      { id = "lane_" .. lane_id .. "_drum_hits" },
      { id = "lane_" .. lane_id .. "_drum_distribution" },
      { id = "lane_" .. lane_id .. "_drum_rotation" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

---------------------------------------------------------------
-- DRUMS_TIMING: division, gate, swing, probability
---------------------------------------------------------------
local function create_timing_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_TIMING",
    name = "Timing",
    description = "Step timing: division, gate length, swing, probability.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    self.name = lane_label(lane_id) .. " Timing"
    self.params = {
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

  return norns_ui
end

---------------------------------------------------------------
-- DRUMS_HOME: per-step editor (note/voltage, velocity, ratchet)
---------------------------------------------------------------
local function create_step_screen()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Step",
    description = "Per-step note, velocity, and ratchet.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    local StepGrid = get_step_grid()
    local step = StepGrid.selected_step
    local s = StepGrid.get_step(lane_id, step)
    local step_label = "Step " .. step .. (s.active and " *" or " o")

    local uses_cv = params:get("lane_" .. lane_id .. "_eurorack_active") == 1
      and params:get("lane_" .. lane_id .. "_cv_out") > 1

    params:set("drum_step_velocity", s.velocity, true)
    params:set("drum_step_ratchet", s.ratchet, true)

    self.name = lane_label(lane_id) .. " " .. step_label

    if uses_cv then
      local default_voltage = (params:get("lane_" .. lane_id .. "_drum_voice_note") - 12) / 12
      params:set("drum_step_voltage", s.voltage or default_voltage, true)
      self.params = {
        { id = "drum_step_voltage", arc_multi_float = {1.0, 0.1, 0.01} },
        { id = "drum_step_velocity" },
        { id = "drum_step_ratchet" },
      }
    else
      local lane_note = params:get("lane_" .. lane_id .. "_drum_voice_note")
      params:set("drum_step_note", s.note or lane_note, true)
      self.params = {
        { id = "drum_step_note" },
        { id = "drum_step_velocity" },
        { id = "drum_step_ratchet" },
      }
    end
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

---------------------------------------------------------------
-- Virtual params for per-step editing
---------------------------------------------------------------
local function create_step_edit_params()
  params:add_group("drum_step_edit", "DRUM STEP EDIT", 4)

  params:add_control("drum_step_voltage", "Step Voltage",
    controlspec.new(-5, 10, 'lin', 0.01, 4, "V"))
  params:set_action("drum_step_voltage", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local StepGrid = get_step_grid()
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.voltage = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)

  params:add_number("drum_step_note", "Step Note", 24, 96, 60)
  params:set_action("drum_step_note", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local StepGrid = get_step_grid()
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      local lane_note = params:get("lane_" .. lane_id .. "_drum_voice_note")
      s.note = (value == lane_note) and nil or value
      StepGrid.rebuild_motif(lane_id)
    end
  end)

  params:add_number("drum_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("drum_step_velocity", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local StepGrid = get_step_grid()
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.velocity = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)

  params:add_number("drum_step_ratchet", "Ratchet", 1, 8, 1)
  params:set_action("drum_step_ratchet", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
    local StepGrid = get_step_grid()
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.ratchet = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)
end

---------------------------------------------------------------
-- Sections the lane button cycles through
---------------------------------------------------------------
DrumsHome.LANE_SECTIONS = {"DRUMS_PATTERN", "DRUMS_TIMING", "LANE_CONFIG"}

function DrumsHome.init()
  create_step_edit_params()

  local pattern_screen = create_pattern_screen()
  local timing_screen = create_timing_screen()
  local step_screen = create_step_screen()

  return {
    screen = step_screen,
    sections = {
      DRUMS_HOME = step_screen,
      DRUMS_PATTERN = pattern_screen,
      DRUMS_TIMING = timing_screen,
    }
  }
end

return DrumsHome

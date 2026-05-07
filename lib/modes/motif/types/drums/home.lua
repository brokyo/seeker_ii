-- home.lua
-- Drums home screen: lane config + per-step velocity/ratchet for the selected step.
-- Tapping a step on the grid selects it and shows its config here.

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")

local DrumsHome = {}

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Drums",
    description = "Trigger step sequencer. Toggle steps on the grid, configure per-step velocity and ratchet here.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local StepGrid = include("lib/modes/motif/types/drums/step_grid")
    local step = StepGrid.selected_step
    local s = StepGrid.get_step(lane_id, step)
    local step_label = "Step " .. step .. (s.active and " ●" or " ○")

    -- Sync virtual params to the selected step's state
    params:set("drum_step_velocity", s.velocity, true)
    params:set("drum_step_ratchet", s.ratchet, true)

    self.name = step_label

    self.params = {
      { separator = true, title = "Pattern" },
      { id = "lane_" .. lane_id .. "_drum_steps" },
      { id = "lane_" .. lane_id .. "_drum_division" },
      { id = "lane_" .. lane_id .. "_drum_gate_length", arc_multi_float = {0.1, 0.05, 0.01} },
      { id = "lane_" .. lane_id .. "_drum_voice_note" },
      { separator = true, title = step_label },
      { id = "drum_step_velocity" },
      { id = "drum_step_ratchet" },
      { separator = true, title = "Euclidean" },
      { id = "lane_" .. lane_id .. "_drum_euclidean_fills" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

local function create_step_edit_params()
  -- Virtual params for editing the selected step's velocity and ratchet.
  -- These read/write to the step_state table, not to persistent params.
  local StepGrid = include("lib/modes/motif/types/drums/step_grid")

  params:add_group("drum_step_edit", "DRUM STEP EDIT", 2)

  params:add_number("drum_step_velocity", "Step Velocity", 1, 127, 100)
  params:set_action("drum_step_velocity", function(value)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local sub_mode = LaneMap.from_flat(lane_id)
    if sub_mode ~= "drums" then return end
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
    local s = StepGrid.get_step(lane_id, StepGrid.selected_step)
    if s then
      s.ratchet = value
      StepGrid.rebuild_motif(lane_id)
    end
  end)
end

function DrumsHome.init()
  create_step_edit_params()
  local screen = create_screen_ui()

  return { screen = screen }
end

return DrumsHome

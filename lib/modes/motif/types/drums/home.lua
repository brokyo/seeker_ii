-- home.lua
-- Drums per-step editor. Tap a step on the grid to edit its velocity and ratchet.

local NornsUI = include("lib/ui/base/norns_ui")
local LaneMap = include("lib/lanes/lane_map")

local DrumsHome = {}

local function get_drums_lane()
  local focused = _seeker.ui_state.get_focused_lane()
  local sub_mode = LaneMap.from_flat(focused)
  if sub_mode == "drums" then return focused end
  return LaneMap.to_flat("drums", 1)
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "DRUMS_HOME",
    name = "Drums",
    description = "Tap a step on the grid to edit velocity and ratchet.",
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    local lane_id = get_drums_lane()
    local StepGrid = include("lib/modes/motif/types/drums/step_grid")
    local step = StepGrid.selected_step
    local s = StepGrid.get_step(lane_id, step)
    local step_label = "Step " .. step .. (s.active and " *" or " o")

    params:set("drum_step_velocity", s.velocity, true)
    params:set("drum_step_ratchet", s.ratchet, true)

    local local_idx = lane_id - LaneMap.OFFSETS.drums
    self.name = "D" .. local_idx .. " " .. step_label

    self.params = {
      { id = "drum_step_velocity" },
      { id = "drum_step_ratchet" },
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
  return { screen = create_screen_ui() }
end

return DrumsHome

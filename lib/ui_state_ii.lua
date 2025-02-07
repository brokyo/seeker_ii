-- ui_state_ii.lua
local UIState = {}

-- Initial state
UIState.state = {
  focused_lane = 1,
  focused_stage = 1,
  current_section = "LANE"
}

function UIState.init()
  print("⎍ UI state tracking")
  return UIState
end

function UIState.set_focused_lane(lane_idx)
  if lane_idx == UIState.state.focused_lane then return end
  
  UIState.state.focused_lane = lane_idx
  print(string.format("⎍ Focused lane %d", lane_idx))
  
  -- Update UI
  _seeker.screen_ui.sections.LANE:update_focused_lane(lane_idx)
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_focused_stage(stage_idx)
  if stage_idx == UIState.state.focused_stage then return end
  
  UIState.state.focused_stage = stage_idx
  print(string.format("⎍ Focused stage %d", stage_idx))
  
  -- Update UI
  _seeker.screen_ui.sections.STAGE:update_focused_stage(stage_idx)
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_current_section(section_id)
  if section_id == UIState.state.current_section then return end
  
  UIState.state.current_section = section_id
  print(string.format("⎍ Current section: %s", section_id))
  
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

function UIState.get_focused_lane()
  return UIState.state.focused_lane
end

function UIState.get_focused_stage()
  return UIState.state.focused_stage
end

function UIState.get_current_section()
  return UIState.state.current_section
end

return UIState 
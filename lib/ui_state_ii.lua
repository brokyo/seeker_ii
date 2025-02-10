-- ui_state_ii.lua
local UIState = {}

-- Initial state
UIState.state = {
  focused_lane = 1,
  focused_stage = 1,
  current_section = "LANE",
  last_action_time = util.time()
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

function UIState.register_activity()
  UIState.state.last_action_time = util.time()
end

function UIState.key(n, z)
  UIState.register_activity()

  print("⎍ Key pressed", n, z)
  -- Handle global controls first
  if n == 1 and z == 1 then
    -- Toggle app visibility
    if _seeker.screen_ui then
      _seeker.screen_ui.state.app_on_screen = not _seeker.screen_ui.state.app_on_screen
      print("⎍ App visibility toggled")
      return
    end
  end
  
  -- Pass to screen UI if visible
  if _seeker.screen_ui and _seeker.screen_ui.state.app_on_screen then
    _seeker.screen_ui.key(n, z)
  end
end

function UIState.enc(n, d)
  UIState.register_activity()

  -- Pass to screen UI if visible
  if _seeker.screen_ui and _seeker.screen_ui.state.app_on_screen then
    _seeker.screen_ui.enc(n, d)
  end
end

return UIState 
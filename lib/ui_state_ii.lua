-- ui_state_ii.lua
local UIState = {}

-- Initial state
UIState.state = {
  focused_lane = 1,
  focused_stage = 1,
  current_section = "LANE",
  last_action_time = util.time(),
  long_press_in_progress = false,  -- Track if we're in a long press
  long_press_section = nil         -- Which section is being long pressed
}

function UIState.init()
  print("⎍ UI state tracking")
  return UIState
end

function UIState.set_focused_lane(lane_idx)
  if lane_idx == UIState.state.focused_lane then return end
  
  UIState.state.focused_lane = lane_idx
  
  -- Update UI
  _seeker.screen_ui.sections.LANE:update_focused_lane(lane_idx)
  _seeker.screen_ui.sections.MOTIF:update_focused_motif(lane_idx)
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_focused_stage(stage_idx)
  if stage_idx == UIState.state.focused_stage then return end
  
  UIState.state.focused_stage = stage_idx
  
  -- Update UI
  _seeker.screen_ui.sections.STAGE:update_focused_stage(stage_idx)
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_current_section(section_id)
  if section_id == UIState.state.current_section then return end
  
  -- Exit old section
  local old_section = _seeker.screen_ui.sections[UIState.state.current_section]
  if old_section then 
    old_section:exit()
  end
  
  UIState.state.current_section = section_id
  
  -- Enter new section
  local new_section = _seeker.screen_ui.sections[section_id]
  if new_section then
    new_section:enter()
  end
  
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

  -- print("⎍ Encoder moved", n, d)

  -- Pass to screen UI if visible
  if _seeker.screen_ui and _seeker.screen_ui.state.app_on_screen then
    _seeker.screen_ui.enc(n, d)
  end
end

-- Add new methods for long press tracking
function UIState.set_long_press_state(is_active, section_id)
  UIState.state.long_press_in_progress = is_active
  UIState.state.long_press_section = section_id
  _seeker.screen_ui.set_needs_redraw()
end

function UIState.is_long_press_active()
  return UIState.state.long_press_in_progress
end

function UIState.get_long_press_section()
  return UIState.state.long_press_section
end

return UIState 
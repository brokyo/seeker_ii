-- ui_state_ii.lua
local UIState = {}

-- Initial state
UIState.state = {
  focused_lane = 1,
  focused_stage = 1,
  current_section = "LANE",
  last_action_time = util.time(),
  long_press_in_progress = false,
  long_press_section = nil,
  recently_triggered = {},
  trigger_clocks = {},
  knob_recording_active = false
}



-- Constants
UIState.TRIGGER_VISUAL_DURATION = 0.5 -- Duration in seconds to show trigger feedback

function UIState.init()
  print("⎍ UI state tracking")
  return UIState
end

-- Methods for global trigger state tracking
function UIState.trigger_activated(param_id)
  -- Cancel any existing cleanup clock for this parameter
  if UIState.state.trigger_clocks[param_id] then
    clock.cancel(UIState.state.trigger_clocks[param_id])
  end
  
  -- Record activation time
  UIState.state.recently_triggered[param_id] = util.time()
  
  -- Schedule cleanup at exact expiration time
  UIState.state.trigger_clocks[param_id] = clock.run(function()
    -- Sleep exactly the visual duration
    clock.sleep(UIState.TRIGGER_VISUAL_DURATION)
    
    -- Remove the trigger state
    UIState.state.recently_triggered[param_id] = nil
    UIState.state.trigger_clocks[param_id] = nil
    
    -- Request redraw if available
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
  
  -- Request immediate redraw to show the activated trigger
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
  
  -- Trigger arc animation if arc is available
  if _seeker and _seeker.arc and _seeker.arc.animate_trigger then
    _seeker.arc.animate_trigger(param_id)
  end
end

function UIState.is_recently_triggered(param_id)
  return UIState.state.recently_triggered[param_id] ~= nil
end

function UIState.set_focused_lane(lane_idx)
  if lane_idx == UIState.state.focused_lane then return end
  
  UIState.state.focused_lane = lane_idx
  
  -- Update UI
  _seeker.screen_ui.sections.LANE:update_focused_lane(lane_idx)
  _seeker.screen_ui.sections.MOTIF:update_focused_motif(lane_idx)
  
  -- Rebuild create_motif parameters to show/hide duration based on new lane's motif state
  if _seeker.create_motif and _seeker.create_motif.screen then
    _seeker.create_motif.screen:rebuild_params()
  end
  
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_focused_stage(stage_idx)
  if stage_idx == UIState.state.focused_stage then return end
  
  UIState.state.focused_stage = stage_idx
  
  -- Update UI
  if _seeker.screen_ui.sections.STAGE then
    _seeker.screen_ui.sections.STAGE:update_focused_stage(stage_idx)
  end
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
  
  -- Check if knob recording is active and delegate to eurorack output component
  if UIState.state.knob_recording_active and n == 3 then
    if _seeker.eurorack_output then
      _seeker.eurorack_output.handle_encoder_input(d)
    end
    return
  end
  
  -- Otherwise, continue execution
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
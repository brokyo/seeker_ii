-- ui_state.lua
-- Centralized UI state management
local UIState = {}

-- Available sections and their configurations
UIState.sections = {
  TUNING = {
    id = "TUNING",
    name = "Tuning",
    icon = "⚘"
  },
  RECORDING = {
    id = "RECORDING",
    name = "Recording",
    icon = "⏺"
  },
  LANES = {
    id = "LANES",
    name = "Lanes",
    icon = "⌸"
  },
  MOTIF = {
    id = "MOTIF",
    name = "Motif",
    icon = "♪"
  },
  STAGES = {
    id = "STAGES",
    name = "Stages",
    icon = "◈"
  },
  TRANSFORMS = {
    id = "TRANSFORMS",
    name = "Transforms",
    icon = "⎊"
  }
}

-- Current UI state
UIState.state = {
  current_section = "LANE",
  focused_lane = 1,
  focused_stage = 1,
  selected_transform = 1,
  scroll_offset = 0,
  selected_index = 0
}

-- Callbacks that will be called when state changes
UIState.callbacks = {
    on_lane_focus_changed = {},
    on_stage_focus_changed = {}
}

-- Register a callback for when lane focus changes
function UIState.on_lane_focus_changed(callback)
    table.insert(UIState.callbacks.on_lane_focus_changed, callback)
end

-- Register a callback for when stage focus changes  
function UIState.on_stage_focus_changed(callback)
    table.insert(UIState.callbacks.on_stage_focus_changed, callback)
end

-- Section change handlers
UIState.section_handlers = {}

-- Register a handler for section changes
function UIState.register_section_handler(handler)
  table.insert(UIState.section_handlers, handler)
end

-- Change the current section
function UIState.change_section(section_id)
  if UIState.sections[section_id] then
    UIState.state.current_section = section_id
    UIState.state.selected_index = 0  -- Reset selection
    UIState.state.scroll_offset = 0   -- Reset scroll
    
    -- Notify all registered handlers
    for _, handler in ipairs(UIState.section_handlers) do
      handler(section_id)
    end
    
    -- Request redraws
    if _seeker then
      _seeker.update_ui_state()
    end
  end
end

-- Get section from grid coordinates
function UIState.get_section_from_grid(x, y)
  for id, section in pairs(UIState.sections) do
    if section.grid_x == x and section.grid_y == y then
      return id
    end
  end
  return nil
end

-- Get current section config
function UIState.get_current_section()
  return UIState.sections[UIState.state.current_section]
end

function UIState.set_focused_lane(lane_idx)
    if lane_idx == UIState.state.focused_lane then return end
    UIState.state.focused_lane = lane_idx
    print(string.format("⎍ Focused lane %d", lane_idx))
    
    -- Call all registered callbacks
    for _, callback in ipairs(UIState.callbacks.on_lane_focus_changed) do
        callback(lane_idx)
    end
    
    -- Trigger redraws in both UIs
    if _seeker.grid_ui then _seeker.grid_ui.set_needs_redraw() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

function UIState.get_focused_lane()
    return UIState.state.focused_lane
end

function UIState.set_focused_stage(stage_idx)
    if stage_idx == UIState.state.focused_stage then return end
    UIState.state.focused_stage = stage_idx
    print(string.format("⎍ Focused stage %d", stage_idx))
    
    -- Call all registered callbacks
    for _, callback in ipairs(UIState.callbacks.on_stage_focus_changed) do
        callback(stage_idx)
    end
    
    -- Trigger redraws in both UIs
    if _seeker.grid_ui then _seeker.grid_ui.set_needs_redraw() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

function UIState.get_focused_stage()
    return UIState.state.focused_stage
end

return UIState 
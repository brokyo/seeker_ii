local UIState = {}

UIState.state = {
    focused_lane = 1,
    focused_stage = 1
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
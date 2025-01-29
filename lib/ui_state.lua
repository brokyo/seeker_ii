local UIState = {}

UIState.state = {
    focused_lane = 1,
    focused_stage = 1
}

function UIState.set_focused_lane(lane_idx)
    UIState.state.focused_lane = lane_idx
    print(string.format("⎍ Focused lane %d", lane_idx))
    -- Trigger redraws in both UIs
    if _seeker.grid_ui then _seeker.grid_ui.set_needs_redraw() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

function UIState.get_focused_lane()
    return UIState.state.focused_lane
end

function UIState.set_focused_stage(stage_idx)
    UIState.state.focused_stage = stage_idx
    print(string.format("⎍ Focused stage %d", stage_idx))
    -- Trigger redraws in both UIs
    if _seeker.grid_ui then _seeker.grid_ui.set_needs_redraw() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

function UIState.get_focused_stage()
    return UIState.state.focused_stage
end

return UIState 
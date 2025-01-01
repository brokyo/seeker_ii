--[[
  params_manager.lua
  Parameter visibility and UI management for Seeker II

  Handles:
  - Parameter group visibility control
  - Channel-specific parameter grouping
  - Behavior-based parameter visibility updates
]]--

-- Handles parameter visibility and UI-related parameter behavior

local params_manager = {}

-- Parameter groups for each behavior
local PULSE_PARAMS = {}
local STRUM_PARAMS = {
    "strum_header_",
    "strum_duration_",
    "strum_pulses_",
    "strum_clustering_",
    "strum_variation_"
}
local BURST_PARAMS = {
    "burst_header_",
    "burst_window_",
    "burst_style_"
}

function params_manager.hide_params(channel_id, param_list)
    for _, param_base in ipairs(param_list) do
        local param_id = param_base .. channel_id
        if params:lookup_param(param_id) then
            params:hide(param_id)
        end
    end
end

function params_manager.show_params(channel_id, param_list)
    for _, param_base in ipairs(param_list) do
        local param_id = param_base .. channel_id
        if params:lookup_param(param_id) then
            params:show(param_id)
        end
    end
end

function params_manager.update_behavior_visibility(channel_id, behavior)
    -- Hide all behavior-specific params first
    params_manager.hide_params(channel_id, STRUM_PARAMS)
    params_manager.hide_params(channel_id, BURST_PARAMS)
    
    -- Show the params for the selected behavior
    if behavior == 2 then  -- Strum
        params_manager.show_params(channel_id, STRUM_PARAMS)
    elseif behavior == 3 then  -- Burst
        params_manager.show_params(channel_id, BURST_PARAMS)
    end
    
    -- Force menu rebuild to reflect changes
    _menu.rebuild_params()
end

return params_manager 
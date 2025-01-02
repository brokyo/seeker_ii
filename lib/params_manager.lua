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
    -- Hide/show strum parameters
    local strum_params = {
        "strum_duration_" .. channel_id,
        "strum_pulses_" .. channel_id,
        "strum_clustering_" .. channel_id,
        "strum_variation_" .. channel_id
    }
    
    -- Hide/show burst parameters
    local burst_params = {
        "burst_window_" .. channel_id,
        "burst_style_" .. channel_id
    }
    
    -- First hide all parameters
    for _, param in ipairs(strum_params) do
        params:hide(param)
    end
    for _, param in ipairs(burst_params) do
        params:hide(param)
    end
    
    -- Then show only the relevant ones based on behavior
    if behavior == 2 then  -- Strum mode
        for _, param in ipairs(strum_params) do
            params:show(param)
        end
    elseif behavior == 3 then  -- Burst mode
        for _, param in ipairs(burst_params) do
            params:show(param)
        end
    end
    
    -- Force menu rebuild to reflect changes
    _menu.rebuild_params()
end

function params_manager.update_duration_visibility(channel_id, mode)
    -- Fixed mode parameters
    local fixed_params = {}
    
    -- Pattern mode parameters
    local pattern_params = {
        "duration_pattern_header_" .. channel_id,
        "duration_pattern_length_" .. channel_id,
        "duration_pattern_shape_" .. channel_id,
        "duration_min_" .. channel_id,
        "duration_max_" .. channel_id
    }
    
    -- Common parameters (shown in both modes)
    local common_params = {
        "duration_variance_" .. channel_id
    }
    
    -- Hide all parameters first
    for _, param in ipairs(fixed_params) do
        if params:lookup_param(param) then
            params:hide(param)
        end
    end
    for _, param in ipairs(pattern_params) do
        if params:lookup_param(param) then
            params:hide(param)
        end
    end
    
    -- Show common parameters
    for _, param in ipairs(common_params) do
        if params:lookup_param(param) then
            params:show(param)
        end
    end
    
    -- Show mode-specific parameters
    if mode == 1 then  -- Fixed mode
        for _, param in ipairs(fixed_params) do
            if params:lookup_param(param) then
                params:show(param)
            end
        end
    else  -- Pattern mode
        for _, param in ipairs(pattern_params) do
            if params:lookup_param(param) then
                params:show(param)
            end
        end
    end
    
    -- Force menu rebuild to reflect changes
    _menu.rebuild_params()
end

return params_manager 
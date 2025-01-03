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

-- Add prefix to all parameter IDs to avoid collisions
params_manager.PARAM_PREFIX = "sk2_"

-- Helper function to safely get parameter values with error logging
params_manager.safe_get_param = function(id)
    local success, param = pcall(function() return params:lookup_param(id) end)
    if not success or param == nil then
        print("ERROR: Attempted to access nil parameter: " .. id)
        return nil
    end
    return params:get(id)
end

-- Helper function to safely set parameter values with error logging
params_manager.safe_set_param = function(id, value)
    local success, param = pcall(function() return params:lookup_param(id) end)
    if not success or param == nil then
        print("ERROR: Attempted to set nil parameter: " .. id)
        return false
    end
    params:set(id, value)
    return true
end

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

function params_manager.update_behavior_visibility(channel_id, value)
    -- Get parameter IDs for this channel
    local strum_header = "strum_header_" .. channel_id
    local strum_duration = "strum_duration_" .. channel_id
    local strum_pulses = "strum_pulses_" .. channel_id
    local strum_clustering = "strum_clustering_" .. channel_id
    local strum_variation = "strum_variation_" .. channel_id
    
    local burst_header = "burst_header_" .. channel_id
    local burst_window = "burst_window_" .. channel_id
    local burst_style = "burst_style_" .. channel_id
    
    -- Hide all behavior-specific parameters first
    params:hide(strum_header)
    params:hide(strum_duration)
    params:hide(strum_pulses)
    params:hide(strum_clustering)
    params:hide(strum_variation)
    
    params:hide(burst_header)
    params:hide(burst_window)
    params:hide(burst_style)
    
    -- Show only the parameters for the selected behavior
    if value == 2 then  -- Strum
        params:show(strum_header)
        params:show(strum_duration)
        params:show(strum_pulses)
        params:show(strum_clustering)
        params:show(strum_variation)
    elseif value == 3 then  -- Burst
        params:show(burst_header)
        params:show(burst_window)
        params:show(burst_style)
    end
    
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
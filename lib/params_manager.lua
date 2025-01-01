-- params_manager.lua
-- Handles parameter visibility and UI-related parameter behavior

local params_manager = {}

-- Parameter group visibility helpers
function params_manager.show_params(param_ids)
    for _, id in ipairs(param_ids) do
        params:show(id)
    end
end

function params_manager.hide_params(param_ids)
    for _, id in ipairs(param_ids) do
        params:hide(id)
    end
end

-- Channel-specific parameter groups
function params_manager.get_strum_params(channel_id)
    return {
        "strum_header_" .. channel_id,
        "strum_duration_" .. channel_id,
        "strum_pulses_" .. channel_id,
        "strum_clustering_" .. channel_id,
        "strum_variation_" .. channel_id
    }
end

function params_manager.get_burst_params(channel_id)
    return {
        "burst_header_" .. channel_id,
        "burst_window_" .. channel_id,
        "burst_count_" .. channel_id,
        "burst_distribution_" .. channel_id
    }
end

-- Update visibility based on behavior
function params_manager.update_behavior_visibility(channel_id, behavior)
    -- Hide all behavior-specific params first
    params_manager.hide_params(params_manager.get_strum_params(channel_id))
    params_manager.hide_params(params_manager.get_burst_params(channel_id))
    
    -- Show params based on selected behavior
    if behavior == 2 then  -- Strum
        params_manager.show_params(params_manager.get_strum_params(channel_id))
    elseif behavior == 3 then  -- Burst
        params_manager.show_params(params_manager.get_burst_params(channel_id))
    end
    
    -- Rebuild menu to reflect changes
    _menu.rebuild_params()
end

return params_manager 
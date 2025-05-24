-- stage_config.lua
-- Configure stage-based motif transformations

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")
local transforms = include("lib/transforms")

local StageConfig = {}
StageConfig.__index = StageConfig

-- Use transform UI names directly from transforms.lua
local transform_types = transforms.ui_names

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_transform_stage", "Stage Transform Config " .. lane_idx, 53)
        params:add_number("lane_" .. lane_idx .. "_config_stage", "Configure Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_config_stage", function(value)
            _seeker.ui_state.set_focused_stage(value)
            _seeker.stage_config.screen:rebuild_params()
            _seeker.screen_ui.set_needs_redraw()
        end)

        for stage_idx = 1, 4 do
            params:add_option("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, "Transform Type", transform_types, 1)
            params:set_action("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, function(value)
                _seeker.stage_config.screen:rebuild_params()
                _seeker.screen_ui.set_needs_redraw()
            end)

            -- Overdub Filter Params
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode", "Filter Mode", {"Up to", "Only", "Except"}, 1)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round", "Filter Round", 1, 10, 1)

            -- Harmonize Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance", "Sub Octave Chance", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume", "Sub Octave Volume", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance", "Fifth Above Chance", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume", "Fifth Above Volume", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance", "Octave Above Chance", 0, 100, 50, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume", "Octave Above Volume", 0, 100, 50, function(param) return param.value .. "%" end)

            -- Transpose Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount", "Transpose Amount", -12, 12, 1)

            -- Rotate Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount", "Rotate Amount", -12, 12, 1)

            -- Skip Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_interval", "Skip Interval", 2, 8, 2)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_offset", "Skip Offset", 0, 7, 0)

            -- Ratchet Params  
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_chance", "Ratchet Chance", 0, 100, 30, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_max_repeats", "Max Repeats", 1, 8, 3)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_timing", "Timing Division", 2, 8, 4)

            -- Stage Config
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif", "Reset Motif", {"No", "Yes"}, 2)
        end
    end
end

local function create_screen_ui()
    local norns_ui = NornsUI.new({
        id = "STAGE_CONFIG",
        name = "Stage Config [WIP]",
        description = "Change playback behavior",
        params = {
            { separator = true, title = "Stage Config" },
        }
    })
    
    -- Preserve the logic from the original enter method on the NornsUI instance
    local original_enter = norns_ui.enter

    -- And then add custom logic
    norns_ui.enter = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = _seeker.ui_state.get_focused_stage()
        print("Configuring Lane " .. lane_idx .. ", Stage " .. stage_idx)

        -- Build a dynamic parameter table based on current lane and stage
        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Config" },
            { id = "lane_" .. lane_idx .. "_config_stage"},
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif"}
        }
        
        -- Update the UI with the new parameter table
        self.params = param_table
        
        -- End by calling the original enter method
        original_enter(self)
        
        -- Rebuild params to show transform-specific parameters
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = _seeker.ui_state.get_focused_stage()
        
        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Config" },
            { id = "lane_" .. lane_idx .. "_config_stage"},
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif"}
        }
        
        -- Get the current transform type and add its specific parameters
        local transform_type = params:string("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)
        
        -- Add specific parameters based on transform type
        if transform_type == "None" then
        elseif transform_type == "Overdub Filter" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Overdub Filter", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Overdub Filter", operator = "="}}
            })
        elseif transform_type == "Harmonize" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Harmonize", operator = "="}}
            })
        elseif transform_type == "Transpose" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Transpose", operator = "="}}
            })
        elseif transform_type == "Rotate" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Rotate", operator = "="}}
            })
        elseif transform_type == "Skip" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_interval",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Skip", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_skip_offset", 
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Skip", operator = "="}}
            })
        elseif transform_type == "Ratchet" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Ratchet", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_max_repeats",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Ratchet", operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_timing",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = "Ratchet", operator = "="}}
            })
        elseif transform_type == "Reverse" then

        end
        
        -- Update the UI with the new parameter table
        self.params = param_table
    end

    return norns_ui
end

local function create_grid_ui()
    return GridUI.new({
        id = "STAGE_CONFIG",
        layout = {
            x = 4,
            y = 7,
            width = 1,
            height = 1
        }
    })
end

function StageConfig.enter(component)
    print("StageConfig.enter called")
    -- Call the original enter method
    component.screen:enter()
    
    -- Add custom enter logic here
    print("StageConfig entered")
    
    -- Example of custom logic you might want to add:
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    print("Configuring Lane " .. lane_idx .. ", Stage " .. stage_idx)
    
    -- adjust stage parameters based on current selection:
    params:set("lane_" .. lane_idx .. "_config_stage", stage_idx)
end

function StageConfig.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    return component
end

return StageConfig
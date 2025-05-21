-- stage_config.lua
-- Configure stage-based motif transformations

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local StageConfig = {}
StageConfig.__index = StageConfig

local transform_types = {"None", "Overdub Filter", "Harmonize", "Transpose", "Rotate", "Ratchet"}

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
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance", "Sub Octave Chance", 0, 100, 0, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume", "Sub Octave Volume", 0, 100, 0, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance", "Fifth Above Chance", 0, 100, 0, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume", "Fifth Above Volume", 0, 100, 0, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance", "Octave Above Chance", 0, 100, 0, function(param) return param.value .. "%" end)
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume", "Octave Above Volume", 0, 100, 0, function(param) return param.value .. "%" end)

            -- Transpose Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount", "Transpose Amount", -12, 12, 1)

            -- Rotate Params
            params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount", "Rotate Amount", -12, 12, 1)
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
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx }
        }
        
        -- Update the UI with the new parameter table
        self.params = param_table
        
        -- End by calling the original enter method
        original_enter(self)
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = _seeker.ui_state.get_focused_stage()
        print("Configuring Lane " .. lane_idx .. ", Stage " .. stage_idx)

        -- Build a dynamic parameter table based on current lane and stage
        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Config" },
            { id = "lane_" .. lane_idx .. "_config_stage"},
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx }
        }
        
        -- Get the current transform type
        local transform_type_idx = params:get("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)
        local transform_type = params:string("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)
        
        -- Add specific parameters based on transform type
        if transform_type == "None" then
        elseif transform_type == "Overdub Filter" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[2], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[2], operator = "="}}
            })
        elseif transform_type == "Harmonize" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_sub_octave_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_fifth_above_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_chance",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_octave_above_volume",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[3], operator = "="}}
            })
        elseif transform_type == "Transpose" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[4], operator = "="}}
            })
        elseif transform_type == "Rotate" then
            table.insert(param_table, {
                id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount",
                view_conditions = {{id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, value = transform_types[5], operator = "="}}
            })
        elseif transform_type == "Ratchet" then
            -- Add ratchet parameters when implemented
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
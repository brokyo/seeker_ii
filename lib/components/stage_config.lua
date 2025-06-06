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

-- Local state for stage configuration
-- Solves some UI problems with stage config params being overridden by global stage change
local config_state = {
    config_stage = 1
}

local function create_params()
    for lane_idx = 1, _seeker.num_lanes do
        params:add_group("lane_" .. lane_idx .. "_transform_stage", "Stage Transform Config " .. lane_idx, 54)
        params:add_number("lane_" .. lane_idx .. "_config_stage", "Configure Stage", 1, 4, 1)
        params:set_action("lane_" .. lane_idx .. "_config_stage", function(value)
            -- Update local config state instead of global focused stage
            config_state.config_stage = value
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
            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif", "Reset Motif", {"Yes", "No"}, 1)
            params:set_action("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif", function(value)
                if _seeker.lanes[lane_idx] then
                    _seeker.lanes[lane_idx]:sync_stage_from_params(stage_idx)
                end
            end)

            params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute", "Mute", {"Yes", "No"}, 2)
            params:set_action("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute", function(value)
                if _seeker.lanes[lane_idx] then
                    _seeker.lanes[lane_idx]:sync_stage_from_params(stage_idx)
                end
            end)
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
        local stage_idx = config_state.config_stage
        print("Configuring Lane " .. lane_idx .. ", Stage " .. stage_idx)

        -- Build a dynamic parameter table based on current lane and stage
        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Config" },
            { id = "lane_" .. lane_idx .. "_config_stage"},
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif"},
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute"}
        }
        
        -- Update the UI with the new parameter table
        self.params = param_table
        
        -- Set the config stage param to match our local state
        params:set("lane_" .. lane_idx .. "_config_stage", config_state.config_stage)
        
        -- End by calling the original enter method
        original_enter(self)
        
        -- Rebuild params to show transform-specific parameters
        self:rebuild_params()
    end

    norns_ui.rebuild_params = function(self)
        local lane_idx = _seeker.ui_state.get_focused_lane()
        local stage_idx = config_state.config_stage
        
        local param_table = {
            { separator = true, title = "Stage " .. stage_idx .. " Config" },
            { id = "lane_" .. lane_idx .. "_config_stage"},
            { id = "lane_" .. lane_idx .. "_transform_stage_" .. stage_idx },
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_reset_motif"},
            { id = "lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_mute"}
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
    local grid_ui = GridUI.new({
        id = "STAGE_CONFIG",
        layout = {
            x = 4,
            y = 7,
            width = 1,
            height = 1
        }
    })
    
    -- Add blink state tracking
    grid_ui.blink_state = {
        blink_until = nil,
        stage_number = nil
    }
    
    -- Blink timing configuration - all in one place
    grid_ui.blink_config = {
        on_duration = 0.1,      -- 100ms on
        off_duration = 0.1,     -- 100ms off  
        inter_blink_pause = 0.1 -- 100ms between blinks
    }
    
    -- Method to trigger blink from outside (called from lane loop starts)
    function grid_ui:trigger_stage_blink(stage_idx)
        -- Calculate total duration for the number of blinks using config
        local cycle_duration = self.blink_config.on_duration + self.blink_config.off_duration + self.blink_config.inter_blink_pause
        local total_duration = (stage_idx * cycle_duration) - self.blink_config.inter_blink_pause -- Remove last pause
        
        self.blink_state.blink_until = util.time() + total_duration
        self.blink_state.stage_number = stage_idx
        self.blink_state.start_time = util.time()
    end
    
    -- Override draw method to handle blinking
    function grid_ui:draw(layers)
        local x = self.layout.x
        local y = self.layout.y
        local brightness = GridConstants.BRIGHTNESS.LOW
        
        -- Check if we should blink
        if self.blink_state.blink_until and util.time() < self.blink_state.blink_until then
            local elapsed = util.time() - self.blink_state.start_time
            local stage_number = self.blink_state.stage_number or 1
            
            -- Use centralized blink configuration
            local blink_on_duration = self.blink_config.on_duration
            local blink_off_duration = self.blink_config.off_duration
            local inter_blink_pause = self.blink_config.inter_blink_pause
            local cycle_duration = blink_on_duration + blink_off_duration + inter_blink_pause
            
            -- Determine which blink we're in
            local current_blink = math.floor(elapsed / cycle_duration) + 1
            
            if current_blink <= stage_number then
                -- We're within a valid blink
                local blink_position = elapsed % cycle_duration
                
                if blink_position < blink_on_duration then
                    -- ON phase
                    brightness = GridConstants.BRIGHTNESS.MEDIUM
                else
                    -- OFF phase or inter-blink pause
                    brightness = GridConstants.BRIGHTNESS.LOW
                end
            else
                -- All blinks complete
                brightness = GridConstants.BRIGHTNESS.LOW
            end
        else
            -- Normal brightness when not blinking
            brightness = GridConstants.BRIGHTNESS.LOW
        end
        
        layers.ui[x][y] = brightness
    end
    
    return grid_ui
end

function StageConfig.enter(component)
    print("StageConfig.enter called")
    -- Call the original enter method
    component.screen:enter()
    
    -- Add custom enter logic here
    print("StageConfig entered")
    
    -- Initialize local config stage with current global focused stage
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local current_global_stage = _seeker.ui_state.get_focused_stage()
    config_state.config_stage = current_global_stage
    
    print("Configuring Lane " .. lane_idx .. ", Stage " .. config_state.config_stage)
    
    -- Sync the config stage param with our local state
    params:set("lane_" .. lane_idx .. "_config_stage", config_state.config_stage)
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
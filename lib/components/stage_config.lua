-- stage_config.lua
-- Configure stage-based motif transformations

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local StageConfig = {}
StageConfig.__index = StageConfig

local instance = nil

function StageConfig.init()
    if instance then print("0: Returning Instance") return instance end
    print("0: Creating Instance")

    instance = {

        --------------------------------
        -- State management
        --------------------------------
        state = {
            focused_lane_idx = 1,
            focused_stage_idx = 1,
            transform_type = "None",
            transform_index = 1
        },

        update_state = function(self, updates)
            for key, value in pairs(updates) do
                self.state[key] = value
            end

            -- Trigger any necessary UI updates
            if self.screen and self.screen.instance then
                self.screen.instance.params = self.screen.build_params()
                
                -- Force redraw since params changed
                if _seeker.screen_ui then
                    print("2: UPDATE STATE | NEEDS REDRAW")
                    _seeker.screen_ui.set_needs_redraw()
                    self.screen.instance:update_dynamic_params(self.screen.build_params())
                    self.screen.update()
                end
            end
        end,

        get_state = function(self)
            return self.state
        end,

        --------------------------------
        -- Params management 
        -- Params interface used by @params_manager_ii for loading core data
        --------------------------------
        params = {
            create = function()
                for lane_idx = 1, _seeker.num_lanes do
                    params:add_group("lane_" .. lane_idx .. "_transform_stage", "Stage Transform Config " .. lane_idx, 53)
                    params:add_number("lane_" .. lane_idx .. "_config_stage", "Configure Stage", 1, 4, 1)
                    
                    -- Add action to update state when config_stage changes
                    params:set_action("lane_" .. lane_idx .. "_config_stage", function(value)
                        if lane_idx == instance:get_state().focused_lane_idx then
                            instance:update_state({ focused_stage_idx = value })
                        end
                    end)

                    for stage_idx = 1, 4 do
                        params:add_option("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, "Transform Type", {"None", "Overdub Filter", "Harmonize", "Transpose", "Rotate", "Ratchet"}, 1)
                        
                        -- Add action to update state when transform type changes
                        params:set_action("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx, function(value)
                            if lane_idx == instance:get_state().focused_lane_idx and 
                               stage_idx == instance:get_state().focused_stage_idx then
                                local new_transform = params:string("lane_" .. lane_idx .. "_transform_stage_" .. stage_idx)
                                instance:update_state({ transform_type = new_transform })
                                instance:update_state({ transform_index = value })
                            end
                        end)

                        -- Overdub Filter Params
                        params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_mode", "Filter Mode", {"Up to", "Only", "Except"}, 1)
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_overdub_filter_round", "Filter Round", 1, 10, 1)

                        -- Harmonize Params
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "oct_below_chance", 0, 100, 0, "%" )
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "oct_below_volume", 0, 100, 0, "%" )
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "fifth_above_chance", 0, 100, 0, "%" )
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "fifth_above_volume", 0, 100, 0, "%" )
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "oct_above_chance", 0, 100, 0, "%" )
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_harmonize_" .. "oct_above_volume", 0, 100, 0, "%" )

                        -- Transpose Params
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_transpose_amount", "Transpose Amount", -12, 12, 1)

                        -- Rotate Params
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_rotate_amount", "Rotate Amount", -12, 12, 1)

                        -- Ratchet Params
                        params:add_number("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_count", "Ratchet Count", -12, 12, 1)
                        params:add_option("lane_" .. lane_idx .. "_stage_" .. stage_idx .. "_ratchet_spacing", "Ratchet Spacing", {"1/32", "1/16", "1/8", "1/4", "1/2", "1", "2"}, 1)
                    end
                end
            end
        },

        -- Screen interface used by @screen_iii
        screen = {
            instance = NornsUI.new({
                id = "STAGE_CONFIG",
                name = "Stage Config",
                description = "Configure stage-based motif transformations",
                params = {
                    { separator = true, name = "Stage Config" }
                }
            }),

            -- Helper function to build params
            build_params = function()
                local state = instance:get_state()
                local params_list = {
                    { separator = true, name = "Stage Config" },
                    { id = "lane_" .. state.focused_lane_idx .. "_config_stage", name = "Configure Stage" },
                    { id = "lane_" .. state.focused_lane_idx .. "_transform_stage_" .. state.focused_stage_idx, 
                      name = "Transform Type"}
                }

                -- Based on transform type, add relevant parameters
                local lane = state.focused_lane_idx
                local stage = state.focused_stage_idx
                
                -- Add parameters based on transform type
                if state.transform_type == "Overdub Filter" then
                    table.insert(params_list, { separator = true, name = "Overdub Filter Settings" })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_overdub_filter_mode", 
                        name = "Filter Mode" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_overdub_filter_round", 
                        name = "Filter Round" 
                    })
                elseif state.transform_type == "Harmonize" then
                    table.insert(params_list, { separator = true, name = "Harmonize Settings" })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_oct_below_chance", 
                        name = "Oct Below Chance" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_oct_below_volume", 
                        name = "Oct Below Volume" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_fifth_above_chance", 
                        name = "Fifth Above Chance" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_fifth_above_volume", 
                        name = "Fifth Above Volume" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_oct_above_chance", 
                        name = "Oct Above Chance" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_harmonize_oct_above_volume", 
                        name = "Oct Above Volume" 
                    })
                elseif state.transform_type == "Transpose" then
                    table.insert(params_list, { separator = true, name = "Transpose Settings" })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_transpose_amount", 
                        name = "Transpose Amount" 
                    })
                elseif state.transform_type == "Rotate" then
                    table.insert(params_list, { separator = true, name = "Rotate Settings" })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_rotate_amount", 
                        name = "Rotate Amount" 
                    })
                elseif state.transform_type == "Ratchet" then
                    table.insert(params_list, { separator = true, name = "Ratchet Settings" })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_ratchet_count", 
                        name = "Ratchet Count" 
                    })
                    table.insert(params_list, { 
                        id = "lane_" .. lane .. "_stage_" .. stage .. "_ratchet_spacing", 
                        name = "Ratchet Spacing" 
                    })
                end
                
                print("1: PARAMS BUILT " .. #params_list)
                return params_list
            end,

            update = function()
                print("3: UPDATE")
                -- -- Check if parameter value has changed from what we have in state
                -- local lane = instance:get_state().focused_lane_idx
                -- local stage = instance:get_state().focused_stage_idx
                -- local param_value = params:get("lane_" .. lane .. "_transform_stage_" .. stage)
                -- local transform_types = {"None", "Overdub Filter", "Harmonize", "Transpose", "Rotate", "Ratchet"}
                -- local current_transform = transform_types[param_value]
                
                -- if current_transform ~= instance:get_state().transform_type then
                --     print("Update detected transform change to: " .. current_transform)
                --     instance:update_state({ transform_type = current_transform })
                -- end
            end,

            -- This build function is needed by screen_iii.lua
            -- Ostensible screen's init method
            build = function()
                print("BUILD")
                -- Update state with focused lane
                local focused_lane_idx = _seeker.ui_state.get_focused_lane()
                local focused_stage_idx = params:get("lane_" .. focused_lane_idx .. "_config_stage")
                
                -- Get current transform type from parameter
                local transform_value = params:get("lane_" .. focused_lane_idx .. "_transform_stage_" .. focused_stage_idx)
                local transform_types = {"None", "Overdub Filter", "Harmonize", "Transpose", "Rotate", "Ratchet"}
                local transform_type = transform_types[transform_value]
                
                print("Building screen with lane " .. focused_lane_idx .. " stage " .. focused_stage_idx .. " transform " .. transform_type)
                
                instance:update_state({ 
                    focused_lane_idx = focused_lane_idx,
                    focused_stage_idx = focused_stage_idx,
                    transform_type = transform_type
                })
                
                -- Update screen params
                -- instance.screen.instance.params = instance.screen.build_params()
                
                return instance.screen.instance
            end
        },

        -- Grid interface used by @grid_ii
        grid = GridUI.new({
            id = "STAGE_CONFIG",
            layout = {
                x = 4,
                y = 7,
                width = 1,
                height = 1
            }
        })
    }
    
    return instance
end

return StageConfig
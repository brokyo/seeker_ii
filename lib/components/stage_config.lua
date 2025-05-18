-- stage_config.lua
-- Configure stage-based motif transformations

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local StageConfig = {}
StageConfig.__index = StageConfig

local instance = nil

function StageConfig.init()
    if instance then return instance end

    instance = {
        -- Params interface used by @params_manager_ii for loading core data
        params = {
            create = function()
                -- Using custom params
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

            -- This build function is needed by screen_iii.lua
            build = function()
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
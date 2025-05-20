-- w_tape.lua
-- Self-contained component for WTape functionality.

local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
-- local GridConstants = include("lib/grid_constants") -- Not needed for minimal version

local WTape = {}
WTape.__index = WTape

function create_params()
    params:add_group("wtape", "WTAPE", 4)
    params:add_option("wtape_active", "w/Tape Active", {"False", "True"}, 1)
    params:set_action("wtape_active", function(value)
        if value == 1 then
            
        else

        end
    end)

    -- WTape Config | Only show when wtape_active is true
    params:add_binary("wtape_is_recording", "Is Recording", "toggle", 0)
    params:set_action("wtape_is_recording", function(value)
        if value == 1 then
            -- Start recording
            -- Set start time
            print("WTape is recording")
        else
            -- Stop recording
            -- Set loop end time
            -- Set loop mode
            print("WTape is not recording")
        end
    end)

    params:add_control("wtape_speed", "Speed", controlspec.new(-4, 4, 'lin', 0.25))
    params:set_action("wtape_speed", function(value)
        -- Do some stuff with ii
        print("WTape speed: " .. value)
    end)

    params:add_option("wtape_play_direction", "Play Direction", {"Forward", "Reverse"}, 1)
    params:set_action("wtape_play_direction", function(value)
        print("WTape play direction: " .. value)
    end)
end

function create_screen_ui()
    return NornsUI.new({
        id = "WTAPE",
        name = "WTape",
        description = "WTape test component.",
        params = {
            { separator = true, title = "WTape" },
            { id = "wtape_active" },
            { id = "wtape_is_recording", view_conditions = {
                { id = "wtape_active", operator = "=", value = "True"} 
            }},
            { id = "wtape_speed", name = "Speed", view_conditions = {
                { id = "wtape_active", operator = "=", value = "True"}
            }},
            { id = "wtape_play_direction", name = "Play Direction", view_conditions = {
                { id = "wtape_active", operator = "=", value = "True"}
            }}
        }
    })
end

function create_grid_ui()
    return GridUI.new({
        id = "WTAPE",
        layout = {
            x = 14, 
            y = 2,
            width = 1,
            height = 1
        }
    })
end

function WTape.init()
    local component = {
        screen = create_screen_ui(),
        grid = create_grid_ui()
    }
    create_params()
    
    --------------------------------
    -- Screen — Custom logic (REMOVED)
    --------------------------------
    -- No custom draw_default for WTape screen instance
    
    --------------------------------
    -- Grid — Custom logic (REMOVED)
    --------------------------------
    -- No custom grid draw for WTape instance
    -- No custom grid handle_key for WTape instance
    
    return component
end

return WTape 
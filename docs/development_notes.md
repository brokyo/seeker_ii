# Creating a New Component in Seeker II

## Overview
Components in Seeker II are self-contained modules that can integrate with multiple parts of the system: params, screen UI, and grid UI. This guide explains how to create and integrate a new component.

## Step 1: Create the Component File
Create a new file in `/lib/components/[component_name].lua`:

```lua
-- /lib/components/[component_name].lua
local NornsUI = include("lib/components/classes/norns_ui")
local GridUI = include("lib/components/classes/grid_ui")
local GridConstants = include("lib/grid_constants")

local ComponentName = {}
ComponentName.__index = ComponentName

local instance = nil

function ComponentName.init()
    if instance then return instance end
    
    instance = {
        -- Params interface
        params = {
            create = function()
                -- Define your params here
                params:add_group("component_name", "COMPONENT NAME", 3)
                -- Add your params...
            end
        },

        -- Screen interface
        screen = {
            instance = NornsUI.new({
                id = "COMPONENT_NAME",
                name = "Component Name",
                description = "Component description",
                params = {
                    { separator = true, name = "Component Name" }
                    -- Add your params...
                }
            }),

            build = function()
                return instance.screen.instance
            end
        },

        -- Grid interface
        grid = GridUI.new({
            id = "COMPONENT_NAME",
            layout = {
                x = 1,  -- Grid position X
                y = 1,  -- Grid position Y
                width = 1,  -- Width in grid units
                height = 1  -- Height in grid units
            }
        })
    }
    
    return instance
end

return ComponentName
```

## Step 2: Add to Screen UI
In `/lib/screen_iii.lua`, add your component:

1. Import at the top:
```lua
local ComponentName = include('lib/components/[component_name]')
```

2. Add to sections in the init function:
```lua
ScreenUI.sections = {
    -- ... existing sections ...
    COMPONENT_NAME = ComponentName.init().screen.build(),
}
```

## Step 3: Add to Grid UI
In `/lib/grid_ii.lua`, add your component:

1. Import at the top:
```lua
local ComponentName = include('lib/components/[component_name]')
```

2. Add to regions table:
```lua
local regions = {
    -- ... existing regions ...
    component_name = ComponentName.init().grid,
}
```

3. Add to draw_controls():
```lua
function draw_controls()
    -- ... existing regions ...
    regions.component_name:draw(GridUI.layers)
end
```

4. Add to key handler:
```lua
function GridUI.key(x, y, z)
    if is_in_keyboard(x, y) then
        -- ... existing keyboard code ...
    else
        -- ... existing regions ...
        elseif regions.component_name:contains(x, y) then
            regions.component_name:handle_key(x, y, z)
    end
end
```

## Step 4: Add to Params Manager
In `/lib/params_manager_ii.lua`, initialize your component's params:

1. Import at the top:
```lua
local ComponentName = include("lib/components/[component_name]")
```

2. Add to bottom of file:
```lua
ComponentName.init().params.create()
```
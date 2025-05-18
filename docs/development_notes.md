## Creating A New UI Component

### Traditional Approach (Multiple Files)

1. Create region in `/lib/grid/regions/[name]_region.lua`:
   - Define `layout` with x, y, width, height
   - Implement `contains()`, `draw()`, `handle_key()`
   - Return the region table

2. Create section in `/lib/ui/sections/[name]_section.lua`:
   - Implement UI elements and parameter behavior
   - Define section params and state
   - Inherit from base Section class

3. Add to `/lib/grid_ii.lua`:
   - Import region at top
   - Add to `regions` table
   - Add `draw()` call in `draw_controls()`
   - Add condition in `GridUI.key()` handler

4. Add to `/lib/screen_iii.lua`:
   - Import section at top
   - Add to `ScreenUI.sections` table (use brackets for special characters)

### New Component-Based Approach (Single File)

Create a self-contained component in `/lib/components/[name].lua`:

1. Set up inheritance:
   ```lua
   local ComponentName = {}
   ComponentName.__index = ComponentName
   setmetatable(ComponentName, { __index = ScreenUI })
   ```

2. Define interfaces in a single instance:
   ```lua
   instance = {
       params = { create = function() end },
       screen = { build = function() end },
       grid = {
           layout = { x, y, width, height },
           contains = function() end,
           draw = function() end,
           handle_key = function() end
       }
   }
   ```

3. In screen.build(), set up inheritance:
   ```lua
   setmetatable(screen_ui, { __index = ComponentName })
   ```

4. Add to `/lib/screen_iii.lua`:
   - Import component
   - Add to `ScreenUI.sections` table
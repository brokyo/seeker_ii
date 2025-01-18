# Development Pitfalls and Solutions

This document lists common development issues encountered in Norns/Lua development and their solutions.

## Module Communication & Dependencies

### Module Import Checklist

**Problem**: Missing imports are a common source of "attempt to index nil value" errors:
```lua
-- ui.lua
local UI = {}

function UI.some_function()
  logger.status({  -- Error: logger not imported!
    event = "something_happened"
  })
end
```

**Solution**: Use an import checklist when creating/modifying modules:
1. List required dependencies at top of file
2. Check for common services:
   - logger (if using logging)
   - params (if using parameters)
   - util (if using utility functions)
3. Document dependencies in module header

```lua
-- ui.lua
-- Dependencies:
--   lib/logger.lua - Logging system
--   lib/params.lua - Parameter management
--   lib/util.lua   - Utility functions

local logger = include('lib/logger')
local params = include('lib/params')
local util = include('lib/util')

local UI = {}
```

### Module Instance Management

**Problem**: When multiple modules need to share a stateful service/manager, using `include()` in each module can create separate instances:
```lua
-- grid_ui.lua
local state_manager = include('lib/state_manager')  -- Creates instance A

-- ui.lua
local state_manager = include('lib/state_manager')  -- Creates instance B

-- Both modules think they're talking to the same manager, but they're not!
```

**Solution**: Use dependency injection - initialize the shared service once and pass it to modules that need it:
```lua
-- main.lua
local state_manager = include('lib/state_manager')
state_manager.init()  -- Initialize once

local grid_ui = include('lib/grid_ui')
local ui = include('lib/ui')

-- Pass the instance to modules that need it
grid_ui.init(state_manager)
ui.init(state_manager)

-- grid_ui.lua
local GridUI = {}
local state_manager = nil  -- Will be set during init

function GridUI.init(manager)
  state_manager = manager  -- Store the shared instance
end
```

Benefits:
- Ensures all modules work with the same instance
- Makes dependencies explicit
- Easier to test with mock instances
- Avoids hidden state synchronization issues
- Clear initialization order

**Warning Signs**:
- Using include() to get references to stateful modules
- Adding callback systems for module communication
- Modules needing to "find" each other

**Questions to Ask**:
1. "Could this be passed in through init()?"
2. "Are we creating hidden dependencies?"
3. "Is there a simpler parent-child relationship?"

### Circular Dependencies and Module Communication

**Problem**: When modules need to communicate with each other, the naive approach leads to circular dependencies:
```lua
-- module_a.lua
local module_b = include('lib/module_b')

-- module_b.lua
local module_a = include('lib/module_a')  -- Circular dependency!
```

**Solution**: Use the Observer Pattern via callback registration:
```lua
-- module_a.lua (the subject/publisher)
local ModuleA = {}
ModuleA.callbacks = {}  -- Store callbacks from other modules

-- Let other modules register their interest
function ModuleA.register_callback(event_name, callback_fn)
  ModuleA.callbacks[event_name] = ModuleA.callbacks[event_name] or {}
  table.insert(ModuleA.callbacks[event_name], callback_fn)
end

-- Notify interested modules when something happens
function ModuleA.notify(event_name, ...)
  if ModuleA.callbacks[event_name] then
    for _, callback in ipairs(ModuleA.callbacks[event_name]) do
      callback(...)
    end
  end
end

-- module_b.lua (the observer/subscriber)
function ModuleB.init()
  -- Register interest in ModuleA's events
  ModuleA.register_callback("some_event", function(...)
    -- Handle the event
  end)
end
```

This pattern is used throughout Norns development:
- Parameter system uses this via `params:set_action()`
- Grid UI can register for parameter changes
- Engine events can trigger UI updates
- Clock/metro events can notify multiple modules

Benefits:
- Avoids circular dependencies
- Loose coupling between modules
- Multiple modules can respond to the same events
- Clear separation of concerns
- Modules can be tested in isolation
- Easy to add new observers without modifying existing code

## Parameter Management

### Parameter Display Formatting

**Problem**: Trying to pass complex data structures (tables, objects) to params system can cause display errors:
```lua
-- Will cause errors in params menu
params:add_option("scale_type", "Scale", musicutil.SCALES, 1)
```

**Solution**: Use simple data types and format display as needed:
```lua
-- Convert complex data to simple strings first
local scale_names = {}
for i = 1, #musicutil.SCALES do
  scale_names[i] = musicutil.SCALES[i].name
end
params:add_option("scale_type", "Scale", scale_names, 1)
```

### Parameter Initialization Timing

**Problem**: When using engines that add their own parameters (like MXSamples), accessing parameters too early can cause errors like "invalid paramset index":
```lua
engine.name = "MxSamples"
local mxsamples = include("mx.samples/lib/mx.samples")
-- This might fail if parameters aren't fully initialized
params:get("some_engine_param")  
```
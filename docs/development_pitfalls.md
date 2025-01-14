# Development Pitfalls and Solutions

This document lists common development issues encountered in Norns/Lua development and their solutions.

## Module Communication & Dependencies

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

**Solution**: Ensure engine parameters are fully initialized before access:
```lua
engine.name = "MxSamples"
local mxsamples = include("mx.samples/lib/mx.samples")
-- Create engine instance first
local skeys = mxsamples:new()  -- This adds engine parameters
-- Then initialize your own parameters
params:add_separator("MY_PARAMS")
-- Now safe to access engine parameters
params:get("some_engine_param")
```

## Grid Management

### Grid Updates

**Problem**: Grid display not updating when parameters change.

**Solution**: Always call `grid:refresh()` after LED changes and ensure redraw is triggered by relevant parameter changes:
```lua
function GridUI.redraw()
  -- Update LEDs
  GridUI.draw_keyboard()
  GridUI.draw_pattern_lane()
  g:refresh()  -- Critical!
end
```

### Grid Event Handling

**Problem**: Grid events not being captured.

**Solution**: Ensure grid key callback is properly set in initialization:
```lua
if g.device then
  g.key = function(x, y, z)
    GridUI.key(x, y, z)
  end
end
```

### Initialization Order and Dependencies

**Problem**: Complex initialization dependencies between modules can lead to circular dependencies and "nil value" errors:
```lua
-- Trying to initialize everything at once leads to dependency cycles
function init()
  grid_ui.init()      -- Needs params for initial state
  params.init()       -- Actions try to update grid
  reflection.init()   -- Grid needs this to work
end
```

**Solution**: Layer initialization in clear dependency order, from core systems outward:
```lua
function init()
  -- 1. Core systems (no dependencies)
  audio_engine.init()
  
  -- 2. State/parameter system (depends on core only)
  params:init()
  params:read()
  params:bang()
  
  -- 3. Business logic (depends on core/params)
  pattern_manager.init()
  
  -- 4. UI layer (can depend on everything)
  grid_ui.init()
  screen_ui.init()
end
```

Benefits:
- Each layer only initializes after its dependencies
- Clear separation of concerns
- Easier to track dependency flow
- Prevents circular initialization issues
- Makes dependencies explicit and visible

Common layers (from inside out):
1. Core systems (audio, clock)
2. State management (parameters, settings)
3. Business logic (pattern management, sequencing)
4. UI and interaction (grid, screen, MIDI)

### Debugging Dependencies

When facing initialization or dependency errors, ask these questions:

1. "Do these modules actually need each other?"
   - Challenge assumed dependencies
   - Look for accidental coupling
   - Consider if the dependency is bidirectional or one-way

2. "What's the simplest thing that needs to happen first?"
   - Identify core systems that have no dependencies
   - Look for modules that only depend on core systems
   - UI usually depends on everything - it should come last

3. "Could this be initialized earlier?"
   - Parameters often can be initialized right after core systems
   - Business logic usually only needs core + parameters
   - UI callbacks/actions can be registered after everything else

Example debugging process:
```lua
-- Initial problematic code
function init()
  grid_ui.init()      -- Fails: needs params
  pattern_system.init()
  params.init()
end

-- Ask: "What actually needs what?"
-- Answer: params don't need anything else
-- New working code
function init()
  params.init()       -- No dependencies!
  pattern_system.init()
  grid_ui.init()      -- Now params exist
end
```

## More to come...
This document will be updated as we encounter and solve more development challenges. 
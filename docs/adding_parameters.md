# Adding Parameters to Seeker II

This guide outlines the process of adding new parameters to Seeker II. Parameters must be properly integrated across three key files to appear in the UI and function correctly.

## Overview

Adding a parameter requires changes to:
1. `params_manager.lua`: Define and initialize the parameter
2. `ui_manager.lua`: Add the parameter to the appropriate UI category
3. `screen.lua`: (Usually no changes needed unless adding new parameter types)

## Step-by-Step Process

### 1. Add Parameter Definition in params_manager.lua

Parameters are added in the lane configuration section:

```lua
-- Calculate total params per lane
local params_per_lane = 3 + 3 + (4 * 4) + 2  -- Must include ALL parameters
-- Voice params (3): instrument, octave, volume
-- Transport params (3): timing_mode, recording_mode, quantize_value
-- Stage params (16): 4 stages × 4 params per stage
-- Keyboard params (2): keyboard_x, keyboard_y

params:add_group("LANE " .. i, params_per_lane)  -- Group must know total count
```

Add your parameter definition:
```lua
-- Add new parameter
params:add_option(
  "lane_" .. i .. "_recording_mode",  -- Unique ID
  "Recording Mode",                   -- Display name
  {"free", "quantized"},             -- Options
  1                                  -- Default value
)
```

### 2. Add Parameter Category in ui_manager.lua

Parameters are organized into categories in the UI manager:

```lua
param_categories = {
  voice = {"keyboard_x", "keyboard_y", "instrument", "midi", "volume"},
  transport = {"record", "recording_mode", "quantize_value"},
  stage = {"active", "transform", "loop_count", "loop_rest", "stage_rest"}
}
```

Add your parameter to the appropriate category. The category determines which page the parameter appears on.

### 3. Update Parameter Filtering in params_manager.lua

The `get_lane_params()` function filters parameters by category. Add a matching clause for your parameter:

```lua
function params_manager.get_lane_params(lane_num, category, stage_num)
  -- ...
  -- Match parameter to category based on id prefix
  if category == "recording_mode" and param.id:match("^lane_" .. lane_num .. "_recording_mode$") then
    matches_category = true
  end
  -- ...
end
```

## Common Gotchas

1. **Parameter Count**: The `params_per_lane` count must include ALL parameters. Missing parameters from this count will cause them to be invisible or misaligned in the UI.

2. **Category Names**: The category name in `ui_manager.lua` must exactly match what you check for in `get_lane_params()`.

3. **Parameter IDs**: Follow the naming convention:
   - `lane_[number]_[param_name]` for lane-specific parameters
   - Use underscores to separate parts
   - Keep IDs consistent between param definition and category matching

## Example: Adding Recording Mode Parameter

Here's a complete example of adding the recording mode parameter:

1. In `params_manager.lua`:
```lua
-- Update parameter count
local params_per_lane = 3 + 3 + (4 * 4) + 2  -- Added recording_mode to transport

-- Add parameter definition
params:add_option(
  "lane_" .. i .. "_recording_mode",
  "Recording Mode",
  {"free", "quantized"},
  1
)

-- Add to get_lane_params
elseif category == "recording_mode" and param.id:match("^lane_" .. lane_num .. "_recording_mode$") then
  matches_category = true
```

2. In `ui_manager.lua`:
```lua
param_categories = {
  transport = {"record", "recording_mode", "quantize_value"},  -- Added to transport page
  -- ...
}
```

## Testing

After adding a parameter:
1. Check that it appears in the correct UI page
2. Verify the parameter count is correct (no missing parameters)
3. Test parameter changes are reflected in the system
4. Check that the parameter persists across script reload 
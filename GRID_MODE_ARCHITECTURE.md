# Grid Mode Architecture

## Overview

The grid system uses a **mode-based architecture** where modes are full-page grid applications with their own behavior and screen sections.

## Key Concepts

### Mode vs Section

- **Mode** (`_seeker.current_mode`) = Grid behavior and interaction paradigm
- **Section** (`_seeker.ui_state.current_section`) = Screen parameter view

A mode can contain multiple sections. Example:
- OSC_CONFIG mode has sections: OSC_CONFIG (connection), OSC_OUTPUT (individual outputs)
- KEYBOARD mode has sections: KEYBOARD, LANE, STAGE, MOTIF, etc.

## Adding a New Mode

1. **Define in registry** (`lib/grid_mode_registry.lua`):
```lua
MY_MODE = {
  button = { x = 13, y = 2 },           -- Mode switcher position
  default_section = "MY_MODE",          -- Section when mode activates
  sections = { "MY_MODE", "MY_SUB" },   -- All sections in this mode
  mode_impl = "lib/grid/modes/my_mode" -- Path to implementation
}
```

2. **Create mode implementation** (`lib/grid/modes/my_mode.lua`):
```lua
local MyMode = {}

function MyMode.draw_full_page(layers)
  -- Draw your mode's grid UI
end

function MyMode.handle_full_page_key(x, y, z)
  -- Handle grid input
end

return MyMode
```

3. **Done!** The system automatically:
- Adds your button to mode switchers
- Routes grid events to your mode
- Lazy-loads your implementation
- Validates section→mode relationships

## Mode Registry Functions

- `GridModeRegistry.get_mode(mode_id)` - Get mode config
- `GridModeRegistry.get_mode_for_section(section)` - Reverse lookup
- `GridModeRegistry.section_belongs_to_mode(section, mode_id)` - Validation

## Current Modes

- **OSC_CONFIG** (x=13, y=2) - OSC configuration and outputs
- **KEYBOARD** (x=14, y=2) - Musical keyboard and performance
- **EURORACK_OUTPUT** (x=15, y=2) - Eurorack CV/Gate
- **CONFIG** (x=16, y=2) - Global application settings

# Seeker II Architecture
#### Last Updated: 2025-02-09

## Core Components

### `seeker_ii.lua`
- Entry point
- Kicks off configuration of the app
- Creates global state, _seeker, that holds the core components that are accessed by other modules
- Kicks off global clock

### `conductor.lua`
- Event processing and manipulation queue
- Owns cross-app sequencing
- Takes events (primarily from `Lane`) and places them in time
- Processes their callback at event time

### `lane.lua`
- Core piece of the application replicated four times
- Contains event configuration, handling, and scheduling controls
- Contains transport controls
- Contains output device configuration
- Contains stage configuration

### `motif_recorder.lua`
- Builds a table of events from grid presses
- Contains recording logic and methods
- Contains quantization logic
- Contains overdub logic
- Uses `theory.note_to_name` to convert grid events to MIDI events

### `motif_ii.lua`
- "Smart" event data container
- Stores events for playback
- Handles manipulation of event table
- Sits on `Lane` and is the source of scheduled events

### `transforms.lua`
- Registry of available transforms
- Used by `Motif` to manipulate data
- Used in `transform_section.lua` to display and select transforms

### `params_manager_ii.lua`
- Parameter system initialization and management
- Provides centralized parameter access

### `ui_state_ii.lua`
- Manages the central UI state that connects the screen and grid
- Handles events that affect the UI state of the entire app

## Screen UI

### `screen_iii.lua`
- UI manager and drawing loop
- Contains all of the UI sections (inhering from the window manager `/lib/ui/sections.lua`)
- Contains the checking for `/lib/ui/screen_saver.lua` screen saver

### `ui/sections`
- Individual windows in the UI
- Front end for params that handle configuration and action
- Inherit from `/lib/ui/section.lua` and are manually overwritten when needed
- Two types of sections:
  - Static sections (like `config_section.lua`) with fixed parameter structures
  - Dynamic sections (like `generate_section.lua` and `transform_section.lua`) that rebuild their parameter structure based on user interaction

### `screen_saver.lua`
- Blinkenlights that kick in after a period of inactivity
- Show app state

## GRID

### `grid_constants.lua`
- Single source of truth for grid-related constants (size, brightness, etc.)
- Used across all grid-related modules

### `grid_layers.lua`
- Manages composite layering system for grid illumination
- Builds a matrix of brightness values for each layer
- Provides methods for setting and getting values in the matrix
- Combines layers into a single output matrix

### `grid_animations.lua`
- Manages dynamic visual effects and background animation
- Intentionally violates some of our development patterns as animation is a special case

### `grid_ii.lua`
- Primary grid interface and event handler
- Manages keyboard, transport, and lane controls
- Routes grid interactions to appropriate systems
- Coordinates visual feedback across layers

### `grid/regions`
- Individual regions of the grid
- Handle their own logic and drawing
- Make moving things around easy

## TODO
### `forms.lua`
- Large-scale presets. Possibly redundant in our new system.

### `icons.lua`
- Cool icons

### `lane_archetype.lua`
- Golden record of lane forms
- Enables sanity checking of data structures
- Controls debug lane

## Areas To Monitor
- Dynamic UI sections (`generate_section.lua`, `transform_section.lua`) use a lifecycle pattern (`enter()`, `exit()`, `update()`) to manage parameter rebuilding. Only needed when parameter structure changes based on user interaction.
- x,y coordinates are converted from grid position to MIDI note in the `grid_ii.lua` methods note_on and note_off using `theory.note_to_name`.
- `MotifRecorder` returns a table of events in `grid_ii.lua` `toggle_rec_button`. This is then passed to `Lane` `set_motif` method.
- `Lane` `on_note_on()` is the convergence point for incoming events. It handles scheduled motifs and live on/offs from the grid. This is the place to change note logic.
- When sending events out of ii we have to deal with magic numbers. Values 1 > 4 are for crow. Values 5 > 8 are for txo.
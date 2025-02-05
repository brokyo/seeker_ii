# Seeker II Architecture

## Core Components

### `seeker_ii.lua`
- Entry point
- Kicks off configuration of the app
- Holds clock that calls `conductor`
- Intializes Lanes system

### `conductor.lua`
- Event processing queue
- Takes events from `Lane`, places them in time
- Processes their callback at event time

### `lane.lua`
- Event configuration, generation, handling, and scheduling
- Contains transport controls
- Contains `Motif` scheduling and transformation controls
- Constains stage configuration controls

### `motif_recorder.lua`
- Catches grid key presses
- Toggles record functionality
- Converts grid event to MIDI event (with optional quantization)

### `motif_ii.lua`
- "Smart" event data container
- Handles manipulation of event table
- Sits on `Lane` and is the source of scheduled events

### `transforms.lua`
- Registry of available transforms
- Used by `Motif` to manipulate data

### `lane_archetype.lua`
- Golden record of lane forms
- Enables sanity checking of data structures
- Controls debug lane

### `params_manager_ii.lua`
- Parameter system initialization and management
- Provides centralized parameter access

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

## TODO

### `forms.lua`

### `icons.lua`
- Cool icons

## UI

### Adding Params to UI
1. Add param to `params_manager_ii.lua`
2. Update integer in `params:add_group()` in `params-manager-ii.lua` to match new param count
3. Add param and necessary metadata to `ScreenUI.sections_config`
4. Add logic to `ScreenUI.get_param_value()` to handle new param
5. Add logic to `ScreenUI.modify_selected` to handle param value changes

## External Dependencies

### Audio Engine
- Uses `MxSamples` sample playback engine

## Areas To Monitor
- x,y coordinates are converted from grid position to MIDI note in the `grid_ii.lua` methods note_on and note_off using `theory.note_to_name`.
- `MotifRecorder` returns a table of events in `grid_ii.lua` `toggle_rec_button`. This is then passed to `Lane` `set_motif` method.
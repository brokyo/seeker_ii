# Seeker II Architecture

## `seeker_ii.lua`
- Entry point
- Kicks off configuration of the app
- Holds clock that calls `conductor`
- Intializes Lanes system

## `conductor.lua`
- Event processing queue
- Takes events from `Lane`, places them in time
- Processes their callback at event time

## `lane.lua`
- Event configuration, generation, handling, and scheduling
- Contains transport controls
- Contains `Motif` scheduling and transformation controls
- Constains `Stage` configuration controls

## `motif_recorder`
- Catches grid key presses
- Toggles record functionality
- Converts grid event to MIDI event (with optional quantization)

## `motif_ii.lua`
- Event container
- Object played by `Lane`
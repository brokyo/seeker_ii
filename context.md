# Seeker II Development Context

## Current Status (2024-01-21)
We've completed the timing system refactor milestone and implemented a cleaner event parameter system. The clock system now uses musical divisions that align with Lattice's native approach.

### What's Working
- **Lattice Timing System**
  - Successfully moved to division-centric architecture
  - Clock parameters use musical divisions (1/32 to 32)
  - Channels properly sync when sharing divisions
  - Key files: `lib/lattice_manager.lua`, `lib/channel.lua`, `lib/clock_utils.lua`

- **Grid UI**
  - Visual feedback matches timing events
  - Note trails working across all modes
  - Key file: `lib/grid_ui.lua`

- **Event System**
  - Basic strum and burst behaviors functioning
  - Clean parameter organization with separate event group
  - Proper parameter visibility management
  - Key file: `lib/channel.lua`

### In Progress
- **Event Behavior Refinement**
  - Planning improvements to strum and burst algorithms
  - No blocking issues currently
  - Working in: `lib/channel.lua`

### Known Issues
- **Parameter System**
  - Some persistence issues with certain parameters
  - Medium priority fix needed
  - Located in: `lib/params_manager.lua`

## Architecture Overview

### Core Modules
1. **Lattice Manager**
   - Heart of the timing system
   - Manages shared sprockets for timing divisions
   - Handles channel registration

2. **Channel**
   - Handles musical voice behavior
   - Registers with lattice for timing
   - Manages note generation and patterns
   - Implements strum and burst behaviors

3. **Grid UI**
   - Provides visual interface
   - Shows timing and note feedback
   - Handles user interaction

### Key Architectural Decisions
1. **Division-Centric Timing**
   - Using musical divisions (1/32 to 32)
   - Provides better synchronization
   - More efficient resource usage

2. **Shared Sprockets**
   - Single source of truth for each division
   - Perfect sync between channels using same division
   - Cleaner separation of timing and behavior

3. **Event Parameter Organization**
   - Separated clock and event parameters
   - Improved visibility management
   - Better user experience

## Development Focus

### Current Priority
- Refining strum and burst behaviors
- Building on stable timing foundation
- High priority

### Next Up
- Parameter persistence improvements
  - Medium priority
  - Dependent on params_manager updates

- Channel Reset/Sync Feature
  - Add global reset button to sync all channels
  - Important for multi-channel timing coordination
  - Will require updates to lattice_manager and channel modules
  - Medium priority

## Using This Document
- Update the date when making significant changes
- Keep "What's Working" and "Known Issues" current
- Document architectural decisions as they're made
- Track development focus and priorities 
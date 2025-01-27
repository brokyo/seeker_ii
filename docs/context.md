# Seeker II - Project Context
Last Updated: [Current Date]

## Overview
### Purpose
- Musical instrument focused on pattern-based composition and performance
- "No wrong notes" interface design
- Dynamic pattern evolution through transforms
- Professional-grade timing and synchronization

### Core Components
Key files: `seeker_ii.lua`, `lib/conductor.lua`, `lib/grid.lua`, `lib/motif.lua`, `lib/screen.lua`
- **Conductor**: Orchestrates motif playback, manages lanes, handles transformations
- **MotifRecorder**: Captures input from grid/MIDI into note sequences with timing
- **Grid**: Manages grid hardware interaction and routes user actions
- **GridAnimations**: Handles ambient visual effects and LED animations at 30fps
- **Screen**: Parameter editing and visual feedback for system state
- **Motif**: Pure data container for note sequences with property arrays
- **UIManager**: Coordinates updates between grid and screen components

### Current Status & Major Milestones
#### Completed
- Core timing system verified (sub-10ms accuracy)
- Conductor architecture implemented
- Testing infrastructure in place
- Basic grid integration

#### In Progress
- Transform system implementation
- Visual feedback system
- Grid animation optimization

#### Upcoming Major Milestones
- Complete pattern recording system
- Multi-lane synchronization
- Performance UI
- Transform sequencing
- Stage management

## Architecture
### Core Pattern: Centralized State Management
Seeker II uses a centralized state pattern that provides clear ownership and predictable data flow:

#### The _seeker Container
The `_seeker` table serves as our single source of truth:
```
_seeker
├── ui_manager      -- UI state coordination
├── params_manager  -- Parameter state
├── conductor       -- Audio/timing
├── focused_lane    -- Current UI focus
└── focused_stage   -- Current stage focus
```

#### Key Principles
1. **Single Source of Truth**
   - All shared state lives in `_seeker`
   - Components never share state directly
   - No global variables outside `_seeker`
   - Clear ownership of each state piece

2. **Component Communication**
   - Components access shared services through `_seeker`
   - UI coordination happens through `_seeker.ui_manager`
   - Parameter access through `_seeker.params_manager`
   - No direct component-to-component communication

3. **State Management**
   - Components own their internal state
   - Shared state lives in appropriate manager
   - Changes flow through manager interfaces
   - Clear initialization order

4. **Benefits**
   - Predictable data flow
   - Easy debugging (state in known locations)
   - Clear dependency graph
   - No hidden coupling
   - Testable components

#### Initialization Sequence
```
1. Core Setup
   └── Audio engine
2. Parameter System
   └── params_manager
3. UI Components
   ├── grid
   ├── ui_manager (with grid)
   └── screen (with ui_manager)
```

### Component Responsibilities
1. **UI Manager** (`lib/ui_manager.lua`)
   - Coordinates UI state between components
   - Manages focus and navigation
   - Routes parameter updates
   - Handles page management

2. **Params Manager** (`lib/params_manager.lua`)
   - Defines and initializes parameters
   - Provides parameter access patterns
   - Manages parameter categories
   - Handles parameter persistence

3. **Screen** (`lib/screen.lua`)
   - Owns screen drawing logic
   - Manages local UI state (animations)
   - Accesses shared state via _seeker
   - Handles parameter display/editing

4. **Grid** (`lib/grid.lua`)
   - Manages grid hardware
   - Handles input events
   - Updates through ui_manager
   - Maintains visual state

## Core Architecture

### Architectural Pattern
The system follows a centralized state pattern for predictable data flow and clear ownership:

#### Component Hierarchy
```
_seeker
├── ui_manager (coordinates UI state)
│   ├── screen (display)
│   └── grid (input)
├── params_manager (parameter state)
└── conductor (audio/timing)
```

#### Key Principles
1. **Single Source of Truth**
   - All shared state lives in `_seeker` table
   - Components access shared services through `_seeker`
   - No direct component-to-component communication
   - No global state outside `_seeker`

2. **State Management Rules**
   - Components own their internal state
   - Shared state lives in `_seeker`
   - UI coordination through `_seeker.ui_manager`
   - Clear initialization order (params → grid → ui → screen)

3. **Benefits**
   - Clear ownership of state
   - Predictable data flow
   - No hidden dependencies
   - Easier debugging (state is always in known place)

### Conductor (The Maestro)
Key files: `lib/conductor.lua`, `lib/transforms.lua`
#### Primary Role
- Orchestrates the overall musical performance
- Manages precise timing and synchronization
- Controls pattern evolution through transforms

#### Key Responsibilities
1. Decides WHEN patterns change (stage transitions)
2. Determines HOW patterns evolve (transform sequencing)
3. Coordinates changes across multiple lanes
4. Manages precise timing and synchronization

#### Implementation Details
1. Timing System
   - Uses absolute beat numbers (e.g. 152399.001) for precise timing
   - Global beat counter ensures exact synchronization
   - Loop rests align to global beat grid
   - Stage transitions occur only after rest periods

2. Transform Handling
   - Transforms only occur at stage boundaries
   - Speed changes require special timing calculations
   - New tempo must align with global beat grid
   - Example: If stage 1 ends at beat 152400.0 with 2x speed:
     * Stage 2 events map to 152400.0, 152400.25, 152400.5...

3. Edge Cases & Safety
   - Handles notes crossing loop boundaries
   - Ensures note-offs even if playback interrupted
   - Proper cleanup on lane/stage transitions
   - Never logs during redraw (can crash Norns)

### Lane System
Key files: `lib/conductor.lua`, `lib/lane_utils.lua`
- Primary organizational unit for playback
- Each lane contains:
  - Motif data (genesis and current state)
  - Instrument settings
  - Timing configuration
  - Transform sequences
- Four stages per lane for dynamic performance
- Stage activation provides performance control

### Motif (The Score)
Key files: `lib/motif.lua`, `lib/motif_recorder.lua`
- Smart data container for musical patterns
- Maintains genesis (original) state
- Provides current working state access
- Implements transform mechanics
- Pure data storage using separate property arrays

### Grid Layout (The Interface)
Key files: `lib/grid.lua`, `lib/ui.lua`, `lib/ui_manager.lua`

The grid interface balances musical expression with visual clarity:
- Central 6x6 musical keyboard for note input
- Four corner sections, each managing an independent lane
- Consistent visual feedback using brightness levels (BRIGHT → MED → DIM)
- Clear focus system to show active lane/stage
- Ambient background animations for grid activity

The interface is designed to make musical exploration intuitive while providing clear feedback about system state. Detailed layout and usage information can be found in `docs/grid_layout.md`.

### State Management
Key files: `lib/params_manager.lua`, `lib/ui_manager.lua`, `lib/screen.lua`

#### Core State
- Global state through `_seeker` table (focused lane/stage)
- Parameter values and configuration in params_manager
- Screen UI state local to screen.lua (parameter selection, animations)
- UI manager coordinates focus changes between grid and screen

The separation ensures each component only manages state it owns, while the ui_manager handles coordination between components.

### Transform System
Key files: `lib/transforms.lua`, `lib/transformations.lua`
- Split between Conductor (decisions) and Motif (mechanics)
- Transforms occur at stage boundaries
- Special handling for timing-critical transforms
- Supports compound transformations

## Musical Design

### Keyboard Philosophy
Key files: `lib/theory_utils.lua`, `lib/grid.lua`
#### Modal Tonnetz Layout
1. Core Concept:
   - "No wrong notes" musical interface
   - Every position guaranteed to be in key
   - Geometric patterns create consistent phrases

2. Layout Structure:
   - Three-row polyphonic keyboard (grid rows 6-8)
   - Middle Row (7): Main melody and chord roots
   - Top Row (6): Harmony voice with thirds/sixths
   - Bottom Row (8): Counterpoint voice

3. Musical Properties:
   - Every path becomes a valid melody
   - Shapes become consistent harmonic patterns
   - Natural voice leading through contrary motion
   - Spans approximately 3 octaves

## System Implementation

### Timing System
Key files: `lib/conductor.lua`, `lib/motif_recorder.lua`

#### Core Concepts
1. **Recording Modes**
   - Grid Mode: Notes quantized to fixed intervals for arpeggios
   - Free Mode: Preserves expressive timing of original performance
   - Mode selection affects both recording and playback behavior

2. **Event Scheduling**
   - Pre-calculates all events for a stage
   - Events include: note_on, note_off, loop_start, stage_end
   - Uses absolute beat numbers for precise timing
   - Maintains exact relative timing between notes in free mode
   - Enforces grid intervals in grid mode

3. **Loop Structure**
   - Grid Mode: Fixed intervals between notes, loop length determined by note count
   - Free Mode: Preserves original timing relationships, loop length from last note
   - Optional rest period between loops (in beats)
   - Clean note boundaries (all notes complete before loop/stage end)

4. **Stage System**
   - Multiple loops with consistent timing behavior
   - Optional rest period between stages
   - Automatic transition to next active stage
   - Falls back to stage 1 if no next active stage

#### Timing Hierarchy
```
Stage
├── Loop Rest (configurable pause between loops)
├── Multiple Loops
│ ├── Grid Mode
│ │ ├── Fixed intervals between notes
│ │ ├── Configurable gate length
│ │ └── Loop length = notes * grid_division
│ └── Free Mode
│   ├── Preserved note timing
│   ├── Original note durations
│   └── Loop length from last note
└── Stage Rest (configurable pause before next stage)
```

### Testing Framework
Key files: `lib/test_helpers.lua`

#### Core Features
1. **Test Definition**
   - Declarative test cases with note sequences
   - Mode-specific test configuration (grid vs free)
   - Support for multi-stage testing
   - Configurable loop counts and timing parameters

2. **Test Categories**
   - Grid mode timing verification
   - Free mode expression preservation
   - Stage transition behavior
   - Loop boundary handling

3. **Test Execution**
   - Individual test running (`test.run_test(n)`)
   - Full suite execution (`test.run_all_tests()`)
   - Detailed logging of timing events
   - Visual verification through event tables

4. **Test Coverage**
   - Basic arpeggio patterns
   - Expressive timing preservation
   - Stage transitions
   - Mode-specific behavior
   - Loop timing and boundaries

## Data Flow
Key files: `lib/motif_recorder.lua`, `lib/conductor.lua`, `lib/grid.lua`
1. Grid captures input
2. Recording:
   - MotifRecorder captures notes and timing
   - Motif stores data
   - Conductor manages playback
3. Playback:
   - Conductor schedules using absolute timing
   - Transforms apply at stage boundaries
   - Grid provides visual feedback

### Screen UI
Key files: `lib/screen.lua`, `lib/ui_manager.lua`

The screen interface provides parameter editing and state feedback:
- Unified screen component handling both drawing and logic
- Clear parameter navigation for lanes and stages
- Visual feedback through animations and transitions
- Tight integration with params_manager for state

#### State Management
- Global state through `_seeker` (focused lane/stage)
- Parameter state via params_manager
- Local UI state for parameter selection
- Animations for visual feedback
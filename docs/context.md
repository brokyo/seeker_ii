# Seeker II - Project Context
Last Updated: [Current Date]

## Overview
### Purpose
- Musical instrument focused on pattern-based composition and performance
- "No wrong notes" interface design
- Dynamic pattern evolution through transforms
- Professional-grade timing and synchronization

### Core Components
Key files: `seeker_ii.lua`, `lib/conductor.lua`, `lib/grid.lua`, `lib/motif.lua`
- **Conductor**: Orchestrates motif playback, manages lanes, handles transformations
- **MotifRecorder**: Captures input from grid/MIDI into note sequences with timing
- **Grid**: Manages grid hardware interaction and routes user actions
- **GridAnimations**: Handles ambient visual effects and LED animations at 30fps
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

## Core Architecture

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

#### Implementation
- Uses absolute beat numbers for precise timing
- Global beat counter ensures exact synchronization
- Supports both quantized and "free" timing modes
- Manages up to 4 parallel lanes with independent settings

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
Key files: `lib/params_manager.lua`, `lib/ui_manager.lua`
#### Core State
- Global state through `_seeker` table
- Contains core components and current focus
- Accessible to all components that need it

#### UI Management
- UIManager coordinates grid and screen updates
- Ensures consistent state across components
- Handles both grid hardware and screen display

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
Key files: `lib/conductor.lua`, `tests/timing_tests.lua`
#### Event Hierarchy
1. Stage: Complete sequence of loops with same transform
2. Loop: One complete motif playthrough
3. Event: Individual note on/off at specific beat

#### Key Features
- Sub-10ms timing accuracy
- Perfect synchronization between lanes
- No drift over long periods
- Proper cleanup prevents stuck notes

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
# Project Context

## Conductor System

### Core Responsibilities
- Manages when motifs play (clock/timing)
- Orchestrates how motifs evolve through transforms
- Synchronizes multiple motifs
- Manages playback state

### Architecture

#### 1. Lane System
- Primary organizational unit for playback
- Each lane contains:
  - Motif data (both genesis and current state)
  - Instrument settings
  - Timing configuration
  - Transform sequences
- Supports up to 4 parallel lanes with independent settings
- Each lane has 4 stages that can be activated/deactivated for dynamic performance

#### 2. Transform System
- Determines sequence and timing of pattern modifications
- Coordinates transforms across multiple lanes
- Manages transform state and progression
- Uses Motif's transform mechanism to apply changes
- Transforms only occur at stage boundaries
- Special handling for timing-critical transforms (e.g. speed changes)

#### 3. Timing & Scheduling System

##### Event Hierarchy
1. Stage: Complete sequence of loops with same transform
2. Loop: One complete playthrough of a motif
3. Event: Individual note on/off at specific beat number

##### Key Features
- Uses absolute beat numbers for precise timing
- Global beat counter (e.g. 152399.001) ensures exact synchronization
- Supports both quantized playback and "free" event times
- Maintains polyphony through chronological event sorting
- Handles overlapping notes correctly

##### Rest Periods
- Loop Rest: Configurable silence between loop iterations
- Stage Rest: Configurable silence between stages

##### Stage Management
- Each stage can be independently activated/deactivated
- Stage progression:
  1. Looks forward from current stage for next active
  2. If none found, searches all stages for any active
  3. If no active stages found, lane stops playing
- Stage 1 always resets to genesis motif
- Stages 2-4 can apply transforms:
  - Stage 2: Transforms from genesis
  - Stages 3-4: Compound on previous transform

##### Implementation Details
- All note events (on/off) are sorted chronologically before processing
- Each event scheduled using absolute beat numbers
- Uses clock.sync for precise timing alignment
- Proper cleanup ensures all notes get note-offs
- Handles interrupted playback gracefully

### Key Learnings
1. Absolute timing is crucial for long-term stability
2. Event sorting enables proper polyphony
3. Stage activation provides dynamic performance control
4. Transform timing must respect global beat grid
5. Rest periods are essential for musical phrasing
6. Proper cleanup prevents stuck notes 
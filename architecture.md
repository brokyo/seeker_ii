# Seeker II Architecture

## `seeker_ii.lua`
- Entry point
- Kicks off configuration of the app
- Holds clock that calls `conductor`
- Intializes Lanes system

## Core Components

### Clock
- Provides global beat timing
- All events scheduled in beats
- Enables quantization and sync

### Conductor
- Central event scheduler
- Manages event queue and timing
- Coordinates all lane playback
- Handles clock-based scheduling

### Motif
- Stores and manages musical sequences
- Maintains both genesis (original) and working states
- Events are `{time, type, note, velocity, pos}` pairs
- Built-in examples serve as test patterns

### Lane
- Playback engine for a single voice
- Uses motif events for sequencing
- Gets instrument from params system
- Manages speed and volume

### Stage
- Transformation container within a lane
- Can reset to genesis or build on previous stage
- Applies transforms to working motif
- Maintains grid positions through transforms

## Data Flow
```
Clock ──────> Conductor
               │
               v
Motif ─────┐   Event Queue
           │   │
           v   v
Lane ──> Stage 1 ──> Stage 2 ──> Stage N ──┐
           ^                                │
           └────────────────────────────────┘
```

## Key Principles
1. Genesis state is immutable
2. Working state handles transformations
3. Grid positions preserved through chain
4. Each stage decides: build or reset
5. All timing in beats (not seconds)
6. Events scheduled through conductor
7. Test patterns (kata) document behavior 
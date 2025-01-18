# Seeker II Context

## Core Components
- **Conductor**: Orchestrates motif playback, handles transformations, and manages musical state
- **MotifRecorder**: Captures input from grid/MIDI and converts to note sequences with timing
- **Grid**: Manages grid hardware interaction and routes user actions to recorder/conductor
- **Motif**: Pure data container storing note sequences as separate property arrays
- **Logger**: Structured logging system for debugging and state tracking

## Architecture Principles
- Global state through `_seeker` table containing core components
- Visual focus separate from musical state
- Each component has a single responsibility:
  - Grid: Input handling and visual feedback
  - MotifRecorder: Note capture and timing
  - Motif: Data storage and access
  - Conductor: Playback and transformation

## Timing System
- Two distinct timing modes:
  - "Free" timing: Preserves human-played timing with precise delays
  - "Grid" timing: Quantizes to musical divisions for rigid timing
- Transform system integrated with timing:
  - Transforms can be scheduled after specific loop counts
  - Multiple motifs can be synchronized for coordinated changes
  - Configurable wait periods between transform sequences
- Clock management:
  - Master clock in Conductor orchestrates all playback
  - Per-motif playback speeds relative to global tempo
  - Pattern boundaries trigger transform evaluations

## System State
- Voice system with 4 independent voices
- Each voice has:
  - A motif (sequence of notes with timing)
  - Playing/recording state
  - Grid row assignment
  - Timing mode and grid division settings
- Grid UI layout:
  - Rows 1-4: Voice lanes with transport controls
  - Each voice row: Record (4), Play (5), Pattern slots (6-12), Clear (13)
  - Rows 6-8: Note input area
- Uses MXSamples as sound engine

## Data Flow
1. Grid captures button presses
2. For recording:
   - Grid -> MotifRecorder captures notes and timing
   - MotifRecorder -> Motif stores structured note data
   - Conductor receives completed Motif for playback
3. For playback:
   - Grid -> Conductor controls voice playback
   - Conductor manipulates and plays Motifs
   - Grid provides visual feedback

## Current Goals
- Implementing timing system with free and grid modes
- Building transform sequence infrastructure
- Adding pattern storage/recall per voice
- Implementing voice mute/solo functionality 
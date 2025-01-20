# Seeker II Context

## Core Components
- **Conductor**: Orchestrates motif playback using absolute beat timing, manages lanes, and handles transformations
- **MotifRecorder**: Captures input from grid/MIDI and converts to note sequences with timing
- **Grid**: Manages grid hardware interaction and routes user actions to recorder/conductor
- **GridAnimations**: Handles ambient visual effects and LED animations at 144hz
- **Motif**: Pure data container storing note sequences as separate property arrays

## Architecture Principles
- Global state through `_seeker` table containing core components
- Visual focus separate from musical state
- Each component has a single responsibility:
  - Grid: Input handling and visual feedback
  - GridAnimations: High-performance LED animations
  - MotifRecorder: Note capture and timing
  - Motif: Data storage and access
  - Conductor: Precise playback scheduling and lane management

## Timing System
- Core timing engine:
  - Absolute beat-based timing for maximum precision
  - Each event scheduled to exact beat numbers
  - Verified sub-10ms timing accuracy
  - Perfect synchronization between lanes
  - No drift over long periods

- Timing modes (planned):
  - "Free" timing: Preserves human-played timing with precise delays
  - "Grid" timing: Quantizes to musical divisions for rigid timing
  - Both modes leverage the absolute beat system for accuracy

- Transform integration:
  - Transforms scheduled at precise beat boundaries
  - Multiple lanes can be synchronized for coordinated changes
  - Transform timing preserved across loop boundaries
  - Configurable wait periods between transform sequences

- Testing infrastructure:
  - Basic synchronization tests
  - Rest timing verification
  - Rapid note stress testing
  - Statistical analysis of timing accuracy

## System State
- Lane system with 4 independent lanes
- Each lane has:
  - A motif (sequence of notes with timing)
  - Playing state
  - Grid row assignment
  - Instrument assignment
  - Loop and rest settings
  - Timing mode and grid division settings
  - Transform sequence state
- Grid UI layout:
  - Rows 1-4: Lane controls
  - Each lane row: Record, Play, Pattern slots, Clear
  - Rows 6-8: Note input area
- Uses MXSamples as sound engine

## Data Flow
1. Grid captures button presses
2. For recording:
   - Grid -> MotifRecorder captures notes and timing
   - MotifRecorder -> Motif stores note data with durations
   - Conductor receives completed Motif for playback
3. For playback:
   - Grid -> Conductor controls lane playback
   - Conductor schedules notes using absolute beat timing
   - Transforms applied at stage boundaries
   - Grid provides visual feedback

## Visual System
- Grid animations run at 144hz for smooth LED transitions
- Animation architecture:
  - Separate metro system from main redraw loop
  - Multiple overlapping sine waves for organic movement
  - Primary wave (main movement)
  - Secondary wave (slower variations)
  - Tertiary wave (very slow undulations)
  - Micro-variations for added complexity
- Visual elements:
  - Ambient edge lighting (columns 1-3, 14-16)
  - Progressive dimming for depth
  - Non-repetitive organic patterns
  - Clear separation between UI and ambient elements
- Performance considerations:
  - Optimized for grid's native vsync
  - Efficient wave calculations
  - No state management overhead
  - Smooth transitions without frame drops
  - Configurable FPS (30-144hz) to balance visual smoothness with CPU usage
  - Default to 144hz but can be reduced if system load becomes a concern
  - Animation speeds automatically adjust to maintain consistent movement at any framerate

## Current Status
- Core timing system complete and verified
- Conductor architecture documented and cleaned
- Testing infrastructure in place
- Ready for grid integration phase
- Next steps:
  - Test with real recorded motifs
  - Add visual feedback during playback
  - Implement timing modes
  - Begin transform system integration 
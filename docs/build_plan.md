# Build Plan

## Grid Integration
✓ Basic start/stop functionality
✓ Channel state visualization
✓ Scale degree visualization
✓ Chord quality display
✓ Out-of-bounds indication

### Next Steps
1. Visual Enhancements
   - Implement trail visualization system
   - Apply consistently across modes:
     - Pulse: Simple note fades
     - Burst: Pattern density trails
     - Strum: Motion visualization

2. Critical Fixes
   - ✓ Parameter ID collision on "auto_save"
   - ✓ Startup error with set_pulse (nil value)
   - Fix seventh calculation for Major/Augmented
   - Review strum note ordering

3. Future Features
   - Pattern step visualization
   - Abstract pattern activity display
   - Consider additional visual feedback:
    - Velocity indication
    - Pattern position
    - Parameter changes

## Design Guidelines
- Maintain consistent visual language
- Show theoretical positions over literal notes
- Use brightness levels meaningfully:
  - DIM (2): Available positions
  - PULSE (8): Active states
  - BRIGHT (15): Current notes
  - OUT_OF_BOUNDS (4): Edge cases

## Musical Considerations
- Focus on functional representation
- Balance accuracy with usability
- Consider musical context in visualization
- Maintain visual rhythm and flow

## Completed
1. ~Basic Channel System~
   - ~Channel start/stop~
   - ~Basic clock division~
   - ~Parameter framework~

2. ~Duration System~
   - ~Fixed and Pattern modes~
   - ~Musical pattern shapes~
   - ~Integration with Strum/Burst~
   - ~Variance system~
   - ~Debug output~

3. ~Preset System~
   - ~Auto-save functionality~
   - ~Auto-load last state~
   - ~Integration with system PSET menu~

## In Progress
1. Grid Integration
   - Basic start/stop buttons
   - Channel section layout
   - Visual feedback for running state

2. Expression System
   - Velocity patterns
   - Pattern-based modulation
   - Cross-parameter relationships

3. Burst System
   - Configurable event counts
   - Pattern-based density
   - Style refinements

## Next Steps
1. Advanced Grid Features
   - Pattern visualization
   - Event monitoring
   - Full control interface

2. Paramquencer Development
   - Chord progression sequencing
   - Parameter modulation
   - Pattern coordination

## Future Features
1. Advanced Timing
   - Euclidean patterns
   - Polyrhythmic support
   - Groove templates

2. Musical Development
   - Scale-based progression
   - Textural generation
   - Effect integration

3. Interface Evolution
   - Interactive event tables
   - Musical notation
   - Real-time visualization

## Architectural Improvements

### 1. Clock System Rebuild
- Separate clock division from behavior modes
- Core concept: Maintain per-channel pulse configuration, but express event timing as fractions
- New structure:
  ```
  Clock
  - Division (per-channel, as today)
  - Global timing control
  
  Event Timing (as fractions of pulse)
  - Strum: Length as fraction (1/4, 1/2 of pulse)
  - Burst: Window as fraction
  - Pulse: Single events
  ```
- Benefits:
  - Clearer relationship between timing elements
  - More musical approach to subdivisions
  - Simpler mental model for users
  - Natural polyrhythm support through clock mod
- Implementation Notes:
  - Use existing music_utils for fraction handling
  - Visual feedback through existing grid pulse/illumination
  - No new parameter types needed

### 2. Note System Restructure
- Split current arpeggiator into distinct concepts:
  ```
  Note Pool
  - Modes:
    1. Chord-based (current system)
    2. Grid-selected (scale degree approach)
  - Implementation:
    - Enter/exit selection mode via params binary trigger
    - Toggle notes on/off in grid
    - Audio feedback using channel's MIDI settings
    - Visual indication of edit mode
  
  Pattern Engine (source-agnostic)
  - Takes note collection from pool
  - Handles ordering/playback
  - Current random/locked-random modes
  - Future expansion possible
  ```
- Grid Integration:
  - Maintain consistent grid layout
  - Scale degree approach for note selection
  - All three octaves available
  - Toggle-based note selection
  - Audio preview on press
- Benefits:
  - More flexible note selection
  - Clearer separation of concerns
  - Better foundation for future features
  - Maintains consistent UI model

### 3. Pattern Evolution
- Enhanced burst algorithms:
  - More physically-modeled behaviors
  - Musical presets (small/medium/large)
  - Style refinements:
    - Natural bounce physics
    - Organic wave patterns
    - Heartbeat-like pulses

- Refined strum patterns:
  - Guitar-like accelerations
  - Natural direction changes
  - Dynamic clustering

- Expression system expansion:
  - New pattern types (sine, breath, waves)
  - Cross-parameter relationships
  - Musical presets combining:
    - Duration patterns
    - Velocity shapes
    - Note selection
    - Movement styles

### 4. Paramquencer Development
- Multi-parameter sequencing:
  - Independent timing per parameter
  - Pattern-based parameter changes
  - Musical relationships between parameters

- Core parameters to sequence:
  - Chord progressions
  - Extensions/inversions
  - Note pool size/range
  - Pattern variations

- Musical development tools:
  - Textural evolution
  - Harmonic progression
  - Rhythmic development
  - Timbral exploration

## Implementation Priority
1. Critical fixes (startup errors, chord generation)
2. Clock system rebuild (foundation for better timing)
3. Note system restructure (enabling more musical possibilities)
4. Pattern evolution (refining musical output)
5. Paramquencer development (adding compositional depth)

## Expanded Musical Possibilities

### 1. Advanced Note Pool System
- Multiple collection modes:
  ```
  Chord-based: Current harmonic system
  Grid-selected: Arbitrary note selection
  Scale-based: Full scale availability
  Hybrid: Combine multiple sources
  ```
- Per-note properties:
  - Play probability
  - Velocity weighting
  - Duration tendencies
  - Relative importance in pattern
- Applications:
  - Complex harmonic textures
  - Evolving timbral landscapes
  - Dynamic pattern density

### 2. Inter-Channel Relationships
- Pattern interactions:
  - Complementary rhythmic patterns
  - Shared note pools with different behaviors
  - Cross-channel pattern influences
- Musical applications:
  - Call and response
  - Rhythmic counterpoint
  - Harmonic development
  - Textural layering

### 3. Musical Preset System
- Context-aware presets:
  ```
  Ambient: Long divisions, wide pools, slow evolution
  Rhythmic: Tight timing, focused notes, clear patterns
  Textural: Shifting patterns, fluid note collections
  ```
- Preset categories:
  - Time-based (rhythmic relationships)
  - Note-based (harmonic relationships)
  - Pattern-based (behavioral relationships)
- Benefits:
  - Quick musical results
  - Starting points for exploration
  - Educational value for understanding system

### 4. Performative Grid Controls
- Scene system in bottom row:
  ```
  Minimal Layout (preferred):
  [Scene A] [Scene B] [Start]
  or
  [Start] [Scene A] [Scene B]
  
  Alternative:
  Could use full column for more scenes,
  but intentional limitation might be more musical
  ```
- Scene contents:
  - Core musical parameters:
    - Chord degree and quality
    - Inversion state
    - Extension settings
  - Optional parameters:
    - Note range/octave
    - Behavior mode
  
- Interaction design:
  - Hold to store current state
  - Tap to recall
  - Visual feedback:
    - Dim: Empty scene
    - Medium: Stored scene
    - Bright: Active scene
  - Could preview stored chord in grid above when held

- Musical applications:
  - Quick switching between chord voicings
  - A/B pattern development
  - Tension/release through inversions
  - Simple progressions through degree changes
  - Performative parameter changes

- Benefits of limitation:
  - More manageable in performance
  - Creates clear musical relationships
  - Forces intentional scene design
  - Maintains playability focus

These expansions could help bridge the gap between technical capability and musical expression, making the system both more powerful and more immediately musical.
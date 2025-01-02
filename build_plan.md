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
   - Fix seventh calculation for Major/Augmented
   - Review strum note ordering
   - Address startup parameter collisions

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
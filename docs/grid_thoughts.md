# Grid Visualization Design

## Core Layout
- Grid divided into 4 vertical strips, one for each channel
- Each channel strip is 4 columns wide
- 6 rows representing 3 octaves of notes (2 rows per octave)
- Focus on 8 in-scale notes for clarity
- Scale degrees start from bottom-left (degree 1 of lowest octave)

## Visual States
- Currently playing notes: Brightest
- Available notes in scale: Medium brightness
- Off notes: Unlit

## Grid Organization
- Each channel has its own 4x6 section
- Notes arranged left-to-right and bottom-to-top
- Lowest notes at bottom, ascending upward
- Each octave spans 2 rows
- Clear visual separation between channels

## Implementation Plan
1. Start with single channel visualization
2. Focus on visualizing currently playing notes first
3. Add available note indicators later
4. Consider scale mask functionality in future iterations

## Interaction Design
- Grid provides visual feedback for:
  - Note velocity through brightness
  - Note position in scale
  - Active channels
  - Currently playing notes
- Clear visual boundaries between channels
- Intuitive pitch arrangement (lower = lower on grid)

## Future Considerations
- Scale mask implementation
- Multiple channel visualization
- Keyboard input functionality
- Visual feedback for different play modes (strum, burst, etc.)

# Grid Implementation Thoughts

## Core Principles
- Grid as musical visualization surface
- Balance between information and clarity
- Consistent visual language across modes

## Technical Learnings
1. Note Position Mapping
   - Use theoretical positions for musical clarity
   - Handle altered notes (♭3, ♭5, etc.) in theoretical positions
   - Account for global modifiers (key, transpose, octave)
   - Map MIDI notes to grid positions thoughtfully

2. Visual Feedback Systems
   - Use multiple brightness levels meaningfully
   - Implement timeouts for temporary states
   - Consider animation frame rates (30fps sufficient)
   - Handle edge cases (out-of-bounds) clearly

3. State Management
   - Track active notes per channel
   - Manage visual feedback timing
   - Handle note on/off events cleanly
   - Consider using dedicated state objects

## Design Patterns
1. Brightness Hierarchy
   - DIM (2): Available/potential
   - PULSE (8): Active states
   - BRIGHT (15): Current events
   - OUT_OF_BOUNDS (4): Edge indicators

2. Layout Organization
   - Channel separation with consistent width
   - Bottom row for controls
   - Vertical axis for scale degrees
   - Horizontal axis for octaves

3. Visual Metaphors
   - Brightness for immediacy
   - Position for musical function
   - Flashing for attention
   - Consistent across modes

## Future Directions
1. Animation Systems
   - Trail visualization for note history
   - Smooth transitions between states
   - Pattern motion representation
   - Density indication for bursts

2. Additional Information
   - Velocity visualization
   - Pattern position indication
   - Parameter change feedback
   - Abstract pattern display

3. Interaction Possibilities
   - Direct note input
   - Parameter control
   - Pattern manipulation
   - Visual feedback for changes 
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
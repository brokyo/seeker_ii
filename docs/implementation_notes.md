# Implementation Notes

## Current Status
- ✓ Parameter ID collision fixed (using sk2_ prefix)
- ✓ Startup error with set_pulse resolved
- ✓ Seventh calculation for Major/Augmented chords fixed and tested

## Implementation Details

### Chord Generation Fix (✓ COMPLETED)
- Issue: All seventh chords were using minor seventh (10 semitones)
- Fix: Quality-specific seventh intervals
  ```lua
  ["7"] = {
      Major = {11},    -- Major seventh
      Minor = {10},    -- Minor seventh
      Diminished = {9}, -- Diminished seventh
      Augmented = {11}  -- Major seventh for augmented
  }
  ```
- Extended to all extensions (9/11/13) to maintain consistency
- Each extension now uses the correct seventh based on chord quality
- Test Results:
  1. Basic Seventh Chords ✓
     - Major7: C-E-G-B
     - Augmented7: C-E-G#-B
     - Minor7: C-E♭-G-B♭
     - Diminished7: C-E♭-G♭-A
  2. Inversions ✓
     - All maintain correct intervals
     - Seventh quality preserved
  3. Extended Chords ✓
     - 9/11/13 extensions maintain correct seventh
     - Proper interval stacking verified

## Testing Plan
1. Test each chord quality with seventh extension:
   - Major7 (C-E-G-B)
   - Minor7 (C-E♭-G-B♭)
   - Diminished7 (C-E♭-G♭-B𝄫)
   - Augmented7 (C-E-G♯-B)
2. Test with different inversions
3. Test with extended chord types (9/11/13)
4. Verify correct grid visualization

## Implementation Order
1. Fix chord generation (seventh calculations)
2. Clock system rebuild
3. Note pool/pattern engine restructure

## Key Architectural Decisions

### Clock System
- Keep per-channel pulse configuration
- Express event timing as fractions of pulse
- Use existing music_utils for fraction handling
- Maintain visual feedback through current grid system
- Polyrhythm support through clock mod (no explicit system needed)

### Note System
- Pattern Engine should be completely agnostic of Note Pool source
- Two primary note pool modes:
  1. Chord-based (current system)
  2. Grid-selected (scale degree approach)
- Note selection UI:
  - Enter/exit via params binary trigger
  - Save on exit
  - Audio feedback using channel's MIDI settings
  - Visual indication of edit mode
- Maintain consistent grid layout across all modes
- Keep current random/locked-random modes (defer more complex randomization)

## Future Considerations
- More complex randomization/evolution systems
- Enhanced pattern visualization
- Additional note pool sources
- Extended grid playability in all modes 
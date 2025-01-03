# Seeker II Test Plan

## 1. Duration System Tests

### ~A. Basic Duration Control~
- ~Test each note length option (1/16 through 16)~
- ~Verify musical timing is exact~ 
- ~Test in each behavior mode (Pulse, Strum, Burst)~
- ~Verify duration changes are reflected in debug output~

### ~B. Variance Testing~
- ~Test each mode:~
  1. ~Fixed: Verify subtle humanization (0-25%)~
  2. ~Pattern: Test each shape:~
     - ~Pendulum: Clear long-short alternation~
     - ~Mountain: Smooth rise and fall~
     - ~Valley: Smooth fall and rise~
     - ~Steps: Consistent random pattern~
     - ~Gather: Progressive shortening~
     - ~Scatter: Progressive lengthening~
- Test with external clock input:
  - Use crow inputs 1 and 2 for clock
  - Test pulse width to duration mapping
  - Verify eurorack integration

### ~C. Pattern Mode~
- ~Test pattern length parameter (2-16)~
- ~Verify pattern restarts correctly~
- ~Test interaction with base duration~
- ~Test min/max range behavior~

## 2. Integration Tests

### ~A. Duration + Strum~
- ~Test duration control of individual strum notes~
- ~Verify strum timing remains musical~
- ~Test with different variance styles~

### ~B. Duration + Burst~
- ~Test duration control of burst events~
- ~Verify burst pattern integrity~
- ~Test with different variance styles~

### C. Duration + Expression
- Test interaction with velocity patterns
- Verify independent operation
- Test timing synchronization

## 3. Musical Tests

### A. Textural Patterns
- Create and test duration presets for:
  1. Tight rhythmic patterns
  2. Loose atmospheric textures
  3. Natural-feeling variations
- Test integration with effects (reverb, delay)
- Verify effectiveness for building atmospheric spaces

### B. Melodic Development
- Test duration's effect on:
  1. Phrase length
  2. Note articulation
  3. Pattern development
- Test clock-driven chord changes
- Verify parameter modulation (extensions, inversions, note count)
- Evaluate effectiveness for creating lead material

## 4. Performance Tests

### A. UI/UX
- Verify debug table readability
- Test parameter navigation
- Verify musical terms are clear
- Implement debug event tables as primary UI aesthetic
- Test preset-based approach:
  - Move away from complex configuration
  - Keep musical parameters exposed
  - Hide technical complexity
  - Verify preset save/load functionality

### B. Grid Integration
- Test start/stop functionality
- Verify visualization is helpful
- Test pattern monitoring
- Implement grid as visualization surface:
  - Abstract pattern activity visualization
  - Trigger interval indicators
  - Paramquencer step visualization
  - Basic control for start/stop

### C. Grid Visualization Tests
1. Scale/Note Mapping
   - Test different scales (major, minor, etc.) for correct degree mapping
   - Verify octave relationships and positioning
   - Check out-of-bounds indication for notes above/below range
   - Test scale degree to grid position alignment

2. Multi-Channel Operation
   - Run multiple channels simultaneously
   - Verify note visualization in correct channel sections
   - Test start/stop functionality per channel
   - Check for visual interference between channels

3. Performance Edge Cases
   - Test Strum mode with multiple simultaneous notes
   - Test Burst mode with rapid note visualization
   - Verify proper clearing of note-off events
   - Check system performance with all channels active

4. Scale/Key Changes
   - Change global key during playback
   - Modify global scale during playback
   - Test octave shifts using global octave parameter
   - Verify visualization updates correctly

5. Visual Feedback
   - Evaluate brightness levels for all states
   - Test out-of-bounds flash rate
   - Check visibility of simultaneous notes
   - Verify start/stop button feedback

## 5. Paramquencer Development

### A. Core Functionality
- Test multi-parameter sequencing at different intervals
- Verify independent timing for parameters
- Test core musical parameters:
  1. Chord progression
  2. Extensions (7th, 9th, etc.)
  3. Inversions
  4. Note count/range

### B. Use Case Testing
- Test melodic development:
  - Chord modulation effectiveness
  - Parameter sequencing musicality
  - Lead material generation
- Test textural generation:
  - Complex strum patterns
  - Effects integration
  - Atmospheric space creation

## 6. Future Development: Timing System

### A. Core Timing Features
- Timing Modes:
  - Normal: Standard note divisions
  - Dotted: Extended note lengths
  - Triplet: Three-based divisions
  - Custom: User-defined ratios
- Swing/Groove:
  - Global swing amount
  - Per-channel groove patterns
  - Micro-timing adjustments
- Polyrhythmic Support:
  - Independent channel timing
  - Cross-rhythm generation
  - Phase relationships

### B. Timing Integration
- Clock system improvements:
  - More precise scheduling
  - Better handling of long-term timing
  - Reduced drift over time
- Grid visualization:
  - Timing relationship display
  - Pattern phase indication
  - Polyrhythm visualization
- External sync:
  - Improved crow timing integration
  - Better handling of external clock jitter
  - Multiple clock source support

### C. Musical Features
- Pattern-based timing:
  - Euclidean rhythm support
  - Time signature changes
  - Complex meter handling
- Groove templates:
  - Classic drum machine feels
  - DAW-style groove import
  - User-defined groove patterns
- Performance tools:
  - Real-time timing manipulation
  - Pattern transformation
  - Rhythmic variation generation

### D. Expression System
- Pattern shapes for velocity:
  - Port duration patterns (Mountain, Valley, etc.)
  - Sync pattern length with duration patterns
  - Independent pattern lengths per parameter
- Advanced expression control:
  - Multiple parameter modulation
  - Cross-parameter relationships
  - Pattern-based parameter locks

### E. Burst System
- Configurable event counts:
  - Per-style default counts
  - User-adjustable ranges
  - Pattern-length sync options
- Style enhancements:
  - Pattern-based density control
  - Probability-based variations
  - Euclidean distribution options

## Next Steps

1. **Immediate**
   - Complete basic duration testing
   - Document any timing inconsistencies
   - Note opportunities for presets
   - Implement debug table UI

2. **Short Term**
   - Implement duration presets
   - Enhance debug visualization
   - Add grid visualization
   - Refactor params menu structure

3. **Future**
   - Explore broader locked random system
   - Consider duration sequencing
   - Investigate effect integration
   - Consider transition to lattice
   - Investigate scale mask approach for chord system 
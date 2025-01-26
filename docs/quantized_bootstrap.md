# Quantized Playback Implementation

## Current Implementation

### Grid Division System
- Grid divisions range from 4 whole notes to 1/32 notes
- Values: 4 whole (0.25), 2 whole (0.5), whole (1), 1/2, 1/3, 1/4, 1/5, 1/6, 1/7, 1/8, 1/9, 1/12, 1/16, 1/24, 1/32
- Display format: "4 whole", "2 whole", "whole", "1/4", etc.

### Speed Control
- Independent grid speed multiplier
- Values: 0.25x, 0.5x, 1x, 2x, 3x, 4x, 6x, 8x
- Applies to any grid division

### Gate Length
- Controls note duration as percentage of grid division
- Range: 0-400%
- Default: 90%

## Next Steps

### Phase 1: Timing System Cleanup
1. [ ] Simplify event generation to use step sequencer approach
2. [ ] Fix speed implementation to multiply grid_division
3. [ ] Remove unused transform_sequence code
4. [ ] Consolidate rest types into single concept

### Phase 2: Rhythmic Transforms
1. [ ] Design transform API for rhythm changes
2. [ ] Implement basic transforms (double/half time)
3. [ ] Add triplet and dotted rhythm support
4. [ ] Test transform combinations

### Phase 3: Pattern Enhancement
1. [ ] Add step repeat/ratcheting
2. [ ] Implement probability per step
3. [ ] Add swing timing control
4. [ ] Support pattern direction changes

## Timing System Analysis

### Areas of Complexity

1. **Multiple Time Bases**
   - Free mode uses recorded time (beat-relative)
   - Grid mode uses fixed divisions
   - Switching between them requires different event generation paths
   - SUGGESTION: Could unify by converting free mode to closest grid division

2. **Stage Transition Timing**
   - Stage transitions only occur after all events complete
   - Complex interaction between:
     - Loop rest
     - Stage rest
     - Note durations
     - Grid division
   - SUGGESTION: Simplify by making transitions beat-aligned

3. **Event Generation**
   - Pre-calculates all events for entire stage
   - Stores in large event table
   - Complex sorting and processing
   - SUGGESTION: Could use simpler step-by-step generation

4. **Clock Synchronization**
   - Multiple sync points:
     - Initial stage sync
     - Per-event sync
     - Loop boundaries
   - SUGGESTION: Reduce sync points to beat boundaries only

5. **Speed Implementation**
   - Currently divides grid_division by speed
   - Makes faster speeds create smaller divisions
   - Counter-intuitive relationship
   - SUGGESTION: Multiply grid_division by speed instead

### Unnecessary Complexity

1. **Stage-specific Parameters**
   - Removed stage-specific grid divisions
   - Transforms are better way to handle rhythmic changes
   - Keeps parameter space simpler

2. **Transform Sequence**
   - Unused transform_sequence code remains
   - Should be removed or properly implemented

3. **Event Table Generation**
   - Generates all events upfront
   - Could use simpler step sequencer approach
   - Would reduce memory usage and complexity

4. **Multiple Rest Types**
   - Both loop_rest and stage_rest
   - Could be unified into single rest concept
   - Would simplify timing calculations

## Future Considerations

1. **Rhythmic Transforms**
   - Add transforms for:
     - Double/half time
     - Triplet conversion
     - Dotted rhythms

2. **Pattern Features**
   - Step repeats (ratcheting)
   - Probability per step
   - Swing timing
   - Direction (forward/reverse/pendulum)

3. **UI Improvements**
   - Visual grid representation
   - Clearer relationship between speed and division
   - Better transition visualization 
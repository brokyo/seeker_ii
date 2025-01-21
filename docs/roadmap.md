# Seeker II Roadmap

## Keyboard Improvements (Current Focus)

### Phase 1: Theory Foundation
1. **Document Current Musical Properties**
   - [ ] Map out the "walking paths" through the scale
   - [ ] Document how thirds and seconds interact
   - [ ] Analyze diagonal movement patterns
   - [ ] Create visual diagram of voice leading options
   - [ ] Identify key resolution points

2. **Pure Theory Utils Refactor**
   - [ ] Extract scale degree calculation (preserving thirds/seconds relationship)
   - [ ] Create `theory.get_scale_position(x, y)` that maintains current musical paths
   - [ ] Add `theory.get_next_resolution(current_pos)` to find natural endpoints
   - [ ] Implement position-relative interval calculation
   - [ ] Add tests that verify musical relationships

3. **Transposition Logic**
   - [ ] Ensure offset calculations preserve scale relationships
   - [ ] Implement relative movement that maintains voice leading
   - [ ] Add position normalization that keeps musical paths intact
   - [ ] Create tests for melodic continuity

### Phase 2: Musical Suggestion System
1. **Core Musical Constants**
   - [ ] Define brightness hierarchy (resolution → leading → counterpoint → played)
   - [ ] Map out scale positions and their musical magnetism
   - [ ] Create clear rules for suggestion priority
   - [ ] Document musical reasoning for each suggestion type

2. **Suggestion Algorithms**
   - [ ] Implement `theory.get_resolution_targets(note)` for strongest musical pulls
   - [ ] Add `theory.get_voice_leading_options(note)` for stepwise motion
   - [ ] Create `theory.get_counterpoint_options(note)` for harmonic sweet spots
   - [ ] Build tests verifying musical relationships

3. **Grid Integration**
   - [ ] Create efficient note-to-position mapping
   - [ ] Handle multiple instances of same pitch
   - [ ] Implement brightness layering system
   - [ ] Add smooth transitions between states

4. **Performance Optimization**
   - [ ] Cache common musical relationships
   - [ ] Optimize grid position lookups
   - [ ] Minimize recalculations during playback
   - [ ] Profile and optimize critical paths

### Phase 3: Grid Component Enhancement
1. **Local State Management**
   - [ ] Add keyboard state to Grid component
   - [ ] Create position cache system
   - [ ] Implement efficient cache invalidation
   - [ ] Add debug visualization helpers

2. **Parameter Integration**
   - [ ] Define keyboard parameters in params_manager
   - [ ] Add keyboard offset parameters
   - [ ] Create parameter handlers in Grid component
   - [ ] Implement parameter persistence

### Phase 4: UI Manager Integration
1. **Keyboard Page**
   - [ ] Add keyboard configuration page to UI manager
   - [ ] Create keyboard parameter categories
   - [ ] Add visual feedback for current position
   - [ ] Implement keyboard transpose controls

2. **Focus System**
   - [ ] Integrate keyboard with focus system
   - [ ] Add keyboard state to UI manager's redraw coordination
   - [ ] Implement keyboard mode transitions
   - [ ] Add visual indicators for keyboard state

### Phase 5: Visual Enhancements
1. **Root Note Visibility**
   - [ ] Always highlight root notes at consistent brightness
   - [ ] Create subtle pulse animation for roots
   - [ ] Ensure roots visible across all modes
   - [ ] Add root position indicators

2. **Musical Suggestion Visualization**
   - [ ] Implement brightness hierarchy from suggestion system
   - [ ] Create smooth transitions between suggestion states
   - [ ] Add subtle animations for stronger suggestions
   - [ ] Design clear visual language for different suggestion types

3. **Playback Integration**
   - [ ] Extend suggestion system to played notes
   - [ ] Show upcoming resolution possibilities
   - [ ] Highlight parallel motion opportunities
   - [ ] Create "heat trails" for melodic patterns

4. **Performance Feedback**
   - [ ] Show "breadcrumb" trail of recent notes
   - [ ] Highlight successful resolution moments
   - [ ] Indicate potential harmonic combinations
   - [ ] Create visual feedback for voice leading

## Implementation Notes

### Architecture Patterns
- Grid component owns keyboard UI state
- Theory utils provides pure musical calculations
- UI manager coordinates state changes
- Params manager handles persistent state

### State Flow
1. User input → Grid component
2. Grid updates params through params_manager
3. UI manager coordinates redraws
4. Theory utils calculates pure musical relationships

### Testing Strategy
1. Unit tests for theory utils
2. Integration tests for parameter system
3. Visual tests for grid layout
4. Performance tests for cache system

### Musical Design Principles
- Root notes always visible as anchor points
- Suggestions guide but don't prescribe
- Multiple valid paths always available
- Visual hierarchy matches musical importance

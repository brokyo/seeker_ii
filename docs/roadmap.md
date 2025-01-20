# Seeker II Development Roadmap

## Phase 1: Core Playback System ✅
1. **Timing System Overhaul** ✅
   - Implemented absolute beat-based timing
   - Added comprehensive timing tests
   - Verified sub-10ms timing accuracy
   - Documented timing architecture
   - Added statistical analysis of timing performance

2. **Code Organization** ✅
   - Standardized terminology (voice → lane)
   - Added architectural documentation
   - Cleaned up conductor.lua structure
   - Removed deprecated functions
   - Added detailed implementation notes

3. **Testing Infrastructure** ✅
   - Built comprehensive test suite
   - Added timing statistics collection
   - Created varied test cases
   - Proper coroutine management
   - Edge case coverage

## Phase 2: Grid Integration (Current)
1. **Parameter Management System**
   - Move all lane configuration to params system:
     - Instrument/voice assignment
     - Base octave settings
     - Loop/stage rest durations
     - Stage transform settings
   - Create minimal but functional UI:
     - Parameter selection via encoder 2
     - Value adjustment via encoder 3
     - Clear parameter grouping by lane
     - Visual feedback for changes

2. **Grid Interaction**
   - Test with real recorded motifs
   - Verify timing with human input
   - Add visual feedback during playback
   - Ensure proper grid position handling

3. **Timing Modes**
   - Implement "free" timing mode
   - Add grid quantization system
   - Support switching between modes
   - Preserve timing accuracy in both modes

4. **UI Development** ✅
   - Lane configuration controls ✅
   - Loop and rest duration controls ✅
   - Stage configuration ✅
   - Basic playback status display ✅
   - Visual metronome/position indicator ✅
   - Hardcoded parameter sets for clarity ✅
   - Robust initialization without timing hacks ✅
   - Clear separation between lane and stage parameters ✅

5. **Performance Features**
   - Lane mute/solo functionality
   - Real-time pattern control
   - Quick pattern switching
   - Performance macro controls

## Phase 3: Transform System
1. **Stage Sequence Infrastructure**
   - Define stage sequence data structure
   - Implement stage transition logic
   - Add stage queuing system
   - Handle stage rest periods

2. **Transform Pipeline**
   - Create transform function interface
   - Implement transform parameter validation
   - Add transform preview capability
   - Build transform chain processing

3. **Basic Transforms**
   - Note pitch transforms (transpose, invert)
   - Time-based transforms (reverse, shift)
   - Simple pattern mutations (skip, repeat)
   - Transform parameter interpolation

4. **Transform Timing**
   - Precise transform scheduling
   - Multi-lane transform sync
   - Transform boundary handling
   - Rest period management

## Phase 4: Advanced Features
1. **Multi-Lane Synchronization**
   - Lane sync groups
   - Coordinated transform timing
   - Cross-lane transform relationships
   - Pattern phase alignment

2. **Pattern Storage & Recall**
   - Save/load pattern data
   - Transform sequence persistence
   - Pattern variation management
   - Quick pattern switching

## Implementation Notes
- Each phase maintains stable, usable state
- Features added iteratively with testing
- Documentation updated continuously
- UI feedback immediate and clear
- Performance and timing verified at each step

# Seeker II Development Roadmap

<update_guidelines>
# ROADMAP UPDATE GUIDELINES
- Only mark items as complete [x] when they are fully implemented and tested
- Never remove tasks unless explicitly decided to drop them
- Keep all detailed subtasks even after parent task is complete
- Add new tasks or notes at appropriate sections
- Preserve all task structure and hierarchy
</update_guidelines>

## Phase 1: Core Pattern System
**Goal**: Replace current pattern system with Reflection-based implementation

- [x] Create `reflection_manager.lua`
  - [x] Basic pattern creation and management
  - [x] Basic pattern management (single pattern)
  - [x] Implement quantization support
    - [x] Add quantization settings to pattern (1/16 fixed for now)
    - [x] Apply quantization during recording
    - [x] Test timing accuracy

- [x] Update main script (`seeker_ii.lua`)
  - [x] Remove Lattice dependencies
  - [x] Initialize Reflection system
  - [x] Basic pattern playback test

## Phase 2: Grid UI & Basic Controls
**Goal**: Implement basic recording and playback with new system

- [ ] Create Simple UI Manager (`lib/ui_manager.lua`)
  - [ ] Basic screen drawing utilities
  - [ ] Voice selection display (E1)
  - [ ] Parameter navigation (E2)
  - [ ] Value adjustment (E3)
  - [ ] Initial parameters:
    - [ ] Quantization division
    - [ ] Recording length
    - [ ] Pattern sync options

- [x] Update Grid UI (`lib/grid.lua`)
  - [x] Basic recording controls
  - [x] Basic pattern control layout
  - [x] Visual feedback for recording/playback state
  - [ ] Visual metronome for selected division

- [ ] Update Parameters (`lib/params_manager.lua`)
  - [ ] Recording quantization parameters
    - Division selection (none, 1/4, 1/8, 1/16)
    - Recording length in beats
  - [ ] Basic pattern sync options
  - [ ] Update existing musical parameters

## Phase 2.5: Multi-Voice System
**Goal**: Support multiple independent playback lanes with separate instruments

- [ ] Expand Reflection Manager
  - [ ] Support for 4 independent patterns
  - [ ] Per-pattern instrument selection
  - [ ] Per-pattern octave settings
  - [ ] Independent recording/playback controls

- [ ] Update Grid UI
  - [ ] Four-row layout for pattern lanes
  - [ ] Visual feedback per voice
  - [ ] Independent record/play/clear controls per voice
  - [ ] Adapt keyboard region for active voice

- [ ] Enhance Parameters
  - [ ] Per-voice instrument selection
  - [ ] Per-voice base octave setting
  - [ ] Per-voice volume controls
  - [ ] Voice mute/solo options

- [ ] Voice Management
  - [ ] Voice activation/deactivation
  - [ ] Pattern persistence per voice
  - [ ] Voice state visualization
  - [ ] Independent quantization settings

## Phase 3: Transform System
**Goal**: Implement the transformation and sequencing system

- [ ] Create transform system
  - [ ] Port existing transformations to work with Reflection events
  - [ ] Implement revert functionality using Reflection's event system

- [ ] Sequence step system
  - [ ] Step configuration data structure
  - [ ] Transform parameter system
  - [ ] Wait bars and revert options

## Future Enhancements
- Pattern storage/loading using Reflection's built-in functions
- Pattern length configuration
- Pattern doubling/halving
- Pattern randomization
- Pattern mutation options
- Pattern chaining across voices
- Additional transform types
- MIDI/Link sync options
- Pattern variation system
- Probability controls for transforms
- More granular quantization options (triplets, swing)

## Development Notes
- Reflection provides better timing and sync than Lattice
- Module instance management is critical for state consistency
- Grid UI layout standardized (x=4-12 for keyboard, x=6-10 for transforms)
- Voice-by-row system provides clear separation of patterns 

## Hotfixes
- [x] Automatically load presets (save/load parameter state between sessions) 
  - [x] Add params:read() and params:write() to init/cleanup
  - [x] Fix initialization order to prevent dependency cycles
  - [x] Document dependency management patterns 
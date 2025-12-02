### Current Session

### Active Concerns

### Near Term Priorities

### Bugs

### Long List
- [] Rename arpeggio → composer architecture (breaking change). Includes: file names (arpeggio_sequence.lua → composer_sequence.lua), parameter IDs (arpeggio_* → composer_*), variable names. Requires pset migration strategy for backward compatibility.
- [] W/Tape pitched sample mode
- [] Disting SD 6 Triggers support
- [] Refactor Arc to per-component pattern (currently global, unlike Grid/Screen). Start by extracting component-specific handlers from arc.lua.
- [] Move mode logic from components to mode definitions. Start by auditing conditional render checks in component draw() functions.
- [] Consolidate duplicated clock utilities into shared module. Start by collecting all division_to_beats() and sync_options implementations.
- [] Clarify param ownership between lane infrastructure and components. Start by mapping which params are created where vs used where.
- [] Move playback config from Lane to Motif. Start by identifying which Lane properties are actually Motif behavior.
- [] Separate trail visual feedback from Lane
- [] Refactor note event structure and creation
- [] Add MIDI CC to control Ableton recording

### Open Questions
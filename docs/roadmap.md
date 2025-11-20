### Current Session

### Active Concerns

### Near Term Priorities
- [] W/Tape pitched sample mode
- [] Disting SD 6 Triggers support
- [] Alternate keyboard mode supporting easier two handed playing

### Bugs

### Long List
- [] **Architectural Debt: Param Ownership** - Current split between lane_infrastructure, stage_config, lane_config, and arpeggio_params works but is conceptually messy. Future refactor options:
  - Split lane_config.init() into early param creation + late UI creation. Allows components to reference lane params during their init. Medium risk.
  - Delete lane_infrastructure entirely. Each component (lane.lua, arpeggio_sequence.lua, tape_transform.lua) creates its own params during init. True component ownership. High risk - requires solving initialization order dependencies.
- [] **Architectural Debt: Lane/Motif Separation** - Playback config (speed, playback_offset, scale_degree_offset, quantize) currently lives on Lane but conceptually belongs to Motif behavior. Consider moving to Motif object for better separation of concerns. Lane = execution channel (voices, routing), Motif = musical pattern + playback behavior.
- [] Refactor trail/tail visual feedback system to separate rendering from Lane
- [] Note Event Refactoring
-- [] Create consistent note event structure in a single place
-- [] Separate live vs playback event creation logic
-- [] Move event param handling out of `Lane:on_note_on`
- [] Add MIDI CC to control ableton recording
- [] Support second Crow

### Open Questions
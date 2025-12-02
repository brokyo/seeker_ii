### Current Session

### Active Concerns

### Near Term Priorities

### Bugs

### Long List
- [] W/Tape pitched sample mode
- [] Disting SD 6 Triggers support
- [] **Architectural Debt: Arc Controller** - Arc was written before I really understood it and all logic is encapsulated in one file. Unlike Grid/Screen which are per-component, Arc is a single global controller that accesses components via `_seeker.component_name`. This requires exposing component functions on the component instance for Arc to call them (e.g., crow_output exposes handle_encoder_input, record_knob, stop_recording_knob). Consider refactoring Arc to be per-component like Grid/Screen for better encapsulation.
- [] **Architectural Debt: Mode System Grid Component Registration** - Components currently check motif_type in draw() to conditionally render (e.g., arp_stage_config vs tuning at same grid position). Mode definitions should specify both screen sections AND active grid components per mode/state. Components shouldn't contain mode logic.
- [] **Architectural Debt: Clock Utilities Duplication** - division_to_beats() and sync_options are duplicated across OSC, eurorack (crow, txo), arpeggio_params, stage_config, and transforms. Should be consolidated into lib/clock_utils.lua for shared tempo/sync utilities.
- [] **Architectural Debt: Param Ownership** - Current split between lane_infrastructure, stage_config, lane_config, and arpeggio_params works but is conceptually messy. Future refactor options:
  - Split lane_config.init() into early param creation + late UI creation. Allows components to reference lane params during their init. Medium risk.
  - Delete lane_infrastructure entirely. Each component (lane.lua, arpeggio_sequence.lua, tape_transform.lua) creates its own params during init. True component ownership. High risk - requires solving initialization order dependencies.
- [] **Architectural Debt: Lane/Motif Separation** - Playback config (speed, playback_offset, scale_degree_offset, quantize) currently lives on Lane but conceptually belongs to Motif behavior. Consider moving to Motif object for better separation of concerns. Lane = execution channel (voices, routing), Motif = musical pattern + playback behavior.
- [] Refactor trail visual feedback system to separate rendering from Lane
- [] Note Event Refactoring
-- [] Create consistent note event structure in a single place
-- [] Separate live vs playback event creation logic
-- [] Move event param handling out of `Lane:on_note_on`
- [] Add MIDI CC to control ableton recording

### Open Questions
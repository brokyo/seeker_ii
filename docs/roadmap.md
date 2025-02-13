### Current Session

### Next Session
- [] Generated patterns to create x/y values
- [] Improve starlight transform

### Long List
- [] Confirmation animations on double click
- [] app_on_screen is vestigial. Remove it.
- [] Review `theory_utils.grid_to_note()` — `scales[scale_type].intervals` isn't real. What is this thing even doing?
- [] Long press for overdub in rec section
- [] Improve transform UI
- [] Add MIDI CC to control ableton recording
- [] Review Harmonize transform
- [] Add param preset saving
- [] Reverse transform may break duration
- [] Transforms should update x/y positions
- [] REC button pulsing and play button illumination are LLM generated without review. Take a close look.
- [] Catch MIDI events (rather than grid) in `motif_recorder`
- [] Review keyboard region in `grid_ii.lua`. Everything else has been refactored into region components. Didn't do keyboard due to potential dependencies.


### Bugs

### Open Questions


### Done
- [x] Ensuring notes are getting recorded into motif_recorder
- [x] Volume control for each lane
- [x] Lanes respect instrument settings
- [x] Return background animation
- [x] Transform logic should live on `Motif` and `Lane` just calls it
- [x] UI — FRAME
- [x] UI — RECORDING
- [x] Restore theory_utils.print_keyboard_layout()
- [x] UI — MUSICAL
- [x] Highlight active lane
- [x] Add speed control for each lane
- [x] UI — LANES
- [x] UI — STAGES (basic)
- [x] Stage playback ignoring settings
- [x] Scrollable params list
- [x] UI — STAGES (transform)
- [x] Transform parameters have configurable type and step
- [x] Highlight root note on keyboard
- [x] Change controls > one row for lanes; one row for stages
- [x] Add per-lane MIDI support and associated params
- [x] Revisit `theory_utils.lua`; it is one of the final holdovers from the old codebase.
- [x] Ensure keyboard is generating correct note structure
- [x] Add Per-lane octave control and associated params
- [x] Play non-focused lanes grid illumination in background with dimmer light 
- [x] Make Lane playback speed controllable per-lane
- [x] Add duration controls to motif
- [x] All stages default to reset motif
- [x] UI Overhaul
- [x] Transform chains
- [x] Optional crow output
- [x] Universal timeline view
- [x] Motif view
- [x] Overdubbing
- [x] Figure out a solution for velocity. There needs to be some way of broadly controlling. Looped MIDI at 127 velocity is just too unpleasant
- [x] Grid logic cleanup (modular regions)
- [x] Footer navigation (current lane and stage)
- [x] "screen saver" that sets core view to blinkenlights. Changes back to controls on encoder or key.
- [x] TXO Support
- [x] Events on loop/stage end
- [x] `ui_state_ii` should handle key and enc events
- [x] Motif pattern generation from preset. "Quickstart presets"
- [x] Fix footer padding
- [x] Set default UI section to CONFIG
- [x] Flash grid outline when motif is generated
- [x] Improve grid recording state animation
- [x] Lane button toggle playback state.
- [x] Add double-tap pattern for executing actions with regions
- [x] Review how we create the grid in theory_utils.lua


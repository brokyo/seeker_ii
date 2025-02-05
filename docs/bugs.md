### Current Session
[] Change controls > one row for lanes; one row for stages
[] Per-lane octave control
[] Check velocity/pitter-patter approach to amplitude control


### Next Session
[] MIDI
[] Add duration
[] Transforms should update x/y positions
[] Multi-transform

### TODOs
[] Clean up `theory_utils.lua`
[] Return param preset saving
[] REC button pulsing and play button illumination are LLM generated without review. Take a close look.
[] Catch MIDI events (rather than grid) in `motif_recorder`
[] Pitch shift option for speed


### Bugs
[] `Lane` speed does not affect timeline as expected. Smaller numbers are faster, bigger are slower.

### Done
[x] Ensuring notes are getting recorded into motif_recorder
[x] Volume control for each lane
[x] Lanes respect instrument settings
[x] Return background animation
[x] Transform logic should live on `Motif` and `Lane` just calls it
[x] UI — FRAME
[x] UI — RECORDING
[x] Restore theory_utils.print_keyboard_layout()
[x] UI — MUSICAL
[x] Highlight active lane
[x] Add speed control for each lane
[x] UI — LANES
[x] UI — STAGES (basic)
[x] Stage playback ignoring settings
[x] Scrollable params list
[x] UI — STAGES (transform)
[x] Transform parameters have configurable type and step
[x] Highlight root note on keyboard

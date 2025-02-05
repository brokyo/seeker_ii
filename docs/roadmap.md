### Current Session

### Next Session
[] Add Per-lane octave control and associated params

### Long List
[] Stage UI should pull current transform params
[] Start recording on first note played rather than rec button press
[] Play non-focused lanes grid illumination in background with dimmer light 
[] Ensure keyboard is generating correct note structure
[] Add duration controls to motif (and maybe individual stages?)
[] Transforms should update x/y positions
[] Multi-transform
[] Revisit `theory_utils.lua`; it is one of the final holdovers from the old codebase.
[] Add param preset saving
[] REC button pulsing and play button illumination are LLM generated without review. Take a close look.
[] Catch MIDI events (rather than grid) in `motif_recorder`
[] Pitch shift option for speed


### Bugs
[] `Lane` speed does not affect timeline as expected. Smaller numbers are faster, bigger are slower.

### Open Questions
[] Mx Samples don't seem to always support velocity. Check velocity/pitter-patter approach and why it has "amplitude" control.
[] Some Mx Samples don't seem to respect note_off. Are we terminating those correctly?
[] Consider recording start and end times. Should we start the loop on the first note? When "rec" is pressed?


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
[x] Change controls > one row for lanes; one row for stages
[x] Add per-lane MIDI support and associated params

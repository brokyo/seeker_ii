### Current Session
[x] Restore theory_utils.print_keyboard_layout()
[x] UI — MUSICAL
[x] Highlight active lane
[x] Add speed control for each lane
[x] UI — LANES
[x] UI — STAGES (basic)
[x] Stage playback ignoring settings
[x] Scrollable params list
[] UI — STAGES (transform)


### Next Session
[] Add duration
[] Highlight root note on keyboard
[] Base octave for each lane
[] Change illumination for active stage
[] Return param preset saving

### TODOs
[] Clean up `theory_utils.lua`
[] Rethinking process for drawing control panels on `grid_ii.lua`. Should think about stages and rec/play buttons as one unit.
[] Revisit `theory_utils.lua`
[] Catch MIDI events (rather than grid) in `motif_recorder`
[] Layer blending logic for illumination
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

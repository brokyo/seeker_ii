### Current Session
[] UI — FRAME


### Next Session
[] UI — MUSICAL 
[] UI — RECORDING
[] UI — STAGES
[] UI — LANES

### TODOs
[] Change illumination for active stage
[] Return param preset saving
[] Base octave for each lane
[] Revisit `theory_utils.lua`
[] Catch MIDI events (rather than grid) in `motif_recorder`
[] Layer blending logic for illumination

### Bugs
[] `Lane` speed does not affect timeline as expected. Smaller numbers are faster, bigger are slower.

### Done
[x] Ensuring notes are getting recorded into motif_recorder
[x] Volume control for each lane
[x] Lanes respect instrument settings
[x] Return background animation
[x] Transform logic should live on `Motif` and `Lane` just calls it
- * General Ideas *
- Should it just all be presets rather than this super configurable stuff?
- Should we drop all of the /4, /2, *2 duration clock mod shit and just use the b system from expression?
- Always check Norns docs (monome.org/docs/norns/api/) for idiomatic solutions:
  ✓ Using metro for timing instead of clock.run/sleep
  ✓ Leveraging built-in modules where possible
  - Future reference for timing, grid, UI patterns

- *Velocity Testing*
- Pulse or Wave patterns

- * Norns UI*
- Should this just be the debugger table? It's a cool aesthetic and may call to mind the patterns this creates.
- It will also be so much easier than struggling with the logging and I'm sure clogging memory

- * Grid UI *
✓ Start/stop patterns from grid implemented
✓ Visual pulse feedback for active channels
- Future ideas:
  - Show melodic/rhythmic activity
  - Paramquencer step visualization
  - Abstract pattern visualization

- * Burst *
- Presets are great, but we should be able to select size (num pulses) too. Small, medium, large
- I wonder if these should have note duration too

- * Presets *
- I still have to manually load the PSET. Can we automate this so –it loads on start?

**Expression**
- Should have sine pattern

**Arpeggiation**
- Should really just have pattern style/step stuff
- Chord should be its own group

**Chord**
- Should cover whole scale and chords. Don't know how to do thiss

**Musicality/Paramquencer**
- Should we explore key changes?

- Note duration also needs to come soon.
- The Arpeggiator param is overloaded, arpeggiation and note space need to be distinct ideas
- I really wish I had some quality-of-life stuff on the grid. Start/stop, some visual indicator of what's happening melodically
- "playing" the chord degree with the encoder is really fun and a nice performative idea
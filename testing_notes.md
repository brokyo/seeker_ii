- * General Ideas *
- Should it just all be presets rather than this super configurable stuff?
- Should we drop all of the /4, /2, *2 duration clock mod shit and just use the b system from expression?
- Always check Norns docs (monome.org/docs/norns/api/) for idiomatic solutions:
  ✓ Using metro for timing instead of clock.run/sleep
  ✓ Leveraging built-in modules where possible
  - Future reference for timing, grid, UI patterns

- Critical Bugs:
  - Parameter ID collision on "auto_save"
  - Startup error with set_pulse (nil value)
  - These may be preventing proper param loading
  - Chord generation using wrong intervals:
    - PRIORITY: Major/Augmented need major seventh (11 semitones)
    - Currently using minor seventh (10) for all qualities
    - Affects musicality of all extended chords

- *Velocity Testing*
- Pulse or Wave patterns

- * Norns UI*
- Should this just be the debugger table? It's a cool aesthetic and may call to mind the patterns this creates.
- It will also be so much easier than struggling with the logging and I'm sure clogging memory

- * Grid UI *
✓ Start/stop patterns from grid implemented
✓ Visual pulse feedback for active channels
✓ Basic scale degree visualization working
✓ Chord quality visualization fixed:
  - Major: 1-3-5 working
  - Minor: 1-♭3-5 working
  - Diminished: 1-♭3-♭5 working
  - Augmented: 1-3-#5 working
  - Inversions working correctly
- Known issues:
  - Burst visualization behavior:
    - Currently treats burst as single event
    - First note stays lit for entire burst duration
    - Doesn't show individual note rhythm
  - Proposed visualization approaches:
    1. Individual Note Pulses:
       - Each note gets brief pulse (like start button)
       - Shows burst rhythm clearly
       - Matches existing pulse aesthetic
    2. Progressive Lighting:
       - New notes bright, older notes dim
       - Creates visual "trail" during burst
       - Clears at end of burst
       - Could show density/pattern better
  - Need to decide which better serves musical visualization
  - Extensions partially working:
    ✓ Minor7 correct: C-E♭(D#)-G-B♭(A#)
    × Major7 wrong: Getting A# instead of B for seventh
    ✓ Diminished7 playing: C-D#(E♭)-F#(G♭)-A#
    × Augmented7 wrong: Getting A# instead of B
    - Confirmed: Using minor seventh (10) for all qualities
    - Need to differentiate major seventh (11) for Major/Augmented
  - Grid visualization working correctly:
    - All qualities show 1-3-5-7 positions regardless of alterations
    - Matches our design decision for theoretical positions
  - Need to fix seventh calculation for:
    1. Major7 (C-E-G-B)
    2. Augmented7 (C-E-G#-B)
- Design decisions:
  ✓ Show scale degrees (1-7) consistently across all scales
    - More practical for 7-row grid layout
    - Maintains consistent visual reference for scale degrees
    - Alternative (showing actual intervals) would require 12 rows
  ✓ Show notes in theoretical degree positions
    - Display altered notes (♭3, ♭5, #5) in their degree positions
    - Prioritize functional visualization over scale consistency
    - Better reflects actual musical patterns being played
    - Acceptable tradeoff: inconsistency between channels with different qualities
  ✓ Use trail visualization for all modes:
    - New notes start bright, older notes dim gradually
    - Creates visual history of recent notes
    - Shows pattern movement clearly
    - Apply to:
      - Pulse mode: Simple fade per note
      - Burst mode: Trail shows burst shape
      - Strum mode: Shows strum motion
    - Consistent visual language across modes
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

- * Strum Improvements *
- Change strum window to use fractions instead of beats
  - More intuitive for musicians (1/4, 1/2, etc.)
  - Current beat-based window is unintuitive
  - Could reuse expression system's fraction approach

- Critical strum issues:
  - Notes are playing in seemingly random order
  - Debug shows correct available notes but wrong playback sequence
  - Expected: C-E-G-C-E-G (ascending)
  - Getting: G-G-E-C-C-E (scrambled)
  - Need to fix note ordering in strum playback
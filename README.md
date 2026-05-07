# Seeker II

![hqdefault](https://github.com/user-attachments/assets/7b5fe37a-5ed3-4332-be59-d5967a2e190b)

[Full Intro on YouTube](https://www.youtube.com/watch?v=sDeOvZlGJTs)

Seeker II is an interface for writing and procedurally manipulating music and visuals. I originally wrote it on New Year’s Day 2025 to make Discreet Music-style phasing simple on a Norns. I’ve since spent the past year using it almost daily, slowly adding features whenever I found gaps between what I wanted to do and what Seeker could do.

Today it includes software instruments, a full sample chopping engine, an algorithmic chord progression builder, a sequenceable motif transformation engine, extensive Eurorack control via I2C, a W/Tape Frippertronics effect, and TouchDesigner communication — all in cross-communication on a shared clock.

Seeker begins with eight musical lanes that run in parallel, each performing its own motif recorded on Grid. Those motifs can be procedurally transformed as the program loops, creating evolving music while maintaining structure and intentionality.

It continues with Grid/Arc UIs connected to modulation sources covering every way of moving through voltage I could think of: strums, bursts, LFOs, knob recording, random walks, non-linear distributions. If it’s a way of moving through numbers, it’s probably in there.

Seeker is intended to travel with you and scale to whatever you have on hand. It works as well in a studio with towers of modules as it does on a train with a Grid and a field recorder. I’ve been relentless about user experience, and I hope that despite its complexity, it’s easy to pick up and make something that helps you expresses how you’re feeling at that moment.

Open the next.

## Requirements

**Required**
- Norns
- Grid

**Recommended**
- [mx.samples](https://github.com/schollz/mx.samples) - Seeker's default engine is fantastic mx.samples from [infinitedigits](https://norns.community/author#infinitedigits). If you purely want to use Eurorack it's not necessary, but so much of this script was designed with it in mind.
- Arc — Seeker has a lot of configurability. Arc makes that configurability pleasant. Encoders 2, 3, 4 are mapped to different significant figures for high-resolution control and realtime performability of parameters. Everything works with out it but strongly recommended.
- [Seeker TouchDesigner tox](lib/etc/td_components) — Seeker connects fairly naturally to TouchDesigner and enables a kind of visual painting that I think is a lot of fun, particularly with Arc. I've included toxs for each type of output. More on this further down.

**Optional**
- Crow — Lots of CV and gate output patterns. Clock-synced modulation with some unusual approaches.
- TXO — More CV and trigger outputs. And full polyphonic support for the TXO+ oscillators. TXO forever.
- i2c modules — Control the playback and settings of Just Friends, W/Syn, and Disting EX
- MIDI — external synths and DAWs

## Installation

In Maiden:
```
;install https://github.com/brokyo/seeker_ii
```

## Quickstart

When you first boot the app you'll see the Motif config screen with preset, root note, and scale. Press the Tape sub-mode button (15,3) to enter Tape mode on Lane 1.

1. **Select a voice** — Open lane config (4A) to choose an output voice and configure its timbre. Click k3/the grid button on the Envelope param to edit visually.

2. **Play notes** — The 6x6 square in the center is a scale keyboard (2A). It's meant to make it easy to put your hands down and play something. Bright keys are root notes, each vertical step is 4 scale degrees, each horizontal step is 1. These steps can be configured in the Tape sub-mode home screen.

3. **Record a motif** — Hold the record button (5B). A metronome appears above the keyboard and a piano roll on the Norns UI. Play a phrase. Press the record button (5B) again to stop the recording. It will begin looping.

4. **Overdub** — Hold the record button (5B) again while the motif plays to overlay new notes. If you don't like your additions head to the clear button (5C) to erase a single overdub or the whole motif.

5. **Add a transform stage** — A phrase can be manipulated after an arbitrary number of loops across four stages. Click the second stage grid button (1A), turn the active param to 'on', and add a transform to evolve the composition. The "Harmonize" transform is one of my favorite things in the app. Stack multiple stages. Compound changes to the motif or reset it in the "Config" section.

6. **Try another lane** — Select a new lane (4A). Record a complementary motif on a different instrument. Let the two voices phase against each other or offset playback speed on the playback button (5A).

### Next Steps

The above sets a base but Seeker is about more than tape loops. Try these:

- **Composer mode** — Press the Composer sub-mode button (16,3) to build algorithmic chord progressions. Click a lane on the left column to start. Each lane runs its own progression with per-stage control over degree, voicing, chord length, strum, rotation, and loop count. Arc pages give hands-on control over harmony and articulation. Think of it as expressive strumming rather than rigid note playing.

- **Sampler mode** — Seeker's looping structure works well with audio clips, particularly for glitching otherwise placid sounds. In Tape mode, select the Sampler type in Lane config (4A) and load a file or record from input. The 4x4 pad in the center (2A) will be loaded with equally-sized chopped segments from your original audio. Each pad has configurable envelope and filter. Try the "Pan Spread" transformation for engaging foley.

- **Eurorack integration** — Seeker's precise clock and scheduled events lend themselves well to Eurorack effects. In Eurorack mode (15,2) you can control Crow and TXO from audio-rate oscillation to 256 beat intervals. The CV monitor shows live voltage bars for active outputs. Tap an output to select it, hold to toggle it on/off. Made to send every kind of CV approach I could think of: standard stuff like LFOs, envelopes, noise, and clocks. But also more fun-to-write stuff like time-curved bursts, arc-recorded CV, looping random, or accumulative walks. I think you'll get totally new sounds out of things you think you know well.


## Music | Mode

The main performance space. A parent mode with two sub-modes accessed via row 3 buttons:

```
Row 2:  (13,2) WTAPE  (14,2) OSC  (15,2) EURORACK  (16,2) MOTIF (tuning)
Row 3:                              (15,3) Tape      (16,3) Composer
```

- **(16,2) Motif** — Parent tuning screen: preset, root note, scale. No grid layout.
- **(15,3) Tape** — Keyboard grid layout for recording and transforming motifs. Home screen configures grid note spacing.
- **(16,3) Composer** — Algorithmic chord progression grid. Lane buttons on the left, stage buttons on top.

Eight lanes run in parallel, each playing motifs created by either Tape or Composer. Lanes share a common stage system with configurable loop counts and transforms.

**Shared controls (Tape sub-mode):**

- **Lane Select** (4A) — Choose lane and configure voices. Multiple voices can be active per-lane.
- **Play** (5A) — Control playback: offset pitch, change speed, quantize events, swing timing. Hold to play/stop.
- **Create** (5B) — Hold to record/generate. Tape records keyboard, Sampler records pads.
- **Clear** (5C) — Hold to erase the motif. If overdubbing you can select a specific generation to remove just that layer.
- **Perform** (5D) — Hold-to-activate Mute, Accent, or Soft with configurable slew time.

### Tape | Sub-Mode (15,3)

![Tape Layout](lib/etc/readme_layout_images/Tape%20Layout.png)

Record motifs on a 6x6 scale keyboard (2A) the note velocity buttons (1B) can help add dynamics as can the voice settings (4A). After recording, motifs can be overdubbed by holding Create Motif (5B). Motifs play through a configurable number of loops and then move to the next "Stage" (1A) where they can be algorithmically manipulated. Try setting reset motif in stage config (1A) to "no" to hear music compound. Scale and keyboard spacing can be configured from the Tape home screen.

**Controls:**
- **Stage Config** (1A) — Configure transforms and loop counts.
- **Note Velocity** (1B) — Two dynamic levels (low, high). Select from grid.
- **Keyboard Tuning** (1C) — Octave up/down buttons to transpose the keyboard.
- **Dual Keyboard** — Toggle the option in Create (5B) to split the keyboard into two zones with separate octaves.

**Try:** Play one rhythmic pulse and keep recording for awhile. Overdub several generations of harmony onto the loop. Then set Overdub Filter in Stage Config (1A) to selectively add and remove those overdubs.


### Composer | Sub-Mode (16,3)

![Composer Layout](lib/etc/readme_layout_images/Compose%20Layout.png)

An algorithmic chord progression builder. Click a lane on the left column to start — each lane runs its own progression with independent snapshots. Stages define chords that cycle with per-stage control over harmony and articulation.

**Grid layout:**
- **Col 1, rows 1-8** — Lane selector. Tap to focus lane and load its snapshot. Hold to play/stop.
- **Row 2, cols 2-9** — Stage buttons. Tap inactive to extend, tap active to pin/unpin for editing, hold active to truncate.
- **(2,7)** — Randomize. Hold 1.0s to confirm.

**Per-stage overrides** (via arc or encoder):
- **Degree** — Which scale degree the chord is built on (I-VII).
- **Voicing** — How chord notes are arranged (close, drop2, spread, etc.).
- **Chord Length** — How many notes from the chord to play.
- **Strum Order** — Direction of the strum (up, down, center-out, random, etc.).
- **Rotation** — Inversion offset applied to the chord.
- **Loops** — How many times this stage repeats before advancing.

**Arc pages** (cycle with arc button):
- **Page 1 (Harmony)** — Ring 1: Degree, Ring 2: Chord Len, Ring 3: Voicing, Ring 4: Rotation
- **Page 2 (Articulation)** — Ring 1-2: Spread (coarse/fine), Ring 3: Strum Order, Ring 4: Loops

**Try:** Set 3-4 stages with different degrees. Give each stage different loop counts (1, 2, 1, 3) so the cycle length is asymmetric. Add rotation overrides that mirror (rot, rot+1, rot-1, rot) for movement without arrival.

### Sampler | Tape Type

![Sampler Layout](lib/etc/readme_layout_images/Sampler%20Layout.png)

Load a sample or record from the Norns input. The sample will be chopped and distributed across a 4x4 pad grid (2A). Filter and envelope can be set for all pads (4A) or overwritten individually. Performances can be looped, overdubbed, and transformed. "Scatter" and "Slide" transformations (1A) manipulate the sample playhead and are very cool for textural work.

**Controls:**
- **Chop Config** (1A) — Per-pad envelope, filter, pitch, pan, and rate.
- **Create** (5B) — Record from Norns input or load a file.

**Try:** Load short samples of birds. Add a stage with Scatter.

### Voice Types

Both Tape and Composer can play the following voices. Each lane can output to multiple destinations simultaneously for interesting effects:

- MX Samples
- MIDI
- Crow/TXO (CV/Gate to eurorack)
- Just Friends
- W/Syn
- Disting EX (Multisample, Rings, Plaits, DX7)
- TXO Oscillator (with polyphony)
- OSC

## Eurorack | Mode (15,2)

![Eurorack Layout](lib/etc/readme_layout_images/Eurorack%20Layout.png)

I find Seeker most interesting when it's directly communicating with Eurorack rather than just being played through it. Seeker supports the classic voltage and gate patterns but also has a number of more unexpected things I've found useful. Clock has a huge range and has brought a new perspective to how I use modular effects.

The default screen is a CV monitor showing live voltage bars for all active outputs. Tap an output on the grid to select it and see its params. Hold an output to toggle it on/off. K2 toggles between the live monitor and param editing.

**Grid output layout (cols 13-16):**
- **Row 5** — Crow outputs 1-4
- **Row 6** — TXO TR outputs 1-4
- **Row 7** — TXO CV outputs 1-4

**Trigger Types:**
- **Clock** — Tempo-synced triggers from 1/64 beat to 256 beats
- **Pattern** — Step-sequenced triggers with configurable length
- **Euclidean** — Euclidean rhythm generator with fill, length, and rotation
- **Burst** — Rapid trigger bursts with count, timing curves, and acceleration

**CV Types:**
- **LFO** — Tempo-synced waveforms (sine, triangle, saw, square, random)
- **Envelope** — Clock-triggered envelopes with attack, decay, sustain, release
- **Knob Recorder** — Record and loop Arc/encoder movements as CV
- **Looped Random** — Random values that repeat after configurable length
- **Clocked Random** — New random value on each clock tick
- **Random Walk** — Accumulative random steps with configurable range

**Try:** Connect Looped Random to anything that takes CV that noticeably affects sound. Pick eight steps and two loops. Quantize and set a small CV range. Voltage melodies.

## OSC | Mode (3B)

![OSC Layout](lib/etc/readme_layout_images/OSC%20Layout.png)

Alongside the Seeker II tox components you can directly manipulate param values in TouchDesigner and sequence them with the Norns clock and events. This is very interesting for  Set the IP in the config menu (3B) and values should automatically show up in TD. Component preview window gives you a sense of values and their path.

Drag the .tox files into your project or My Components folder. Each component provides 4 CHOP outputs. I tend to connect them to null TOPs and reference those in parameters.

All work on a Norns but are much better with an Arc.

**Float** — [Float Component](lib/etc/td_components/seeker_ii_floats.tox) Set float values through a base and multiplier. Useful for tuning images or performance.

**LFO** — [LFO Component](lib/etc/td_components/seeker_ii_lfo.tox) Tempo-synced lfos using stock TouchDesigner shapes. Set mix/max ranges for interesting parameter transformations.

**Envelopes** — [Envelope Component](lib/etc/td_components/seeker_ii_envelope.tox) Clock-driven triggers with TD-based envelope parameters. Cool with rhythms.

**Try:** Connect an envelope to the offset parameter on a noise TOP that's connected to a Displace TOP. Try slow triggers with long release times. 

## W/Tape | Mode (3A)

![W/Tape Layout](lib/etc/readme_layout_images/W%3ATape%20Layout.png)

Transport control for the Whimsical Raps W/ module in tape mode with a particular focus on Frippertronics/buffer manipulation. Designed to act as a looper for foley or as a decaying delay.

I think this is such a cool module (the W/Synth used in Music mode is amazing) and I shimmed in a bunch of convenience methods so you can focus on sound design rather than config.

**Quickstart:** Hold Frippertronics (2C) to mark loop start and begin recording. Perform, then press again to close the loop—playback engages automatically. Set Buffer Decay (2D) to control how quickly layers fade. Long-press Frippertronics to clear and start over.

**Try:** Mult a piano for MX Samples. Send one out to W/'s in port and record for two seconds. Connec the W/ out to an effect. Recombine the clean signal with the frippertronic/effect chain. 

## Settings | Mode (16,1)

Global configuration: BPM, MIDI clock settings, screensaver timeout, and Shield encoder fix. Tap tempo available. Root note and scale are configured in the Motif parent screen (16,2).

---

## Transform Reference

Transforms modify motifs as they pass through stages with a user-configurable number of loops. Tape and Sampler each have their own transform library. Set variations on a theme or change "reset motif" to off to compound the effects over time.

### Tape Transforms

**Harmonize** — Layer harmonic intervals over notes. Sub-octave, fifth, and octave above with independent chance and volume. Timing and velocity are subtly humanized.

**Echo** — Cascading repetitions with decay. Each note generates quieter copies trailing behind it. Clock-synced timing. Direction moves echoes up or down the scale.

**Drift** — Subtle melodic variation. Notes randomly wander by scale degrees. Stability controls how much of the melody stays fixed (Very Low=25%, Low=50%, Medium=75%, High=90%).

**Ripple** — Repeats the entire phrase at a configurable delay, volume, and transposition. Great for atomsphere.

**Overdub Filter** — Filter notes by recording generation. Keep early layers, remove specific generations, or isolate the original.

### Sampler Transforms

**Scatter** — Create micro-loops from your sample. Amount controls playhead drift, Size controls minimum chop length. Good for glitchy textures.

**Slide** — Shift the played audio from within the chop window. Optional wrap around buffer boundaries. Add variation to repeated sounds.

**Reverse** — Flip playback direction with probability per chop.

**Pan Spread** — Randomly offset pan position. Probability and range controls. Good for spatial movement.

**Filter Drift** — Progressively darken or brighten the filter across stages. Direction controls whether it opens or closes.

### Composer Stages

Composer stages define chords in a progression rather than transforms on a recorded motif. Each stage has per-stage overrides for degree, voicing, chord length, strum order, rotation, and loop count. Global params set defaults; per-stage overrides take precedence.

The progression cycles through stages, with each stage repeating for its configured loop count before advancing. Asymmetric loop counts across stages create evolving patterns that don't repeat predictably.

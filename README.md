# Seeker II

Seeker II is a compositional interface for creating and procedurally manipulating phasing music and visuals. Record phrases, layer overdubs, chop samples, sequence changes, distort video, open the next.

Eight musical lanes can be run in parallel with each performing its own motif with sequencable changes. Motifs can be written with a tape-loop, a heavily parameterized chord sequencer, or chopped samples.

Seeker is the center of my studio and connects to the things I regularly use. If you're reading this, you likely use them too. Eurorack via i2c (Crow, TXO, Just Friends, W/, Disting EX), OSC for visual apps like TouchDesigner, and MIDI for external equipment.

It's intended to travel with you and scale to what you have on hand. I've been relentless about the user-experience and I hope that it's easy to pick up but deep enough to always spark something new.

## Requirements

**Required**
- Norns
- Grid (128)

**Recommended**
- Arc — Seeker has a lot of configurability. The Arc makes that configurability pleasant. Encoders mapped to different significant figures for high-resolution control and realtime performability.
- [Seeker TouchDesigner tox](lib/etc/td_components) — Seeker connects fairly naturally to TouchDesigner and enables a kind of visual painting that I think is a lot of fun. I've included toxs for each type of output. More on this further down.

**Optional**
- Crow — Lots of CV and gate output patterns. Clock-synced modulation with some unusual approaches.
- TXO — More CV and trigger outputs. TXO forever.
- i2c modules — Control the playback and settings of Just Friends, W/Syn, and Disting EX
- MIDI — external synths and DAWs

## Installation

In Maiden:
```
;install https://github.com/brokyo/seeker_ii
```

## Quickstart

When you first boot the app you will be on Lane 1 in Tape mode.

1. **Select a voice** — Open lane config (4A) to choose an output (MX Samples, Just Friends, MIDI, etc) and configure its timbre.

2. **Play notes** — The 6x6 keyboard (2A) is ready. Bright keys are root notes. Vertical = 4 scale degrees, horizontal = 1.

3. **Record a motif** — Hold the record button (5B). A metronome appears above the keyboard. Play a phrase. Press again to stop—it loops automatically.

4. **Overdub** — Hold record again while the motif plays. New notes layer onto existing ones.

5. **Add a transform stage** — A phrase can be manipulated after an arbitrary number of loops. Open stage config (1A). Turn on a new stage and a transform (Harmonize is my favorite) to evolve the composition. Your motif evolves each loop but can always be reset to the start.

6. **Try another lane** — Select a new lane (4A). Record a variation. Now two voices phase against each other.

### Next Steps

- **Composer mode** — Switch a lane to Composer and build an evolving arpeggio with harmonic (1A) and expression (1B) stages. Connect it to Eurorack and create unorthodox patterns, timing, and velocity curves.
- **Sampler mode** — Built on Softcut. Load an audio file or record from input, then trigger chopped segments from the grid. Each pad has configurable envelope, filter, pitch, pan, and rate. Record performances and transform them across stages.
- **Eurorack integration** — Configure Crow outputs (3C) for clock-synced modulation—LFOs, bursts, random walks, or knob recorders that capture Arc movements.

## Motif | Mode

The main performance space. Eight lanes run in parallel, each playing one of three motif types. Each type has its own keyboard and stage system.

### Tape | Motif Type

![Tape Layout](lib/etc/readme_layout_images/Tape%20Layout.png)

Record motifs on a 6x6 Tonnetz/interval keyboard (2A). After recording, motifs can be overdubbed by holding Create Motif (5B). After a configurable number of loops, motifs move to the next "Stage" (1A). Scale and intervals can be set in Keyboard Config (E3 long-press).

**Tape Controls:**
- **Stage Config** (1A) — Configure transforms and loop counts.
- **Note Velocity** (1B) — Four dynamic levels (pp, mp, f, ff). Select from grid.
- **Dual Keyboard** — Toggle the option in Create (5B) to split the keyboard into two zones with separate octaves.

**Tape Transforms:**
- **None** — Pass through unchanged
- **Overdub Filter** — Filter events by overdub generation (Up to, Only, Except)
- **Harmonize** — Add harmonic overtones (sub-octave, fifth, octave) with probability and humanization
- **Transpose** — Shift all notes by semitones
- **Rotate** — Rotate note order while preserving timing
- **Reverse** — Reverse note order while preserving durations
- **Skip** — Play every Nth note, skipping others
- **Ratchet** — Probabilistic note repetition with configurable burst timing

### Composer | Motif Type

![Composer Layout](lib/etc/readme_layout_images/Compose%20Layout.png)

An algorithmic chord sequencer is represented by an interval keyboard (2A). Hold Create Motif (5B) to begin a sequence. Optionally, select from expression presets to give it character. Arpeggios move through stages with configurable chord voicings and performance characteristics.

- **Create Motif** (5B) — Select expression preset and generate.
- **Harmonic Config** (1A) — Per-stage chord root, type, length, inversion, octave.
- **Expression Config** (1B) — Per-stage velocity curves, strum timing/shape, note duration, pattern filtering.

### Sampler | Motif Type

![Sampler Layout](lib/etc/readme_layout_images/Sampler%20Layout.png)

Load a sample or record from the Norns input (4A). Via Softcut, the sample will be chopped and distributed across a 4x4 pad grid (2A). Record pad performances and transform them across stages just like Tape mode. Good for percussion and textural sound mangling.

**Sampler Controls:**
- **Chop Config** — Per-pad configuration (hold pad to edit).
- **Stage Config** (1A) — Configure sampler transforms and loop counts.
- **Chop Amplitude** (1B) — Four dynamic levels for trigger loudness.

**Per-Pad Parameters:**
- **Mode** — Gate (hold to play) or One-Shot (trigger and release)
- **Start/Stop** — Slice points within the sample
- **Pitch** — Transpose -12 to +12 semitones
- **Speed** — Playback rate (-2x to +2x, negative = reverse)
- **Pan** — Stereo position
- **Attack/Release** — Amplitude envelope
- **Crossfade** — Smooth loop transitions
- **Filter** — Off, Lowpass, Highpass, Bandpass, or Notch with cutoff and resonance

**Sampler Transforms:**
- **None** — Pass through unchanged
- **Scatter** — Randomize chop positions within buffer (amount controls drift, size controls minimum length)
- **Slide** — Shift chop windows through buffer while preserving duration (optional wrap)
- **Reverse** — Flip playback direction with per-event probability
- **Pan Spread** — Randomly offset pan from recorded value
- **Filter Drift** — Progressively darken or brighten filter across stages

### All | Motif Types

All motif types share these controls:

- **Lane Select** (4A) — Choose lane and configure voices. Multiple voices can be active per-lane.
- **Create** (5B) — Hold to record/generate. Tape records keyboard, Sampler records pads, Composer generates from parameters.
- **Play** (5A) — Control playback: offset pitch, change speed, quantize events, swing timing. Hold to play/stop.
- **Clear** (5C) — Hold to erase the current motif. Confirmation flash on grid.
- **Perform** (5D) — Hold-to-activate Mute, Accent, or Soft with configurable slew time.

**Voice Outputs:**

Each lane can output to multiple destinations simultaneously:
- MX Samples (internal engine)
- MIDI (external gear/DAW)
- Crow/TXO (CV/Gate to eurorack)
- Just Friends (i2c)
- W/Syn (i2c)
- Disting EX (i2c)
- OSC (note events to TouchDesigner)

## Eurorack | Mode (3C)

![Eurorack Layout](lib/etc/readme_layout_images/Eurorack%20Layout.png)

I find Seeker most interesting when it's directly communicating with Eurorack rather than just being played through it. Accordingly, I've included a bunch of Crow and TXO output options that stay true to the music and its timing. 

Every output combines can be played on a beat interval, a multiplier, and a phase offset. You can make modules doing some really unusual things.

**Crow Outputs:**

Each output selects a Category (Gate or CV) then a Mode within that category.

*Gate Category:*
- **Clock** — Simple clocked gate output.
- **Pattern** — Random rhythmic pattern, rerollable on demand.
- **Euclidean** — Euclidean rhythm with rotation.
- **Burst** — Rapid pulses with configurable distribution (linear, accelerating, decelerating, random).

*CV Category:*
- **LFO** — Tempo-synced shapes (sine, triangle, saw, pulse, noise) with voltage range.
- **Knob Recorder** — Capture E3 knob movements as looping CV.
- **Envelope** — ADSR or AR with clock-synced timing.
- **Looped Random** — Generate a random CV sequence, loop it N times, then regenerate.
- **Clocked Random** — External trigger (Crow input) generates random voltages.
- **Random Walk** — Stochastic movement within configurable ranges.

**TXO TR:** Clock, Pattern, Euclidean, and Burst modes matching Crow's Gate category.

**TXO CV:**
- **LFO** — Wave morphing LFO (Sine→Triangle→Saw→Pulse→Noise).
- **Envelope** — ADSR or AR with clock-synced timing.
- **Random Walk** — Same as Crow.

## OSC | Mode (3B)

![OSC Layout](lib/etc/readme_layout_images/OSC%20Layout.png)

Alongside the Seeker II tox components you can directly manipulate param values in TouchDesigner and sequence them with the Norns clock and events. Set the IP in the config menu (3B) and values should automatically show up in TD. Component preview window gives you a sense of values and their path.

**Float** — [Float Component](lib/etc/td_components/seeker_ii_floats.tox) Set float values through a base and multiplier. Useful for tuning images or finding the right range for LFOs. Better with Arc.

**LFO** — [LFO Component](lib/etc/td_components/seeker_ii_lfo.tox) Tempo-synced lfos using stock TouchDesigner shapes. Set mix/max ranges for interesting parameter editing.

**Envelopes** — [Envelope Component](lib/etc/td_components/seeker_ii_envelope.tox) Clock-driven triggers with TD-based envelope parameters. Cool with rhythms.

## W/Tape | Mode (3A)

![W/Tape Layout](lib/etc/readme_layout_images/W%3ATape%20Layout.png)

Transport control for the Whimsical Raps W/ module in tape mode with a particular focus on Frippertronics/buffer manipulation. Designed to act as a looper for foley or as a decaying delay.

I think this is such a cool module (the W/Synth used in Motif mode is amazing) and I shimmed in a bunch of convenience methods so you can focus on sound design rather than config.

**Quickstart:** Hold Frippertronics (2C) to mark loop start and begin recording. Perform, then press again to close the loop—playback engages automatically. Set Buffer Decay (2D) to control how quickly layers fade. Long-press Frippertronics to clear and start over.

**Playback:**
- **Play** — Toggle playback on/off.
- **Speed** — Playback rate with pitch shift (-2x to +2x).
- **Reverse** — Toggle tape direction.

**Transport:**
- **Rewind** — Jump back configurable time (0.1-60s, default 10s).
- **Fast Forward** — Jump forward configurable time (0.1-60s, default 10s).
- **Go To Start** — Jump to tape beginning.

**Recording:**
- **Record** — Arm recording on/off.
- **Recording Level** — Input level to tape.
- **Decay** — 0 = pure overdub (layers accumulate), 1 = full replace.
- **Echo Mode** — Plays back existing audio before erasing.
- **Monitor Level** — Direct input monitoring.

**Loop:**
- **Loop Active** — Enable/disable loop playback.
- **Frippertronics** — Quick loop capture workflow. Press once to start recording and mark loop start. Press again to close the loop and begin layering. Long-press to clear and reset.

**Maintenance:**
- **Init W/Tape** — Full reset: stops playback/recording, clears tape, returns to start. 

## Settings | Mode (3D)

Global configuration: BPM, root note, scale, and MIDI clock settings. Tap tempo available. "Sync All" restarts all lanes and outputs simultaneously.

## Etc
### Disting EX Setup
**Triggerable Polyphonic Voice:**
1. Select Disting Voice > All on Norns
2. Navigate to Macro Osc 2 Settings (P encoder)
3. Set all voices to trigger on I2C: Instance n > I2C trigger 1
4. Set all voices to share params: Instance n > Share Params 1

### W/ Setup
**W/ Mode Change**
Requires physical controls.
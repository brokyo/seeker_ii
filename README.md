# Seeker II

Seeker II is a compositional interface for creating and procedurally manipulating phasing music and visuals. Record phrases, layer overdubs, chop samples, sequence changes, distort video, open the next.

Eight musical lanes can be run in parallel with each performing its own motif with sequencable changes. Motifs can be written with a tape-loope, a heavily parameterized chord sequencer, or chopped samples.

Seeker is the center of my studio and connects to the things I regularly use. If you're reading this, you likely use them too. Eurorack via i2c (Crow, TXO, Just Friends, W/, Disting EX), OSC for visual apps like TouchDesigner, and MIDI for external equipment. 

It's intended to travel with you and scale to what you have on hand. I've been relentless about the user-experience and I hope that it's easy to pick up despite but deep enough to always surprise.

## Requirements

**Required**
- Norns
- Grid (128)

**Recommended**
- Arc — Seeker has a lot of configurability. The Arc makes that configurability pleasant. Encoders mapped to different significant figures for high-resolution control and realtime performability.
- [Seeker TouchDesigner tox](lib/etc/seeker.tox) — Seeker connects fairly naturally to TouchDesigner and enables a kind of visual painting that I think is a lot of fun. This tox handles all the connections. More on this further down.

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

## Layout

![Seeker II Layout](https://github.com/brokyo/seeker_ii/raw/main/layout.png)

## Quickstart

When you first boot the app you will be on Lane 1 in Tape mode.

1. **Select a voice** — Open lane config (4A) to choose an output (MX Samples, Just Friends, MIDI, etc) and configure its timbre.

2. **Play notes** — The 6x6 keyboard (2A) is ready. Bright keys are root notes. Vertical = 4 scale degrees, horizontal = 1.

3. **Record a motif** — Hold the record button (5B). A metronome appears above the keyboard. Play a phrase. Press again to stop—it loops automatically.

4. **Overdub** — Hold record again while the motif plays. New notes layer onto existing ones.

5. **Add a transform stage** — A phrase can be manpiulated after an arbitary number of loops. Open stage config (5D). Turn on a new stage and a transform (Harmonize is my favorite) to evolve the composition. Your motif evolves each loop but can always be reset to the start.

6. **Try another lane** — Select a new lane (4A). Record a variation. Now two voices phase against each other.

### Next Steps

- **Composer mode** — Switch a lane to Composer and built an evolving arpeggio with timing (##) and expression (##) stages. Connect it to Eurorack and create unorthodox patterns, timing, and velocity curves.
- **Sampler mode** — Built on Softcut. Load an audio file or record from input, then trigger chopped segments from the grid. Each pad has a configurable envelope and filter.
- **Eurorack integration** — Configure Crow outputs (3C) for clock-synced modulation—LFOs, bursts, random walks, or knob recorders that capture Arc movements.

## Motify | Mode

The main performance space. Eight lanes run in parallel, each playing one of three motif types. Each type has its own keyboard and stage system.

### Tape | Motif Type
Record motifs on a 6x6 Tonnetz/interval keyboard (2A). After recording, motifs can be overdubbed by holding the button Create Motif (5B) key. After a configurable number of loops, motifs move to the next "Stage" (5D). Stages manipulate the event table enabling straightforward transformations (Reverse, Rotate, Ratchet) or more unique ones (Harmonize, Generation Filter). Scale and intervals can be set in Keyboard Config (##)

- Create Motif (5B) — Hold to record, press again to stop.
- Stage Config (5D) — Configure transforms and loop counts.

### Composer | Motif Type
An algorithmic chord sequencer is represented by an interval keyboard (2A). Hold Create Motif (5B) to begin a sequence. Optionally, select from expression presets to give it character. Arpeggios move through stages (##) with configurable chord voicings and performance characteristics.

- Create Motif (##) — Select expression preset and generate.
- Harmonic Config (##) — Per-stage chord root, type, length, inversion, octave.
- Expression Config (##) — Per-stage velocity curves, strum timing/shape, note duration, pattern filtering.

### Sampler | Motif Type
Load a sample or record from the Norns input (4A). Via softcut, the sample will be chopped and distributed across a 4x4 pad grid (2A). Each pad has its own envelope, filter, rate, and chop points. Good for percussion and textural sound mangling. 

- Create Motif (##) — Load file or record from input.
- Pad Config (##) — Per-pad envelope, filter, rate, start/end points.


### All | Motif Type
All motifs share the same basic selection and playback controls. 
- **Lane Select** (4A) — Choose lane and configure the voices it controls. Multiple voices can be active per-lane. Lots of cool tonal stuff in Eurorack becomes possible. 
- **Motif Playback** (5A) — Control the motif's playback characteristics. Ofset pitch, change speed, quantize events, or swing timing. Hold to play/stop.
- **Clear Motif** (5C) — Hold to erase the current motif. You'll see a confirmation flash on grid when it happens.

## Eurorack | Mode (3C)
I find Seeker most interesting when it's directly communicating with Eurorack rather than just being played through it. Accordingly, I've included a bunch of Crow and TXO output options that stay true to the music and its timing. 

Every output combines can be played on a beat interval, a multiplier, and a phase offset. You can make modules doing some really unusual things.

**Crow Outputs:**
- **Gate** — Clock or pattern-driven. Patterns can be Euclidean or random, rerollable on demand.
- **Burst** — Rapid pulses with configurable distribution (linear, accelerating, decelerating, random).
- **LFO** — Tempo-synced shapes (sine, linear, rebound, etc.) with voltage range.
- **Envelope** — ADSR or AR with configurable shape curves.
- **Knob Recorder** — Capture Arc movements as looping CV. Gestural sampling.
- **Random Walk** — Stochastic movement within configurable ranges.
- **Clocked Random** — External trigger (Crow input) generates random voltages, optionally quantized to scale.

**TXO TR:** Gate and Burst. Both support burst shaping (linear, accelerating, decelerating, random).

**TXO CV:**
- **LFO** — Wave morphing LFO (Sine→Triangle→Saw→Pulse→Noise).
- **Envelope** — ADSR or AR with clock-synced timing.
- **Random Walk** — Same as Crow.

## OSC | Mode (3A)
Built with the Seeker_II TOX in mind, this mode enables you to control TOP values in TouchDesigner in sequence with the Seeker clock and events. Set the IP in the config menu (3A) and values should automatically show up in TD. 

**Float** — Direct value + multiplier. Useful for tuning images.

**LFO** — Tempo-synced oscillation using stock TouchDesigner shapes.

**Trigger** — Clock-driven pulses with envelope parameters (attack, decay, sustain, release)

## W/Tape | Mode (3B)

Transport control for the Whimsical Raps W/ module in tape mode. Play, record, fast-forward, rewind, loop points, reverse. I think this is such an interesting module (the W/Synth used in Motif mode is amazing) and I believe it becomes much more performable with grid control. 

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
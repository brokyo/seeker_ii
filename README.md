# Seeker II

Seeker II is a looper for Monome Norns that stores and procedurally transforms musical patterns.

## Core Concepts

Seeker II is built around three interconnected musical ideas:

### Layers

Layers are independent musical channels that allow you to compose looping patterns:

- **Multiple Independent Tracks**: Each layer operates as a separate voice with its own instrument, settings, and playback status.
- **Stage-Based Progression**: Layers play through four sequential stages, each of which can optionally modify the content of the loop.
- **Output Flexibility**: By default layers us the Mx Samples engine but can also output to MIDI, Crow, or TXO.


### Motifs

Motifs are the musical patterns at the core of Seeker II:

- **Performable Memory**: Record patterns in real-time using the grid or MIDI input.
- **Overdub Generations**: Motifs can be overdubbed with groups of notes that can be individually adressed in transformations 
- **Generate Patterns [Alpha]**: A series of generators enables one-click motif generation across common musical concepts.

### Transformations

Once created, motifs can be transformed in sequenced stages:

- **Non-Destructive Changes**: Transform patterns while preserving the original motif.
- **Stage-Based Evolution**: Apply different transformations at each stage of a lane.
- **Musical Operations**: Transpose, reverse, rotate, stretch, or add resonance to patterns.


## Getting Started

### Setting Up

1. Select a layer using the layer selection buttons (Rows 6 > 7, Columns 13 > 16)
2. Configure the lane's instrument and output settings (Norns screen)

### Recording A Motif

### Generating A Motif

### Overdubbing A Motif



## Requirements

- Monome Norns
- Grid
- Optional: MIDI In/Out, Crow, or Eurorack integration

## Addition Notes
- [Some thoughts on additional eurorack stuff like loop triggers]
- [Some thoughts on output]
- [Config and debug menus]
# Seeker II

Seeker II is a compositional interface for Monome Norns. 

It allows you to:
- Record, overdub, and transform musical motifs on an emulated tape
- Configure and control time-synchronized modulation in Eurorack (via i2c) and TouchDesigner (via OSC)

Using these voices:
- MX Samples (https://norns.community/mxsamples)
- Whimsical Raps i2c devices (W/Syn, Just Friends)
- I2C connectors (Crow, TXO)
- MIDI

## Installation
In Maiden: ;install https://github.com/brokyo/seeker_ii


## Layout
![Seeker II Layout](https://github.com/brokyo/seeker_ii/raw/main/layout.png)

## Quickstart
### To Begin
1. **Configure Lane** (4A): Select your output voice (MX Samples, W/Syn, etc.)
2. **Record motif** (5B): Hold grid key to start recording on the keyboard (2A)
3. **Stop recording** (5B): Press grid key again when recording is complete
4. **Change playback parameters** (5A): Adjust octave, degree, and speed

### Next Steps
1. **Overdub motif** (5B): Hold grid key again in tape mode to layer new material
2. **Transform motif** (5D): Configure time-synchronized changes to motif
3. **New Lane** (4A): Create additional voices for phasing compositions
4. **Synchronize modulation** (3A/3C): Configure OSC and Eurorack patterns to accompany loops

## Layout Details
### 1 | Keyboard Config
- A: Octave Tuning 
  - Left key drops the keyboard octave by one; right key increases it by one
- B: Offset Tuning 
  - Left key drops the keyboard note by one; right key increases it by one
- C: Velocity Tuning 
  - Left-to-right increases key velocity

### 2 | Keyboard
- A: Tonnetz-Style Keyboard 
  - Tuned to global set in (3D) 
  - Covers two octaves
  - Illuminated keys are root
  - Vertical keys move by one degree. Horizontal keys move by two degree

### 3  | Integrations
- A: OSC Configuration
  - Configure time-synchronized LFOs and clocks
  - Set to TouchDesigner default but configurable at bottom of menu
- B: W/Tape Configuration
  - Record, overdub, and navigate tape
  - NB: Requires manual button combination on W/ Module to enter tape mode
- C: Eurorack Configuration
  - Configure time-synchronized voltage patterns
  - Crow: Choose from Gate, Burst, LFO, Envelope, Knob Recorder, and Structured Random
  - TXO: Choose from Gate, Burst, LFO, and Stepped Random
- D: Global Configuration
  - Tuning, clock, and MIDI control affecting entire app.

### 4 | Lane Management
- A: Lane Selection
  - Select lane outputs among supported voices
  - 1 -> 8 lanes available. Each stores its own tuning information

### 5 | Motif Management
- A: Playback Configuration
  - Control playback of recorded motif
  - Shift playback octave, degree, and speed
- B: Create Motif
  - Select between emulated tape and arpeggio
  - Hold grid key (5B) to start recording (Keyboard will blink)
  - Press grid key (5B) again to stop
  - Holding grid key (5B) in tape mode will overdub
- C: Clear Motif
  - Hold grid key (5C) to clear recording. Grid will blink on confirmation
- D: Stage Configuration
  - Stages allow for structured changes to motifs
  - Pick from Harmonize, Ratchet, Transpose, Overdub Filter, and Reverse

## Etc
### Known Bugs
- When the app has the Screensaver or Create Motif active K1 doesn't work.
- After powering on the Norns sometimes the Arc isn't recognized. Unplug/replug and it should work.

### TODO
- See roadmap.md

### Disting Poly Plaits
- Distings Plaits mode in Poly requires a bit of configuration on the module itself. There are a huge number of permutations but I regularly use:
#### Triggerable Polyphonic Voice
- Select Disting Voice > All on Norns
- Navigate to Macro Osc 2 Settings using P encoder
- Set all voices to trigger on I2C [Instance n > I2C trigger 1]
- Set all voices to share params from Norns [Instances n > Share Params 1]
#### Drone Voice

## Code Structure
```
lib/
├── motif_core/        Musical data structures and transformations
├── sequencing/        Timing and playback engine
├── ui/                Screen interface and state management
│   └── base/          Base UI classes (norns_ui, grid_ui)
├── controllers/       Hardware input handlers
├── grid/              Grid UI infrastructure
│   ├── keyboards/     Keyboard layout implementations
│   └── selector/      UI selector components
├── components/        Feature modules with screen/grid/params
│   ├── global_config/ Global app configuration
│   ├── keyboard/      Keyboard configuration and motif creation
│   ├── lanes/         Lane management and stage transforms
│   │   └── stage_types/ Mode-specific stage configurations
│   ├── eurorack/      Eurorack CV/gate output (Crow, TXO)
│   ├── osc/           OSC output for TouchDesigner
│   └── wtape/         W/Tape integration
└── etc/               Miscellaneous utilities and resources
```
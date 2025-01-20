# **Seeker II**

**Seeker II** is a pattern sequencer for Monome Norns that lets you capture musical patterns across multiple lanes and apply transformations to create evolving compositions while maintaining precise timing and musical coherence.

## **Features**

* **Multi-Lane System**: Up to 4 independent pattern lanes, each with its own instrument and settings
* **Stage-Based Sequencing**: Each lane can have multiple stages with independent loop counts and rest periods
* **Precise Timing**: Sub-10ms accuracy using absolute beat timing
* **Musical Grid**: Scale-aware note input with visual feedback
* **Transform System**: Apply musical transformations to evolving patterns

## **Architecture**

* Multi-lane layout
* Stage-based pattern sequencing
* Absolute beat timing
* Lane-specific parameters
* Transform pipeline

### **Lane System**
Each lane in Seeker II provides:
* Independent instrument assignment
* Configurable octave range
* Multiple stages with:
  - Loop count control
  - Loop rest duration
  - Stage rest duration
* Transform sequence support

## **Grid Layout**
* Rows 1-4: Pattern lanes for each instrument
* Row 5: Global controls
* Rows 6-8: Note input area

## **Controls**
* Independent controls per lane
* Pattern recording and playback
* E1: Lane selection
* E2: Parameter selection
* E3: Value adjustment

## **Parameters**
* Global musical settings (root, scale)
* Lane-specific parameters
  - Instrument selection
  - Octave range
  - Stage configuration
  - Loop and rest settings

## **System Architecture**

### **Key Components**

1. **Reflection Manager** (`lib/reflection_manager.lua`)
   * Handles pattern creation and management
   * Provides quantization support
   * Manages timing and synchronization

2. **Grid Interface** (`lib/grid.lua`)
   * Pattern recording controls
   * Multi-voice layout
   * Visual feedback for recording/playback state
   * Keyboard region for note input

3. **Parameter System** (`lib/params_manager.lua`)
   * Quantization settings
   * Voice-specific parameters
   * Pattern configuration
   * Automatic parameter persistence between sessions

### **Voice System**

Each voice in Seeker II provides:
* Independent pattern recording and playback
* Dedicated instrument selection
* Individual octave settings
* Separate quantization controls
* Volume and mute/solo options

## **User Interface**

### **Grid Layout**
* Rows 1-4: Pattern lanes for each voice
* Columns 4-12: Keyboard region for note input
* Visual feedback for recording and playback states
* Independent controls per voice

### **Norns Controls**
* E1: Voice selection
* E2: Parameter navigation
* E3: Value adjustment

## **Pattern System**

Patterns in Seeker II store:
* Note data (pitch, velocity, timing)
* Quantization settings
* Voice-specific parameters
* Playback state

## **Future Features**

* **Sequence Steps**: Chain patterns and transformations
* **Pattern Storage**: Save and load pattern configurations
* **Advanced Timing**: Support for triplets, swing, and complex rhythms
* **Pattern Variations**: Probability-based pattern mutations
* **External Sync**: MIDI and Link synchronization options

## **Development**

Seeker II is actively under development. For the latest status and upcoming features, please refer to the roadmap document.

---

_Note: This document reflects the current state of Seeker II and will be updated as new features are implemented._
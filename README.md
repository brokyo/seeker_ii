# **Seeker II**

**Seeker II** is a generative music-making script for the Monome Norns and Grid, built on the Reflection timing system. It enables musicians to capture musical patterns across multiple voices and apply transformations to create evolving compositions while maintaining precise timing and musical coherence.

## **Core Features**

* **Multi-Voice System**: Up to 4 independent pattern lanes, each with its own instrument and settings
* **Precise Timing**: Built on Reflection for rock-solid timing and synchronization
* **Grid Integration**: Intuitive Grid-based interface for pattern recording and control
* **Pattern Transformations**: Apply musical transformations to evolve patterns over time (coming soon)

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

* **Transform System**: Apply musical transformations to patterns
* **Sequence Steps**: Chain patterns and transformations
* **Pattern Storage**: Save and load pattern configurations
* **Advanced Timing**: Support for triplets, swing, and complex rhythms
* **Pattern Variations**: Probability-based pattern mutations
* **External Sync**: MIDI and Link synchronization options

## **Development**

Seeker II is actively under development. For the latest status and upcoming features, please refer to the roadmap document.

---

_Note: This document reflects the current state of Seeker II and will be updated as new features are implemented._
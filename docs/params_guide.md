# Seeker II Parameter Guide

## Duration Parameters

### Fixed Mode
- **Base Duration**: The fundamental note length (1/16 to 16 beats)
- **Variance**: Adds subtle timing variations (0-25%) for human feel

### Pattern Mode
- **Pattern Length**: Number of steps in the sequence (2-16)
- **Pattern Shape**:
  - Pendulum: Alternates between long and short durations
  - Mountain: Builds up to peak then falls
  - Valley: Drops down then rises back
  - Steps: Random but repeating sequence of note lengths
  - Gather: Progresses from short to long durations
  - Scatter: Progresses from long to short durations
- **Min/Max Duration**: Sets the range for pattern variation

## Clock Parameters

### Basic Configuration
- **Source**: Internal or external clock
- **Division**: Musical timing divisions (1/16 to 16)
- **Behavior**: Pulse, Strum, or Burst

### Strum Configuration
- **Window**: Total time for strum sequence
- **Events**: Number of notes in sequence (2-12)
- **Motion**: Energy distribution (0-100)
- **Feel**: Timing variation amount (0-100)

### Burst Configuration
- **Window**: Total time for burst sequence
- **Style**: 
  - Spray: Scattered, wild distribution
  - Accelerate: Building momentum
  - Decelerate: Slowing down
  - Crescendo: Building intensity
  - Cascade: Three overlapping waves
  - Pulse: Steady pairs with variation
  - Bounce: Decaying rebounds
  - Chaos: Order meets randomness

## Voice Parameters
- **Voice**: Selected output for the channel

## Arpeggiation Parameters

### Chord Selection
- **Degree**: Scale position (I through VII)
- **Quality**: Major, Minor, Diminished, Augmented
- **Extension**: None, 7th, 9th, 11th, 13th
- **Inversion**: Root, First, Second, Third
- **Start Octave**: Base octave (0-8)
- **Note Count**: Total notes in sequence (3-12)

### Pattern
- **Style**: Up, Down, Up-Down, Random, Random-Lock
- **Step**: Note-to-note distance (-4 to 4)

## Expression Parameters
- **Pattern**: Static, Rise, Fall, Steps
- **Period**: Pattern length in beats (0.25-32)
- **Min/Max**: Velocity range (0-127) 
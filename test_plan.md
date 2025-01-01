# Seeker II Test Plan

## 1. Clock & Timing Tests

### A. Basic Clock Division
- Test each division (1/16, 1/8, 1/4, etc.)
- Verify timing accuracy
- Run multiple channels at different divisions

### B. Strum Behavior
- Test different strum durations (1/8, 1/4, etc.)
- Verify clustering behavior (0, 50, 100)
- Test human feel variation
- Verify note spacing is musical
- Test with different numbers of events (2-12)

### C. Burst Behavior
- Test different window sizes
- Verify all distribution patterns
- Test with different event counts

## 2. Chord & Scale Tests

### A. Scale Degrees
- Test each degree (I-VII) in C Major
- Verify correct chord qualities (major/minor/diminished)
- Test in different keys
- Verify transposition works

### B. Chord Modifications
- Test manual quality changes
- Test extensions (7, 9, 11, 13)
- Test inversions
- Verify note count expansion works

## 3. Arpeggiator Pattern Tests

### A. Basic Patterns
- Up: Verify correct note sequence
- Down: Verify correct note sequence
- Up-Down: Test direction changes
- Random: Verify randomness
- Random-Lock: Verify pattern repeats

### B. Step Size
- Test different step sizes (1-4)
- Verify wrapping behavior
- Test with different note counts

## 4. Integration Tests

### A. Global Parameter Impact
- Change key/scale, verify all channels update
- Test global octave shifts
- Test global transposition

### B. Multi-Channel Interaction
- Run multiple channels with different behaviors
- Verify independent operation
- Test parameter changes while running 
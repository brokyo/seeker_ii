# Pattern System Design

## Overview
This document outlines our pattern recording, playback, and transformation system built on the Reflection library. The system allows for recording multiple synchronized patterns and applying sequenced transformations to them over time.

## Core Components

### 1. Reflection Patterns
- Each voice gets its own Reflection pattern instance
- Handles recording, playback, and synchronization
- Example setup:
  ```lua
  voices = {
    pad1 = {
      pattern = reflection.new(),
      original_events = nil,  -- Store original pattern
      sequence = {},         -- Transform sequence
      current_step = 1,
      bars_waited = 0
    },
    arp1 = { -- similar structure },
    arp2 = { -- similar structure }
  }
  ```

### 2. Recording System
- Bar-aligned recording with precise durations
- Support for overdubbing and undo
- Example recording controls:
  ```lua
  -- Start a 12-bar recording on next bar
  pattern:set_rec(2, 48, 4)  -- queued, 48 beats, sync to bar
  
  -- Enable overdubbing during playback
  pattern:set_rec(1)
  
  -- Undo last overdub
  pattern:undo()
  ```

### 3. Transform Sequencing
Each pattern can have a sequence of transformation steps:
```lua
sequence = {
  {
    transform = "harmonize",
    params = { interval = 3 },
    wait_bars = 4,    -- Wait 4 bars before next step
    revert = false    -- Keep changes
  },
  {
    transform = "transpose",
    params = { semitones = 7 },
    wait_bars = 2,
    revert = true     -- Revert to original pattern
  }
}
```

## Grid Interface

### Recording Controls (Right Column)
```
[R1] Record pad1 (12 bars)
[R2] Record arp1 (3 bars)
[R3] Record arp2 (4 bars)
[R4] Record bass (4 bars)
```

### Pattern Sequences (Per Row)
```
[1][2][3][4][5]  <- Transform steps for pad1
[1][2][3][4][5]  <- Transform steps for arp1
[1][2][3][4][5]  <- Transform steps for arp2
```

### Step Configuration
When a step button is pressed, Norns screen shows:
1. Transform type selection
2. Transform parameters
3. Bars to wait before next step
4. Whether to revert to original pattern

## Pattern Management

### Recording
```lua
function init_pattern(name, bars)
  local pattern = reflection.new()
  
  -- Setup recording completion handler
  pattern.end_of_rec_callback = function()
    -- Store original pattern for reverting
    voices[name].original_events = tab.copy(pattern.event)
  end
  
  -- Setup loop handler for transformations
  pattern.end_of_loop_callback = function()
    handle_pattern_step(name)
  end
  
  return pattern
end
```

### Transform Steps
```lua
function handle_pattern_step(name)
  local voice = voices[name]
  local step = voice.sequence[voice.current_step]
  
  voice.bars_waited = voice.bars_waited + 1
  
  if voice.bars_waited >= step.wait_bars then
    -- Apply transformation
    apply_transform(voice.pattern, step)
    
    -- Revert if needed
    if step.revert then
      voice.pattern.event = tab.copy(voice.original_events)
    end
    
    -- Move to next step
    voice.current_step = voice.current_step % #voice.sequence + 1
    voice.bars_waited = 0
  end
end
```

### Pattern Storage
Patterns can be saved and loaded:
```lua
-- Save all patterns
function save_patterns()
  for name, voice in pairs(voices) do
    voice.pattern:save(norns.state.data..name..".pat")
  end
end

-- Load all patterns
function load_patterns()
  for name, voice in pairs(voices) do
    voice.pattern:load(norns.state.data..name..".pat")
  end
end
```

## Benefits
1. Precise, bar-aligned recording
2. Independent pattern lengths and transform sequences
3. Flexible transformation system with waiting and reverting
4. Built-in pattern storage
5. Automatic synchronization between patterns
6. Support for overdubbing and undo 
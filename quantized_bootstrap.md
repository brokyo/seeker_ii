# Quantized Playback Implementation Plan

## Overview
Implement grid-based playback mode that ignores original motif timing and instead plays notes on a rigid grid. This provides a contrasting rhythmic element to the free-form recorded motifs.

## Core Concept
- Use motif as a sequence of pitches/velocities only
- Generate new timing grid independent of recorded timing
- Maintain original motif data for switching between modes
- Implement in `schedule_stage` to leverage existing event processing

## Implementation Details

### 1. Lane Configuration
```lua
lane.timing_mode = "grid"  -- ("free"|"grid")
lane.grid_division = 1/16  -- step size in beats
```

### 2. Grid Event Generation
Replace existing event generation in `schedule_stage` with:
```lua
if lane.timing_mode == "grid" then
  local step_duration = lane.grid_division
  local note_duration = step_duration * 0.9  -- adjustable gate time
  
  for loop = 0, stage.num_loops - 1 do
    local loop_start = last_loop_end
    local step = 0
    
    for i = 1, lane.motif.note_count do
      -- Generate note_on/note_off events on grid steps
      -- Calculate loop boundaries
      -- Handle loop/stage rests
    end
  end
end
```

## Next Steps

### Phase 1: Basic Implementation
1. [ ] Add timing_mode parameter to lanes UI
2. [ ] Implement basic grid event generation
3. [ ] Test with simple motifs
4. [ ] Verify loop/stage rest handling

### Phase 2: Grid Parameters
1. [ ] Add grid division parameter (1/4, 1/8, 1/16, etc)
2. [ ] Add gate time parameter (note duration)
3. [ ] Add grid pattern selection (straight, triplet, swing)
4. [ ] UI controls for grid parameters

### Phase 3: Advanced Features
1. [ ] Pattern direction (forward, reverse, pendulum)
2. [ ] Note probability per step
3. [ ] Step repeat/ratcheting
4. [ ] Velocity patterns independent of recorded velocities

## Open Questions
1. How to handle motifs with fewer/more notes than grid steps?
2. Should grid parameters be per-stage like transforms?
3. How to visualize grid mode in the UI?
4. Should we support switching modes mid-playback?

## Technical Considerations
- Keep original motif data intact
- Maintain absolute beat number system
- Ensure clean transitions between stages
- Consider CPU impact of event generation
- Handle edge cases (empty motifs, single notes)

## UI/UX Considerations
- Clear indication of timing mode
- Visual grid representation
- Intuitive parameter controls
- Smooth mode switching behavior 
# Norns Application Logging Specification

## Critical Rules
1. NEVER log in redraw() functions for grid or UI - this will spam logs and crash the application
2. ALWAYS use rate limiting for high-frequency events
3. ALWAYS log musical state changes
4. NEVER log every tick or update

## Core Intent
This logging system is designed for a real-time musical application running on Norns where log readability and quick problem identification are crucial. The system must balance:
- Comprehensive state tracking
- Performance impact
- Visual appeal during live performance
- Debugging utility

## Decision Priorities (Highest to Lowest)

### 1. Musical State Safety
- ALWAYS log state changes that affect musical output
- ALWAYS preserve enough context to understand the musical timeline
- NEVER skip logging pattern modifications

Example:
```lua
-- GOOD: Complete state logging
log.music({
    event = "pattern_transform",
    before = pattern:serialize(),
    transform = "reverse",
    after = transformed:serialize()
})

-- BAD: Missing context
log.music({
    event = "pattern_transform",
    transform = "reverse"
})
```

### 2. Performance Requirements
- Use rate limiting for high-frequency events
- Log timing-sensitive operations only when exceeding thresholds
- Batch logs when possible

### 3. Visual Interest (REPL During Performance)
- Use consistent visual markers for event types
- Maintain clean, aesthetically pleasing log rhythm
- Use color and symbols thoughtfully

### 4. Debugging Clarity
- Include source location for all logs
- Organize related events visually
- Maintain clear event boundaries

## Log Types and Format

### Music Events

Musical events can represent single notes or collections. The format adapts to show relationships and groupings:

```lua
-- Single note event
♪ ▽△▽ [pattern1.lua:42] Grid(3,4) → P2 
   note: C4  vel: 127  dur: 0.25
   ctx: { bpm: 120, spd: 1.0 }

-- Pattern/collection of notes
♪ ═══ [pattern1.lua:42] Pattern P2 Updated
   ├─ pos: 1  note: C4  vel: 127  dur: 0.25
   ├─ pos: 2  note: E4  vel: 100  dur: 0.5
   └─ pos: 4  note: G4  vel: 115  dur: 0.25
   ctx: { bpm: 120, spd: 1.0 }

-- Chord/simultaneous notes
♪ ║║║ [pattern1.lua:42] Chord Added → P2 
   ┌─ note: C4  vel: 127
   ├─ note: E4  vel: 127
   └─ note: G4  vel: 127
   dur: 0.25
   ctx: { bpm: 120, spd: 1.0 }

-- Pattern transformation
♪ ◆◇◆ [pattern1.lua:42] Pattern P2 Transformed
   before:
   ├─ pos: 1  note: C4  vel: 127  dur: 0.25
   └─ pos: 2  note: E4  vel: 100  dur: 0.5
   after:
   ├─ pos: 1  note: C5  vel: 127  dur: 0.25
   └─ pos: 2  note: E5  vel: 100  dur: 0.5
   transform: { type: "transpose", amount: 12 }
```

Different decorators indicate event type:
- `▽△▽` Single note events
- `═══` Pattern/sequence events
- `║║║` Chord/simultaneous notes
- `◆◇◆` Pattern transformations

### Data Flow Events
```lua
-- Format with connecting lines
⟿ ─── [transform.lua:23] grid → pattern 
   type: pattern_change
   data: { from: p1, to: p2 }
```

### Status Events
```lua
-- Format with block decoration
⬖ ▣ ▣ [engine.lua:89] Recording Started
   pattern: P1
   mode: overdub
```

### Debug Events
```lua
-- Format with attention markers
⚐ ! ! [sequencer.lua:156] Buffer Check
   detail: Overflow prevention engaged
```

## Configuration and Control

### Message Suppression
```lua
log.config = {
    suppress = {
        music = false,
        flow = false,
        status = false,
        debug = false
    },
    detail_level = {
        music = 2,    -- 1: Basic notes only
                      -- 2: + context
                      -- 3: + all attributes
        flow = 1,     -- 1: Basic flow
                      -- 2: + data details
        status = 1,   -- 1: Basic status
                      -- 2: + context
        debug = 1     -- 1: Messages only
                      -- 2: + stack traces
    }
}
```

### Visual Styling
```lua
log.style = {
    use_decorations = true,
    color_enabled = true,
    compact_mode = false
}
```

## Decision Trees for Common Scenarios

### Pattern Code
```
Is it modifying musical state?
├── Yes: MUST log before/after state
│   └── Is it time-sensitive?
│       ├── Yes: Use compact format
│       └── No: Include full context
└── No: Don't log unless debugging
```

### Performance Code
```
Is it in the audio path?
├── Yes: Log only violations
│   └── Use rate limiting
└── No: Normal logging rules
    └── Include timing data
```

### UI/Grid Code
```
Is it a redraw()?
├── Yes: NEVER log here
└── No: Is it affecting musical output?
    ├── Yes: Log state change
    │   └── Include visual markers
    └── No: Is it user feedback?
        ├── Yes: Consider visual log
        └── No: Debug log only
```

## Implementation Guidelines

### Source Location Tracking
```lua
function log.get_source_location()
    local info = debug.getinfo(3, "Sl")
    return string.format("[%s:%d]", info.short_src, info.currentline)
end
```

### Rate Limiting
```lua
function log.rate_limited(key, interval, fn)
    local now = os.time()
    if not log.last_time[key] or (now - log.last_time[key] > interval) then
        log.last_time[key] = now
        fn()
    end
end
```

### Performance Thresholds
- CPU: Log when exceeding 80%
- Memory: Log when exceeding 90%
- Timing: Log jitter above 2ms
- Buffer: Always log underruns

## Common Pitfalls

### DO NOT:
1. Log in redraw() functions
2. Log every musical tick
3. Log without rate limiting in tight loops
4. Lose musical context between related events
5. Use inconsistent visual markers

### DO:
1. Batch related logs together
2. Use rate limiting for frequent events
3. Include musical context for state changes
4. Maintain visual consistency
5. Consider log appearance during performance

## Extension Points
The system is designed to be extensible:

### Adding New Log Types
```lua
log.register_type("custom", {
    prefix = "⚡",
    format = function(msg) ... end,
    detail_levels = {1, 2, 3}
})
```

### Custom Formatters
```lua
log.register_formatter("harmony", {
    format = function(value) return string.format("harm: %s", value) end,
    detail_level = 2
})
```
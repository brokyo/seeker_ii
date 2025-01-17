# Norns Application Logging Specification

## Critical Rules
1. NEVER log in redraw() functions for grid or UI - this will spam logs and crash the application
2. ALWAYS use rate limiting for high-frequency events
3. ALWAYS log musical state changes
4. NEVER log every tick or update
5. ALWAYS format timing values to 2 decimal places - timing precision beyond 0.01 beats is not meaningful for music

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

### Basic Format Rules
1. Simple events should be single-line with clear key=value pairs
2. Complex state changes use tabulated format
3. Use clear visual borders for important events
4. Source location should be clearly marked
5. Use consistent channel prefixes (TECH, SYS, etc)

### Technical Events (Notes, Triggers)
```lua
[TECH:NOTE] note_on @ grid.lua:42 | n=60 v=100 b=0.00
[TECH:NOTE] note_off @ grid.lua:44 | n=60 v=0 b=0.25
```

### Status Events
```lua
[motif_recorder.lua:119] ▓▓ Recording Started ▓▓
[motif_recorder.lua:142] ▓▓ Recording Stopped ▓▓
```

### Complex Data (Motifs, Patterns)
```lua
▓▓▓▓▓▓▓▓▓▓▓▓▓ MOTIF RECORDED ▓▓▓▓▓▓▓▓▓▓▓▓▓
Events: 4
  #  Beat   Note  Vel   Dur    Delta
----------------------------------------
  1  0.00   60    100   0.25   0.00
  2  0.25   64    100   0.25   0.25
  3  0.50   67    100   0.25   0.25
  4  0.75   72    100   0.25   0.25
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
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

## Detail Levels

### Technical Events (music)
1. Critical state changes only
2. Note events with basic info
3. Full technical context

### Status Events (status)
1. All state changes (always shown)
2. Additional context (if needed)
3. Debug-level state info

### Debug Events (debug)
1. Basic debug messages
2. Tabulated data dumps
3. Full debug with timing

## Key Formatting Rules

### Technical Events
- Use short key names (n=note, v=velocity, b=beat)
- Include source location after @
- Group related values with |

### Status Events
- Use ▓▓ borders for visibility
- Keep messages concise
- Source first in []

### Complex Data
- Use clear column headers
- Align numeric data right
- Use visual borders
- Include summary header

## Common Patterns

### Note Events
```lua
[TECH:NOTE] <operation> @ <source> | n=<note> v=<vel> b=<beat>
```

### Status Changes
```lua
[<source>] ▓▓ <message> ▓▓
```

### Data Dumps
```lua
▓▓▓▓▓▓▓▓▓▓▓▓▓ <TITLE> ▓▓▓▓▓▓▓▓▓▓▓▓▓
<summary>
<headers>
----------------
<aligned data>
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
```

## Controlling Verbosity

Set detail levels to control logging verbosity:
```lua
-- Minimal logging
logger.config.detail_level.music = 1   -- Critical musical changes only
logger.config.detail_level.status = 1  -- Critical status only

-- Normal operation
logger.config.detail_level.music = 2   -- Include note events
logger.config.detail_level.status = 2  -- Include basic status

-- Debug mode
logger.config.detail_level.music = 3   -- All musical events
logger.config.detail_level.status = 3  -- All status including recording
logger.config.detail_level.debug = 3   -- Full debug with stack traces
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
6. Mix string-formatted and raw numeric values in logging chains

### DO:
1. Batch related logs together
2. Use rate limiting for frequent events
3. Include musical context for state changes
4. Maintain visual consistency
5. Consider log appearance during performance

### Type Safety in Logging Chains

When passing data through multiple logging calls, be consistent with types:

```lua
-- BAD: Mixing formatted strings and numbers
function some_function()
  local value = 123.456
  log.status({
    time = string.format("%.2f", value)  -- Don't pre-format!
  })
end

function log.status(data)
  -- This will fail if data.time is a string but format expects number
  print(string.format("Time: %.2f", data.time))
end

-- GOOD: Keep numeric values as numbers until final formatting
function some_function()
  local value = 123.456
  log.status({
    time = value  -- Pass raw number
  })
end

function log.status(data)
  -- Format only at display time
  print(string.format("Time: %.2f", data.time))
end
```

Key rules for type safety in logging:
1. Pass raw values through logging chains
2. Format numbers only at the final display point
3. If values might be strings, use tonumber() defensively
4. Document expected types in logging interfaces
5. Consider adding type checking for critical logging paths

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
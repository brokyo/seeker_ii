# Seeker II Build Plan

## Core Philosophy

### 1. Musical Intent
- Each feature must serve a clear musical purpose
- Focus on expressive timing and rhythm control
- Maintain musical coherence across all channels
- Prioritize features that enhance live performance and composition

### 2. Code Architecture
- Clear separation of concerns between modules
- Consistent module patterns across codebase
- Explicit state management
- Predictable timing behavior
- No global state except through dedicated managers

### 3. Error Handling
- Graceful degradation when things go wrong
- Clear error messages for debugging
- Protection against common failure modes
- Automatic recovery where possible

## Learnings from Previous Implementation

### What Worked Well
1. Channel-based architecture for independent voice control
2. Grid UI visualization for note feedback
3. Chord generation system with quality-specific intervals
4. Parameter management system with prefixes
5. Test-driven development approach for critical components

### Missteps and Corrections
1. Incorrect seventh intervals in chord generation
   - Fixed by implementing quality-specific seventh intervals
   - Added proper handling for Major7 and Augmented7 chords

2. Initial timing implementation issues
   - Clock.run approach led to drift and sync problems
   - Need for centralized timing control became apparent

3. Module dependency management
   - Confusion between require/include for core vs local modules
   - Need for consistent module loading patterns

4. Grid UI implementation
   - Initial implementation mixed concerns
   - Need for better separation between display and logic

## Implementation Philosophy

### 1. Module Structure
- Each module should be self-contained
- Clear public interface
- Private functions prefixed with underscore
- Consistent return pattern for module tables
- Example:
```lua
local MyModule = {}
local private_state = {}

function MyModule.init(params)
    -- Initialization logic
end

function MyModule.public_method()
    -- Public interface
end

local function _private_helper()
    -- Private helper
end

return MyModule
```

### 2. State Management
- State should be owned by a single module
- State changes should be explicit and trackable
- Use callbacks for state change notifications
- Avoid global state

### 3. Timing System
- Centralized timing control through LatticeManager
- Two types of timing:
  1. Pulse sprocket: Main musical timing (quarter notes, etc)
  2. Events sprocket: Sub-pulse events (strums, bursts)
- All timing derived from single source of truth
- Clear hierarchy of timing relationships

### 4. Error Handling Pattern
```lua
function safe_operation(params)
    if not validate_params(params) then
        return nil, "Invalid parameters"
    end
    
    local success, result = pcall(function()
        -- Operation logic
    end)
    
    if not success then
        return nil, "Operation failed: " .. result
    end
    
    return result
end
```

## Implementation Plan

### Phase 1: Core Timing System
1. Create LatticeManager
   - Initialize main lattice
   - Methods for creating/managing sprockets
   - Clear cleanup handling

2. Channel Integration
   - Convert one channel to use lattice
   - Test thoroughly
   - Apply learnings to other channels

3. Testing Points
   - Basic timing accuracy
   - Multi-channel sync
   - Start/stop behavior
   - Edge cases (very fast/slow divisions)

### Phase 2: Event System
1. Implement Events Sprocket
   - Sub-pulse timing control
   - Event queuing system
   - Priority handling

2. Integration with Channel
   - Convert strum/burst to use events
   - Maintain musical coherence
   - Test timing accuracy

### Phase 3: Grid UI Enhancement
1. Separate Display Logic
   - Clear update triggers
   - Efficient redraw strategy
   - Better visual feedback

2. Add New Features
   - Better out-of-bounds indication
   - More informative visualizations
   - Performance optimizations

## Testing Strategy

### 1. Unit Tests
- Test each module in isolation
- Focus on edge cases
- Verify error handling

### 2. Integration Tests
- Test module interactions
- Verify timing accuracy
- Check resource usage

### 3. Musical Tests
- Verify musical coherence
- Test expressiveness
- Check timing feel

## Future Considerations

### 1. Performance
- Monitor CPU usage
- Optimize hot paths
- Consider batching updates

### 2. Extensibility
- Plan for future features
- Keep interfaces flexible
- Document extension points

### 3. User Experience
- Clear error messages
- Intuitive parameter names
- Consistent behavior

## Implementation Notes

### Current Status
- Chord generation fixed and tested
- Basic grid UI implementation working
- Ready to begin lattice integration

### Next Steps
1. Create clean LatticeManager implementation
2. Convert one channel to use lattice
3. Test thoroughly
4. Apply to remaining channels

### Critical Points
- Maintain musical timing accuracy
- Ensure clean error handling
- Keep code organized and documented
- Test each step thoroughly

## Clock Philosophy

### 1. Timing Hierarchy
- Main lattice is the single source of truth
- All musical events derive from this foundation
- Clear parent-child relationships between timing elements
- No independent timing sources to prevent drift

### 2. Musical Time vs. System Time
- Think in musical divisions, not milliseconds
- All timing expressed as musical fractions (1/4, 1/8, etc.)
- System handles conversion to real time
- Maintain musical coherence across tempo changes

### 3. Event Timing Model
```lua
Timing Hierarchy:
└── Main Lattice (global tempo)
    ├── Channel Pulse Sprockets (divisions)
    │   └── Note Events (on/off)
    └── Event Sprockets (sub-pulse)
        ├── Strum Events (note spread)
        └── Burst Events (note clusters)
```

### 4. Clock Behaviors
- Pulse Mode: Simple division-based timing
  - Clean, predictable note placement
  - Direct relationship to tempo
  - Ideal for rhythmic patterns

- Strum Mode: Organic note spread
  - Notes distributed within pulse window
  - Natural acceleration/deceleration
  - Musical direction changes

- Burst Mode: Note clustering
  - Dense note groups within pulse
  - Physics-based note distribution
  - Natural dynamic feel

### 5. Timing Precision
- All events quantized to nearest possible timing
- No events scheduled beyond reasonable precision
- Clear handling of timing conflicts
- Graceful behavior at tempo extremes

## Parameter Management

### 1. Parameter Hierarchy
```lua
Global Parameters
├── Musical Context
│   ├── Key
│   ├── Scale
│   └── Tempo
└── Global Controls
    ├── Transpose
    └── Octave

Channel Parameters
├── Core Musical
│   ├── Chord Degree
│   ├── Chord Quality
│   └── Extensions
├── Timing
│   ├── Division
│   ├── Behavior Mode
│   └── Sync Mode
└── Expression
    ├── Velocity
    ├── Duration
    └── Pattern
```

### 2. Parameter Relationships
- Clear parent-child dependencies
- Explicit update propagation
- Cached derived values
- Efficient change notification

### 3. Parameter Persistence
- Automatic state saving
- Clean serialization
- Safe deserialization
- Version compatibility

### 4. Parameter Modulation
- Clear modulation paths
- Rate-limited updates
- Priority system for conflicts
- Predictable behavior

### 5. Parameter Validation
- Type checking
- Range validation
- Dependency verification
- Clear error messages

### 6. Musical Parameter Design
- All parameters serve clear musical purpose
- Intuitive naming and organization
- Consistent value ranges
- Musical default values
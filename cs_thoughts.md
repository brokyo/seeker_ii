# Seeker II Development Philosophy

## Core Design Principles

1. **Simplification Through Presets**
   - Favor well-designed presets over excessive parameter exposure
   - Focus on musical results rather than technical configuration
   - Examples: Velocity patterns, Strum patterns
   - Allow basic tweaking of core parameters (timing, intensity) while hiding complexity

2. **Musical Expression**
   - Prioritize musical feel over technical precision
   - Implement human-like variations and natural timing
   - Focus on creating organic, expressive patterns
   - Balance between predictability and variation

3. **Debugging Approach**
   - Separate debug levels (SEEKER_DEBUG vs SEEKER_VERBOSE)
   - Event tables for musical events (strum, pulse, burst)
   - Clear logging of musical parameters and timing
   - Visual separation of debug information for clarity

## Implementation Patterns

1. **Parameter Organization**
   - Group related parameters together
   - Use clear, musical terminology
   - Provide sensible defaults and ranges
   - Include descriptive names and units

2. **State Management**
   - Track channel states independently
   - Maintain global parameters that affect all channels
   - Implement proper initialization and cleanup
   - Use preset system for saving/loading configurations

3. **Timing and Synchronization**
   - Base timing on musical beats
   - Handle clock divisions musically
   - Implement proper wrapping and cycling of patterns
   - Consider musical phrasing in pattern lengths

## Learned Lessons

1. **User Interface**
   - Keep the main interface simple and musical
   - Hide technical complexity behind presets
   - Provide immediate musical feedback
   - Use consistent terminology

2. **Musical Generation**
   - Start with simple, reliable patterns
   - Add complexity through layering and modulation
   - Ensure musical coherence across changes
   - Consider the full range of musical use cases

3. **Testing Strategy**
   - Test musical results, not just technical function
   - Include edge cases in musical contexts
   - Verify behavior across different time scales
   - Test interaction between multiple channels

## Future Directions

1. **Pattern Development**
   - Continue developing preset patterns for different musical styles
   - Consider adding pattern variations within presets
   - Look for opportunities to combine patterns musically
   - Keep focus on musical expressiveness

2. **User Experience**
   - Consider adding visual feedback for musical events
   - Develop more intuitive parameter relationships
   - Look for opportunities to simplify without losing power
   - Consider adding pattern visualization

3. **Musical Features**
   - Consider adding more musical pattern types
   - Look for ways to enhance expressiveness
   - Consider adding pattern coordination between channels
   - Think about musical structure on longer time scales 
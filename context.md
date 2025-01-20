# Architectural Context

## Core Components and Responsibilities

### Conductor (The Maestro)
- **Primary Role**: Orchestrates the overall musical performance
- **Key Responsibilities**:
  1. Decides WHEN patterns should change (stage transitions)
  2. Determines HOW patterns evolve (transform sequencing)
  3. Coordinates changes across multiple lanes
  4. Manages precise timing and synchronization
- **Relationship to Other Components**:
  - Uses Motif's transform mechanism but owns the transform decision-making
  - Coordinates multiple lanes and their state transitions
  - Handles high-level musical structure (stages, loops, rests)

### Motif (The Score)
- **Primary Role**: Smart data container for musical patterns
- **Key Responsibilities**:
  1. Maintains the genesis (original) state of patterns
  2. Provides access to current working state
  3. Implements the mechanics of state transitions
- **Relationship to Other Components**:
  - Serves as the data foundation for Conductor's decisions
  - Provides transform application mechanism
  - Does not make decisions about when/how to transform

## Architectural Decisions

### Transform System
- **Decision**: Split transform responsibilities between Conductor and Motif
- **Rationale**:
  1. Conductor (the maestro) should decide when and how music evolves
  2. Motif (the score) should know how to apply those changes
  3. This mirrors real-world music where a conductor interprets a score
- **Benefits**:
  1. Clear separation of concerns
  2. More intuitive metaphor
  3. Better support for multi-lane coordination
- **Implementation**:
  - Conductor owns transform sequences and timing
  - Motif provides the mechanism for applying transforms
  - Genesis state remains immutable in Motif

### State Management
- **Decision**: Maintain both genesis and working states in Motif
- **Rationale**:
  1. Original pattern should be preserved
  2. Transforms may need to reference original state
  3. Reset capability is essential
- **Benefits**:
  1. Clean separation of original and modified data
  2. Support for both compound and reset transforms
  3. Better data encapsulation 
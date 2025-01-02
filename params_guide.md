# Seeker II Parameter Guide

## Duration Controls

### Mode
- **Fixed**: Notes have a consistent length with optional variation
- **Pattern**: Notes follow a repeating sequence of lengths
- **Aleatoric**: Note lengths are chosen randomly within a range

### Base Duration
Sets the fundamental length of notes. Options range from very short (1/16 note) to very long (whole notes and beyond). This is your starting point for shaping the feel of a pattern.

### Variance (0-100%)
How much the duration can change from the base value. At 0%, notes are exactly the base duration. Higher values allow more variation.

### Variance Style
- **Random**: Each note's length varies unpredictably
- **Locked Random**: Creates a repeating pattern of variations
- **Drift**: Smoothly wanders between longer and shorter notes
- **Breathe**: Creates a natural ebb and flow, like breathing

### Min/Max Duration
When using Aleatoric mode, these set the shortest and longest possible note lengths. Think of it as setting boundaries for randomization.

### Pattern
For Pattern mode, enter numbers to create a sequence of duration multipliers. For example:
- "1": All notes are base duration
- "1 2": Alternates between normal and double length
- "1 0.5 2": Cycles through normal, half, and double length

## Musical Effects

Different settings create distinct musical effects:

### Tight Rhythmic
- Mode: Fixed
- Base Duration: 1/8 or 1/16
- Low variance (0-10%)

### Organic Melody
- Mode: Fixed
- Base Duration: 1/4 or 1/2
- Variance: 20-40%
- Style: Drift or Breathe

### Atmospheric
- Mode: Fixed or Aleatoric
- Base Duration: 1 or longer
- Variance: 50-100%
- Style: Breathe

### Textural
- Mode: Pattern
- Base Duration: 1/4
- Pattern: Mix of short and long values
- Or use Locked Random for repeating organic patterns

## Tips

- Start with Fixed mode and no variance to establish your basic pattern
- Add small amounts of variance (10-20%) to make patterns feel more natural
- Use Locked Random when you want organic feel but need predictability
- Breathe style works well for ambient or atmospheric sounds
- Pattern mode is great for creating specific rhythmic phrases
- Remember that duration affects how notes blend together - longer notes create more overlap

## Common Issues

- If notes feel too choppy, try increasing the base duration
- If notes are blending too much, reduce duration or add variance
- For clearer rhythms, use Fixed mode with low/no variance
- If timing feels off, check that your base duration aligns with your musical timing 
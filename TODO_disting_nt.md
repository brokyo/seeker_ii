# Disting NT Integration TODO

## Deferred: SysEx Preset Creation
- Create Python script to build NT presets via sysex from Mac
- Would connect via USB MIDI to NT
- Commands: 35H (clear), 32H (add algorithm), 36H (save)
- Start with simple Poly Multisample preset
- See `disting_nt_idealized.lua` for command reference

## Feature Request for Expert Sleepers
- Port sysex preset commands to i2c (34H, 35H, 32H, 33H, 60H)
- See `disting_nt_idealized.lua` for rationale and examples

## Current Implementation Notes
- Preset system works but requires manual NT setup first
- User must ensure algorithm type in NT matches Seeker preset selection

-- disting_nt_idealized.lua
-- REFERENCE DOCUMENT: Idealized Disting NT control if i2c had sysex parity
-- NOT functional code - for feature request reference only

--[[
FEATURE REQUEST FOR EXPERT SLEEPERS
====================================

Request: Port these sysex commands to i2c for Teletype/Crow users:

| Sysex | Function | Proposed i2c |
|-------|----------|--------------|
| 32H | Add algorithm by guid + specs | 0x32 |
| 33H | Remove algorithm at index | 0x33 |
| 35H | New preset (clear all) | 0x35 |
| 60H | Get algorithm count | 0x60 |

THE VISION: INSTRUMENTS, NOT PRESETS
====================================

The key insight is that users want to build up "instruments" - complete
signal chains - without managing preset files. An instrument might be:

  "Warm Pad" = Poly Wavetable + VCF (lowpass) + Reverb
  "Plucky Bass" = Poly FM + Compressor
  "Strings" = Poly Multisample + Chorus

With i2c algorithm control, a sequencer (Norns, Teletype, Crow) could:

1. Add algorithms on-the-fly as instruments are needed
2. Configure each algorithm's params
3. Build up the workspace incrementally (not clear/replace)
4. Remove algorithms when instruments are deactivated

EXAMPLE WORKFLOW (if i2c had these commands):

  User activates Lane 1 with "Warm Pad" instrument:
    → i2c: add poly_wavetable (gets index 1)
    → i2c: add vcf_svf (gets index 2)
    → i2c: add reverb (gets index 3)
    → i2c: configure params on each
    → i2c: set i2c_channel = 1 on poly_wavetable

  User activates Lane 2 with "Plucky Bass":
    → i2c: add poly_fm (gets index 4)
    → i2c: add compressor (gets index 5)
    → i2c: configure params
    → i2c: set i2c_channel = 2 on poly_fm

  Workspace now has 5 algorithms, two instruments playing.

  User deactivates Lane 1:
    → i2c: remove index 1, 2, 3
    → Workspace shrinks

No preset files. No manual NT configuration. The sequencer owns
the instrument definitions and builds them dynamically.

RATIONALE:
- Teletype/Crow users could build instruments programmatically
- Matches sysex capabilities available to DAW users
- More intuitive than managing preset files
- Enables live instrument switching during performance
- Workspace accumulates - add instruments as needed

--]]

------------------------------------------------------------
-- Hypothetical i2c Commands (if implemented)
------------------------------------------------------------

local CMD = {
  -- Existing commands (work today)
  SET_PARAM       = 0x46,  -- Set parameter to value
  GET_PARAM       = 0x48,  -- Get parameter value
  NOTE_PITCH_CH   = 0x68,  -- Set pitch for note
  NOTE_ON_CH      = 0x69,  -- Note on with channel
  NOTE_OFF_CH     = 0x6A,  -- Note off with channel

  -- Hypothetical new commands (mirroring sysex)
  LOAD_PRESET     = 0x34,  -- Load preset by program number (#N matching)
  NEW_PRESET      = 0x35,  -- Clear preset (remove all algorithms)
  ADD_ALGORITHM   = 0x32,  -- Add algorithm by guid + specs
  REMOVE_ALGO     = 0x33,  -- Remove algorithm at slot index
  GET_ALGO_COUNT  = 0x60,  -- Get number of algorithms in preset
}

------------------------------------------------------------
-- Idealized Workflow
------------------------------------------------------------

--[[

1. USER FLOW (if implemented):
   - User selects "Load NT Preset #3" in Seeker
   - Norns sends: i2c 0x34 0x00 0x03 (load preset #3)
   - NT loads presets/#03_my_preset.json from SD card
   - Norns queries algorithm count, syncs params

2. PROGRAMMATIC PRESET BUILDING:
   - Norns sends: i2c 0x35 (clear preset)
   - Norns sends: i2c 0x32 <poly_fm_guid> <slot=1> <specs> (add Poly FM)
   - Norns sends: i2c 0x32 <reverb_guid> <slot=2> <specs> (add reverb)
   - Result: Custom algorithm chain built from Norns

3. LIVE PRESET SWITCHING:
   - Teletype pattern: NT.PRESET 1, NT.PRESET 2, etc.
   - Or Crow: ii.disting_nt.load_preset(n)

--]]

------------------------------------------------------------
-- What We Have Today (workaround)
------------------------------------------------------------

--[[

Current approach in disting_nt.lua:
1. User manually sets up NT preset with desired algorithms
2. Seeker's "Preset" selector stores algorithm type + param values
3. On preset select, we blast all params via existing i2c SET_PARAM
4. Limitation: Can't add/remove algorithms, only configure existing ones

This works for sound design within a fixed algorithm, but can't:
- Switch between completely different presets
- Build algorithm chains programmatically
- Load user's saved NT preset files

--]]

return {
  CMD = CMD,
  description = "Reference document for i2c feature request"
}

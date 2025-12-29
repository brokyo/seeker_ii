-- disting_nt_idealized.lua
-- REFERENCE DOCUMENT: Feature request for Expert Sleepers
-- NOT functional code - documents what i2c parity with sysex would enable

--[[
FEATURE REQUEST FOR EXPERT SLEEPERS
====================================

Request: Port these sysex commands to i2c for Teletype/Crow users:

| Sysex | Function                      | Proposed i2c |
|-------|-------------------------------|--------------|
| 32H   | Add algorithm by guid + specs | 0x32         |
| 33H   | Remove algorithm at index     | 0x33         |
| 35H   | New preset (clear all)        | 0x35         |
| 60H   | Get algorithm count           | 0x60         |

KEY CONCEPTS: INDEX vs CHANNEL
==============================

Algorithm Index:
  - When you add algorithms to NT, they get indices (1, 2, 3...)
  - To edit params via i2c, you first SELECT the algorithm by index
  - SET_PARAM with param 255 = index selects the "current algorithm"
  - Then subsequent SET_PARAM calls target that algorithm

i2c Channel:
  - Each algorithm has an "i2c channel" PARAMETER
  - NOTE_ON/OFF messages specify a channel
  - Algorithms only respond to notes on their configured channel
  - This is set via the algorithm's i2c_channel param (like any other param)

These are DECOUPLED:
  - Algorithm at index 3 might listen on channel 1
  - Algorithm at index 1 might listen on channel 5
  - You control this by setting each algorithm's i2c_channel param

THE VISION: CHAINS, NOT PRESETS
===============================

Users want to build "chains" - serial signal paths - without managing
preset files on the NT SD card. A chain might be:

  "Warm Pad"    = Poly Wavetable -> VCF (SVF) -> Reverb
  "Plucky Bass" = Poly FM -> Compressor
  "VCO + Filter"= VCO Wavetable -> VCF (SVF)

With i2c algorithm control, Norns/Teletype/Crow could:

1. Add algorithms on-the-fly as chains are activated
2. Set each algorithm's i2c_channel param for note routing
3. Configure other params (output bus assignments, etc.)
4. Remove algorithms when chains are deactivated

EXAMPLE WORKFLOW (if i2c had these commands):

  User activates Lane 1 "VCO + Filter" chain:
    -> i2c 0x32 'vcot' (add VCO Wavetable, NT assigns index N)
    -> select algorithm N (param 255 = N)
    -> set i2c_channel = 1 (so Lane 1 notes reach this algo)
    -> set VCO output -> internal bus
    -> i2c 0x32 'fsvf' (add VCF SVF, NT assigns index N+1)
    -> select algorithm N+1
    -> set VCF input <- internal bus
    -> set VCF output -> Output 1

  Lane 1 plays notes:
    -> NOTE_ON(channel=1, note, velocity)
    -> VCO Wavetable (listening on channel 1) responds

  User deactivates Lane 1:
    -> i2c 0x33 index N+1 (remove VCF)
    -> i2c 0x33 index N (remove VCO)

No preset files. Sequencer owns chain definitions.

--]]

------------------------------------------------------------
-- What We Have Today (implemented in disting_nt/)
------------------------------------------------------------

--[[

CURRENT IMPLEMENTATION (disting_nt/ module):

Structure:
  disting_nt/
    init.lua        - Public API, note handling, lane params
    i2c.lua         - Low-level i2c communication
    algorithms.lua  - Data-driven definitions for 9 voice + 1 filter algo
    params.lua      - Generic param creation from definitions
    ui.lua          - UI helpers for lane_config
    chains.lua      - All algorithm options + multi-algo chain presets

Supported Algorithms:
  Voice (note-receiving):
    - Poly FM (pyfm)
    - Poly Plaits (pym2)
    - Poly Multisample (pymu)
    - Poly Resonator (pyri)
    - Poly Wavetable (pywt)
    - Seaside Jawari (ssjw)
    - VCO Pulsar (vcop)
    - VCO Waveshaping (vcow)
    - VCO Wavetable (vcot)

  Effects (for chains):
    - VCF SVF (fsvf)

CURRENT USER FLOW (Short-Term Workaround):

1. User manually sets up algorithm(s) on NT via NT UI or preset file
2. User sets each algorithm's i2c_channel param on NT:
   - Single algorithm: set i2c_channel = 1
   - Multiple algorithms: set i2c_channel = 1, 2, 3... matching desired lane
3. In Seeker: Lane Config -> Disting NT
4. Select algorithm type that matches NT setup
5. Activate
6. Adjust params (sent via i2c - assumes algorithm index = lane number)
7. Notes from lane -> i2c NOTE_ON/OFF on lane's i2c_channel

CONVENTION FOR MULTI-LANE SETUPS:
  - Load algorithms in lane order (algo 1 for lane 1, algo 2 for lane 2...)
  - Set each algorithm's i2c_channel to match its index
  - Lane N sends notes on channel N and edits algorithm at index N

LIMITATIONS (awaiting i2c parity):
  - Can't add/remove algorithms from Norns
  - User must manually match NT preset to Seeker selection
  - User must manually set i2c_channel on NT
  - Param editing assumes algorithm index = lane number (fragile)
  - Can't query what algorithms are loaded on NT

--]]

------------------------------------------------------------
-- Hypothetical i2c Commands (if implemented by ES)
------------------------------------------------------------

local CMD = {
  -- Existing commands (work today)
  SET_PARAM       = 0x46,  -- Set parameter to value (param 255 = select algo)
  GET_PARAM       = 0x48,  -- Get parameter value
  NOTE_PITCH_CH   = 0x68,  -- Set pitch for note
  NOTE_ON_CH      = 0x69,  -- Note on with channel
  NOTE_OFF_CH     = 0x6A,  -- Note off with channel

  -- Hypothetical new commands (mirroring sysex)
  ADD_ALGORITHM   = 0x32,  -- Add algorithm by guid + specs, returns index
  REMOVE_ALGO     = 0x33,  -- Remove algorithm at index
  LOAD_PRESET     = 0x34,  -- Load preset by filename
  NEW_PRESET      = 0x35,  -- Clear preset (remove all algorithms)
  GET_ALGO_COUNT  = 0x60,  -- Get number of algorithms in preset
}

------------------------------------------------------------
-- Future: What changes when i2c gains algorithm control
------------------------------------------------------------

--[[

When ES implements ADD_ALGORITHM (0x32) and REMOVE_ALGO (0x33):

1. chains.lua gains activation logic:
   - On chain activate: send ADD_ALGORITHM for each algo in chain
   - Track returned indices
   - Set i2c_channel param on note-receiving algorithm = lane number
   - Configure routing (output bus -> input bus connections)

2. Lane deactivation cleans up:
   - Send REMOVE_ALGO for each index used by chain
   - NT workspace shrinks automatically

3. No manual NT setup required:
   - User just selects chain in Seeker and activates
   - Norns builds it on NT automatically
   - i2c_channel assignment is automatic

4. Live chain switching:
   - Deactivate old chain (remove algos)
   - Activate new chain (add algos)
   - Seamless during performance

5. Multi-lane support becomes robust:
   - Each lane adds its own algorithm(s)
   - Each lane sets i2c_channel = lane_number
   - No index/channel confusion

--]]

return {
  CMD = CMD,
  description = "Reference document for i2c feature request to Expert Sleepers"
}

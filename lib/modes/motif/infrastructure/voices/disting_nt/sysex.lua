-- disting_nt/sysex.lua
-- SysEx protocol layer for Disting NT algorithm lifecycle management
-- Sends MIDI SysEx messages via i2c using the 0x81/0x82/0x83 commands

local i2c = include("lib/modes/motif/infrastructure/voices/disting_nt/i2c")

local sysex = {}

------------------------------------------------------------
-- Constants
------------------------------------------------------------

-- Expert Sleepers SysEx header
sysex.MANUFACTURER_ID = {0x00, 0x21, 0x27}
sysex.NT_PRODUCT_ID = 0x6D
sysex.DEVICE_ID = 0x00  -- Default, configurable per user's NT settings

-- SysEx command bytes (from NT manual)
sysex.CMD = {
  ADD_ALGORITHM = 0x32,
  REMOVE_ALGORITHM = 0x33,
  LOAD_PRESET = 0x34,
  NEW_PRESET = 0x35,
  SET_PARAM = 0x46,
  SET_FOCUS = 0x4A,
}

-- i2c command bytes for sending MIDI (confirmed by creator)
sysex.I2C_MIDI = {
  SEND_1 = 0x81,  -- 1 MIDI byte
  SEND_2 = 0x82,  -- 2 MIDI bytes
  SEND_3 = 0x83,  -- 3 MIDI bytes
}

------------------------------------------------------------
-- State Tracking
------------------------------------------------------------

-- Track algorithms added per lane for later removal
-- lane_algorithms[lane_idx] = { indices = {...}, guids = {...} }
sysex.lane_algorithms = {}

-- Global counter for algorithm indices (reset on clear_preset)
-- NT uses 1-based indices for algorithms
sysex.next_algo_index = 1

------------------------------------------------------------
-- 16-bit Value Encoding
------------------------------------------------------------

-- Encode a 16-bit value into 3 SysEx-safe bytes
-- Format: <msb 2 bits> <mid 7 bits> <lsb 7 bits>
function sysex.encode_16bit(value)
  if value < 0 then
    value = 65536 + value  -- Convert signed to unsigned
  end
  local msb = math.floor(value / 16384) % 4   -- Top 2 bits
  local mid = math.floor(value / 128) % 128   -- Middle 7 bits
  local lsb = value % 128                      -- Bottom 7 bits
  return msb, mid, lsb
end

------------------------------------------------------------
-- SysEx Message Encoding
------------------------------------------------------------

-- Build SysEx header (common to all messages)
local function build_header()
  return {
    0xF0,                           -- SysEx start
    sysex.MANUFACTURER_ID[1],       -- 0x00
    sysex.MANUFACTURER_ID[2],       -- 0x21
    sysex.MANUFACTURER_ID[3],       -- 0x27
    sysex.NT_PRODUCT_ID,            -- 0x6D
    sysex.DEVICE_ID,                -- Device ID
  }
end

-- Encode ADD_ALGORITHM SysEx message
-- guid: 4-character string (e.g., "pymu")
-- specs: table with spec1, spec2, spec3 (optional, defaults to 0)
function sysex.encode_add_algorithm(guid, specs)
  specs = specs or {}
  local msg = build_header()

  table.insert(msg, sysex.CMD.ADD_ALGORITHM)  -- 0x32

  -- GUID: exactly 4 ASCII bytes
  for i = 1, 4 do
    table.insert(msg, string.byte(guid, i) or 0)
  end

  -- Specification values (3 bytes each)
  local s1_msb, s1_mid, s1_lsb = sysex.encode_16bit(specs.spec1 or 0)
  local s2_msb, s2_mid, s2_lsb = sysex.encode_16bit(specs.spec2 or 0)
  local s3_msb, s3_mid, s3_lsb = sysex.encode_16bit(specs.spec3 or 0)

  table.insert(msg, s1_msb)
  table.insert(msg, s1_mid)
  table.insert(msg, s1_lsb)
  table.insert(msg, s2_msb)
  table.insert(msg, s2_mid)
  table.insert(msg, s2_lsb)
  table.insert(msg, s3_msb)
  table.insert(msg, s3_mid)
  table.insert(msg, s3_lsb)

  table.insert(msg, 0xF7)  -- SysEx end

  return msg
end

-- Encode REMOVE_ALGORITHM SysEx message
-- index: 1-based internally, converted to 0-based for SysEx
function sysex.encode_remove_algorithm(index)
  local msg = build_header()

  table.insert(msg, sysex.CMD.REMOVE_ALGORITHM)  -- 0x33
  table.insert(msg, index - 1)                    -- Convert to 0-based for SysEx
  table.insert(msg, 0xF7)                         -- SysEx end

  return msg
end

-- Encode NEW_PRESET SysEx message (clears all algorithms)
function sysex.encode_new_preset()
  local msg = build_header()

  table.insert(msg, sysex.CMD.NEW_PRESET)  -- 0x35
  table.insert(msg, 0xF7)                  -- SysEx end

  return msg
end

-- Encode SET_PARAM SysEx message
-- algo_index: 1-based internally, converted to 0-based for SysEx
-- param_num: parameter number
-- value: parameter value
function sysex.encode_set_param(algo_index, param_num, value)
  local msg = build_header()

  table.insert(msg, sysex.CMD.SET_PARAM)  -- 0x46
  table.insert(msg, algo_index - 1)       -- Convert to 0-based for SysEx

  -- Parameter number (16-bit encoded as 3 bytes)
  local p_msb, p_mid, p_lsb = sysex.encode_16bit(param_num)
  table.insert(msg, p_msb)
  table.insert(msg, p_mid)
  table.insert(msg, p_lsb)

  -- Value (16-bit encoded as 3 bytes)
  local v_msb, v_mid, v_lsb = sysex.encode_16bit(value)
  table.insert(msg, v_msb)
  table.insert(msg, v_mid)
  table.insert(msg, v_lsb)

  table.insert(msg, 0xF7)  -- SysEx end

  return msg
end

------------------------------------------------------------
-- i2c Transmission
------------------------------------------------------------

-- Send MIDI bytes via i2c in chunks of 3
-- NT buffers until F7, ignores bytes after F7
function sysex.send_midi(midi_bytes)
  for i = 1, #midi_bytes, 3 do
    local b1 = midi_bytes[i] or 0
    local b2 = midi_bytes[i + 1] or 0
    local b3 = midi_bytes[i + 2] or 0
    crow.ii.raw(i2c.ADDRESS, string.char(sysex.I2C_MIDI.SEND_3, b1, b2, b3))
  end
end

------------------------------------------------------------
-- High-Level Lifecycle Commands
------------------------------------------------------------

-- Add an algorithm to the NT preset
-- Returns the assigned index (tracked locally)
function sysex.add_algorithm(guid, specs)
  local msg = sysex.encode_add_algorithm(guid, specs)
  sysex.send_midi(msg)

  local assigned_index = sysex.next_algo_index
  sysex.next_algo_index = sysex.next_algo_index + 1

  return assigned_index
end

-- Remove an algorithm from the NT preset
function sysex.remove_algorithm(index)
  local msg = sysex.encode_remove_algorithm(index)
  sysex.send_midi(msg)
end

-- Clear all algorithms from the NT preset
function sysex.clear_preset()
  local msg = sysex.encode_new_preset()
  sysex.send_midi(msg)

  -- Reset state (NT uses 1-based indices)
  sysex.next_algo_index = 1
  sysex.lane_algorithms = {}
end

-- Set a parameter on an algorithm by index
function sysex.set_param(algo_index, param_num, value)
  local msg = sysex.encode_set_param(algo_index, param_num, value)
  sysex.send_midi(msg)
end

-- Create SysEx message to show parameter on NT hardware display
function sysex.encode_set_focus(algo_index, param_num)
  local msg = build_header()

  table.insert(msg, sysex.CMD.SET_FOCUS)  -- 0x4A
  table.insert(msg, algo_index - 1)       -- Convert to 0-based for SysEx

  -- Parameter number (16-bit encoded as 3 bytes, 0-based for SysEx)
  local p_msb, p_mid, p_lsb = sysex.encode_16bit(param_num - 1)
  table.insert(msg, p_msb)
  table.insert(msg, p_mid)
  table.insert(msg, p_lsb)

  table.insert(msg, 0xF7)  -- SysEx end

  return msg
end

-- Show parameter on NT hardware display
function sysex.set_focus(algo_index, param_num)
  local msg = sysex.encode_set_focus(algo_index, param_num)
  sysex.send_midi(msg)
end

------------------------------------------------------------
-- Lane Management
------------------------------------------------------------

-- Store algorithm indices for a lane (for later removal)
function sysex.store_lane_algorithms(lane_idx, indices, guids)
  sysex.lane_algorithms[lane_idx] = {
    indices = indices,
    guids = guids,
  }
end

-- Get stored algorithm data for a lane
function sysex.get_lane_algorithms(lane_idx)
  return sysex.lane_algorithms[lane_idx]
end

-- Clear stored algorithm data for a lane
function sysex.clear_lane_algorithms(lane_idx)
  sysex.lane_algorithms[lane_idx] = nil
end

------------------------------------------------------------
-- Initialization
------------------------------------------------------------

-- Reset state (call on Seeker init)
function sysex.init()
  sysex.next_algo_index = 1  -- NT uses 1-based indices
  sysex.lane_algorithms = {}
end

return sysex

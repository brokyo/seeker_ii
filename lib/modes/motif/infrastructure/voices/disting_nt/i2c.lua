-- disting_nt/i2c.lua
-- Low-level i2c communication with Disting NT

local i2c = {}

------------------------------------------------------------
-- Constants
------------------------------------------------------------

i2c.ADDRESS = 0x41

i2c.CMD = {
  -- Controller/parameter commands
  SET_CONTROLLER = 0x11,  -- Set i2c controller X to value Y
  SET_PARAM      = 0x46,  -- Set parameter to actual value
  SET_PARAM_NORM = 0x47,  -- Set parameter (0-16384 scaled to range)
  GET_PARAM      = 0x48,  -- Get parameter value
  GET_PARAM_MIN  = 0x49,  -- Get parameter min
  GET_PARAM_MAX  = 0x4A,  -- Get parameter max

  -- Note commands (without channel)
  NOTE_PITCH     = 0x54,  -- Set pitch for note id
  NOTE_ON        = 0x55,  -- Note on
  NOTE_OFF       = 0x56,  -- Note off
  ALL_NOTES_OFF  = 0x57,  -- All notes off

  -- Note commands (with channel)
  NOTE_PITCH_CH  = 0x68,  -- Set pitch with channel
  NOTE_ON_CH     = 0x69,  -- Note on with channel
  NOTE_OFF_CH    = 0x6A,  -- Note off with channel
  SET_CHANNEL    = 0x6B,  -- Set channel for subsequent commands
}

------------------------------------------------------------
-- Value Conversion
------------------------------------------------------------

-- Split 16-bit value into MSB and LSB bytes
function i2c.split_bytes(value)
  local msb = math.floor(value / 256) % 256
  local lsb = value % 256
  return msb, lsb
end

-- Convert signed value to unsigned 16-bit
function i2c.to_unsigned(value)
  if value < 0 then
    return 65536 + value
  end
  return value
end

-- Convert MIDI note (0-127) to NT pitch value
-- 0V = middle C = MIDI 60, scaled as 16384 = 10V
function i2c.midi_to_pitch(midi_note)
  local volts = (midi_note - 60) / 12
  return math.floor(volts * 1638.4)
end

-- Scale velocity (0-127) with volume multiplier to NT velocity (0-16384)
function i2c.scale_velocity(velocity_0_127, volume_multiplier)
  return math.floor(velocity_0_127 * volume_multiplier * 16384 / 127)
end

------------------------------------------------------------
-- Raw i2c Communication
------------------------------------------------------------

-- Send raw bytes to NT
function i2c.send(bytes)
  local bytestring = string.char(table.unpack(bytes))
  crow.ii.raw(i2c.ADDRESS, bytestring)
end

------------------------------------------------------------
-- Algorithm Selection
------------------------------------------------------------

-- Select which algorithm (by i2c channel) receives subsequent parameter changes
-- Uses the param 255 workaround documented in NT manual
function i2c.select_algorithm(channel)
  local msb, lsb = i2c.split_bytes(channel)
  i2c.send({i2c.CMD.SET_PARAM, 255, msb, lsb})
end

------------------------------------------------------------
-- Parameter Commands
------------------------------------------------------------

-- Set parameter to actual value (call select_algorithm first)
function i2c.set_param(param_num, value)
  local unsigned = i2c.to_unsigned(value)
  local msb, lsb = i2c.split_bytes(unsigned)
  i2c.send({i2c.CMD.SET_PARAM, param_num, msb, lsb})
end

-- Set parameter with algorithm selection in one call
function i2c.set_param_at_channel(channel, param_num, value)
  i2c.select_algorithm(channel)
  i2c.set_param(param_num, value)
end

------------------------------------------------------------
-- Note Commands (with channel)
------------------------------------------------------------

function i2c.note_pitch(channel, note_id, pitch)
  local msb, lsb = i2c.split_bytes(i2c.to_unsigned(pitch))
  i2c.send({i2c.CMD.NOTE_PITCH_CH, channel, note_id, msb, lsb})
end

function i2c.note_on(channel, note_id, velocity)
  local msb, lsb = i2c.split_bytes(velocity)
  i2c.send({i2c.CMD.NOTE_ON_CH, channel, note_id, msb, lsb})
end

function i2c.note_off(channel, note_id)
  i2c.send({i2c.CMD.NOTE_OFF_CH, channel, note_id})
end

function i2c.all_notes_off()
  i2c.send({i2c.CMD.ALL_NOTES_OFF})
end

function i2c.set_channel(channel)
  i2c.send({i2c.CMD.SET_CHANNEL, channel})
end

return i2c

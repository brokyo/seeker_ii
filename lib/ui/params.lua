-- params.lua
-- Manage norns-stored params
local params_manager = {}
local musicutil = require('musicutil')
local theory = include('lib/motif_core/theory')

-- Get sorted list of available instruments
function params_manager.get_instrument_list()
    local instruments = {}
    for k, v in pairs(_seeker.skeys.instrument) do
        table.insert(instruments, k)
    end
    table.sort(instruments)
    return instruments
end

-- Initialize MIDI input parameters
local function add_midi_input_params()
    params:add_group("midi_input", "MIDI INPUT", 1)

    -- MIDI input device selection (None = disabled)
    local midi_devices = {"None"}
    for i = 1, #midi.vports do
        local name = midi.vports[i].name or string.format("Port %d", i)
        table.insert(midi_devices, name)
    end

    params:add{
        type = "option",
        id = "midi_input_device",
        name = "MIDI Input Device",
        options = midi_devices,
        default = 2, -- Default to first available device
        action = function(value)
            if _seeker.midi_input then
                if value > 1 then
                    -- Enable MIDI and set device
                    _seeker.midi_input.set_enabled(true)
                    _seeker.midi_input.set_device(value - 1)
                else
                    -- Disable MIDI input when "None" is selected
                    _seeker.midi_input.set_enabled(false)
                end
            end
        end
    }
end

function params_manager.init_params()
    -- Note: All lane parameters are now created by LaneConfig component
    -- This includes voice, stage, and motif playback parameters

    -- Add MIDI input parameters
    add_midi_input_params()
end

return params_manager

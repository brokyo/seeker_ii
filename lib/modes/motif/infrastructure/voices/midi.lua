-- midi.lua
-- MIDI voice parameters for lane configuration

local midi_voice = {}

midi_voice.name = "MIDI"

function midi_voice.create_params(i)
    params:add_binary("lane_" .. i .. "_midi_active", "MIDI Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_midi_active", function(value)
        if value == 1 then
            _seeker.lanes[i].midi_active = true
        else
            _seeker.lanes[i].midi_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_midi_voice_volume", "MIDI Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_midi_voice_volume", function(value)
        _seeker.lanes[i].midi_voice_volume = value
    end)

    local device_names = {"none"}
    for _, dev in pairs(midi.devices) do
        table.insert(device_names, dev.name)
    end
    params:add_option("lane_" .. i .. "_midi_device", "MIDI Device", device_names, 1)
    params:set_action("lane_" .. i .. "_midi_device", function(value)
        if value > 1 then
            -- value 1 = "none", value 2 = first device (index 1), etc.
            _seeker.lanes[i].midi_out_device = midi.connect(value - 1)
        else
            _seeker.lanes[i].midi_out_device = nil
        end
    end)

    params:add_number("lane_" .. i .. "_midi_channel", "MIDI Channel", 0, 16, 0)
    params:set_action("lane_" .. i .. "_midi_channel", function(value)
        _seeker.lanes[i].midi_channel = value
    end)
end

function midi_voice.get_ui_params(lane_idx)
    local ui_params = {}
    table.insert(ui_params, { id = "lane_" .. lane_idx .. "_midi_active" })

    if params:get("lane_" .. lane_idx .. "_midi_active") == 1 then
        table.insert(ui_params, { separator = true, title = "Voice Settings" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_midi_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_midi_device" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_midi_channel" })
    end

    return ui_params
end

return midi_voice

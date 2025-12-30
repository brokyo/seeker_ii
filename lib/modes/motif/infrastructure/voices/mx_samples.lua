-- mx_samples.lua
-- MX Samples voice parameters for lane configuration

local mx_samples = {}

mx_samples.name = "mx. samples"

function mx_samples.get_instrument_list()
    local instruments = {}
    for k, v in pairs(_seeker.skeys.instrument) do
        table.insert(instruments, k)
    end
    table.sort(instruments)
    return instruments
end

function mx_samples.create_params(i)
    params:add_binary("lane_" .. i .. "_mx_samples_active", "MX Samples Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_mx_samples_active", function(value)
        if value == 1 then
            _seeker.lanes[i].mx_samples_active = true
        else
            _seeker.lanes[i].mx_samples_active = false
        end
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_mx_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_mx_voice_volume", function(value)
        _seeker.lanes[i].mx_voice_volume = value
    end)

    local instruments = mx_samples.get_instrument_list()
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)

    -- ADSR envelope controls
    params:add_control("lane_" .. i .. "_attack", "Attack", controlspec.new(0, 10, 'lin', 0.01, 0, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_attack", function(value)
        _seeker.lanes[i].attack = value
    end)

    params:add_control("lane_" .. i .. "_decay", "Decay", controlspec.new(0, 10, 'lin', 0.01, 1, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_decay", function(value)
        _seeker.lanes[i].decay = value
    end)

    params:add_control("lane_" .. i .. "_sustain", "Sustain", controlspec.new(0, 2, 'lin', 0.01, 0.9, ""),
        function(param) return string.format("%d%%", math.floor(param:get() * 100)) end)
    params:set_action("lane_" .. i .. "_sustain", function(value)
        _seeker.lanes[i].sustain = value
    end)

    params:add_control("lane_" .. i .. "_release", "Release", controlspec.new(0, 10, 'lin', 0.01, 2, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_release", function(value)
        _seeker.lanes[i].release = value
    end)

    params:add_control("lane_" .. i .. "_pan", "Pan", controlspec.new(-1, 1, 'lin', 0.01, 0, "", 0.01))
    params:set_action("lane_" .. i .. "_pan", function(value)
        _seeker.lanes[i].pan = value
    end)

    -- Filter controls
    params:add_taper("lane_" .. i .. "_lpf", "LPF Cutoff", 20, 20000, 20000, 3, "Hz")
    params:set_action("lane_" .. i .. "_lpf", function(value)
        _seeker.lanes[i].lpf = value
    end)

    params:add_control("lane_" .. i .. "_resonance", "LPF Resonance", controlspec.new(0, 4, 'lin', 0.01, 0, ""))
    params:set_action("lane_" .. i .. "_resonance", function(value)
        _seeker.lanes[i].resonance = value
    end)

    params:add_taper("lane_" .. i .. "_hpf", "HPF Cutoff", 20, 20000, 20, 3, "Hz")
    params:set_action("lane_" .. i .. "_hpf", function(value)
        _seeker.lanes[i].hpf = value
    end)

    -- Effects sends
    params:add_control("lane_" .. i .. "_delay_send", "Delay", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01),
        function(param) return string.format("%d%%", math.floor(param:get() * 100)) end)
    params:set_action("lane_" .. i .. "_delay_send", function(value)
        _seeker.lanes[i].delay_send = value
    end)

    params:add_control("lane_" .. i .. "_reverb_send", "Reverb", controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01),
        function(param) return string.format("%d%%", math.floor(param:get() * 100)) end)
    params:set_action("lane_" .. i .. "_reverb_send", function(value)
        _seeker.lanes[i].reverb_send = value
    end)
end

function mx_samples.get_ui_params(lane_idx)
    local ui_params = {}
    table.insert(ui_params, { id = "lane_" .. lane_idx .. "_mx_samples_active" })

    if params:get("lane_" .. lane_idx .. "_mx_samples_active") == 1 then
        table.insert(ui_params, { separator = true, title = "Voice Settings" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_mx_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_instrument" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_pan", arc_multi_float = {0.1, 0.05, 0.01} })

        table.insert(ui_params, { separator = true, title = "Envelope" })
        table.insert(ui_params, {
            id = "lane_" .. lane_idx .. "_adsr_visual_edit",
            is_action = true,
            custom_name = "Visual Edit"
        })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_attack", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_decay", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_sustain", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_release", arc_multi_float = {1.0, 0.5, 0.1} })

        table.insert(ui_params, { separator = true, title = "Filter" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_lpf", arc_multi_float = {1000, 100, 10} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_resonance", arc_multi_float = {0.5, 0.1, 0.05} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_hpf", arc_multi_float = {1000, 100, 10} })

        table.insert(ui_params, { separator = true, title = "Effects" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_delay_send", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_reverb_send", arc_multi_float = {0.1, 0.05, 0.01} })
    end

    return ui_params
end

return mx_samples

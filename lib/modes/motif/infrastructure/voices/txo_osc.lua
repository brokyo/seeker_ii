-- txo_osc.lua
-- TXO oscillator voice parameters for lane configuration
-- Uses TXO's built-in oscillators as sound source (not CV/Gate to external gear)

local txo_osc = {}

-- Waveform presets: sine=0, tri=1000, saw=2000, pulse=3000, noise=4000
-- "custom" shown when morph is at a non-preset value (user controlling manually)
local WAVEFORMS = {"sine", "triangle", "saw", "pulse", "noise", "custom"}
local PRESET_MORPH_VALUES = {0, 1000, 2000, 3000, 4000}

-- Mode options for envelope behavior
local MODES = {"drone", "triggered"}

function txo_osc.create_params(i)
    params:add_binary("lane_" .. i .. "_txo_osc_active", "TXO Osc Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_txo_osc_active", function(value)
        _seeker.lanes[i].txo_osc_active = (value == 1)

        if value == 1 then
            local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
            local mode = params:get("lane_" .. i .. "_txo_osc_mode")

            -- Initialize oscillator settings
            crow.ii.txo.osc_wave(osc_select, params:get("lane_" .. i .. "_txo_osc_morph"))
            crow.ii.txo.osc_width(osc_select, params:get("lane_" .. i .. "_txo_osc_width"))
            crow.ii.txo.osc_slew(osc_select, params:get("lane_" .. i .. "_txo_osc_slew"))

            if mode == 2 then -- triggered mode: enable envelope
                crow.ii.txo.env_act(osc_select, 1)
                crow.ii.txo.env_att(osc_select, params:get("lane_" .. i .. "_txo_osc_attack") * 1000)
                crow.ii.txo.env_dec(osc_select, params:get("lane_" .. i .. "_txo_osc_decay") * 1000)
            else -- drone mode: disable envelope, set CV high and leave it
                crow.ii.txo.env_act(osc_select, 0)
                crow.ii.txo.cv_set(osc_select, params:get("lane_" .. i .. "_txo_osc_volume") * 5)
            end
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_txo_osc_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_txo_osc_volume", function(value)
        _seeker.lanes[i].txo_osc_volume = value
        -- Update CV immediately in drone mode
        local mode = params:get("lane_" .. i .. "_txo_osc_mode")
        if mode == 1 and params:get("lane_" .. i .. "_txo_osc_active") == 1 then
            local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
            crow.ii.txo.cv_set(osc_select, value * 5)
        end
    end)

    params:add_option("lane_" .. i .. "_txo_osc_select", "Oscillator", {"1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_txo_osc_select", function(value)
        _seeker.lanes[i].txo_osc_select = value
    end)

    params:add_option("lane_" .. i .. "_txo_osc_mode", "Mode", MODES, 1)
    params:set_action("lane_" .. i .. "_txo_osc_mode", function(value)
        _seeker.lanes[i].txo_osc_mode = value
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        if value == 2 then -- triggered mode: enable envelope for AD shaping
            crow.ii.txo.env_act(osc_select, 1)
            crow.ii.txo.env_att(osc_select, params:get("lane_" .. i .. "_txo_osc_attack") * 1000)
            crow.ii.txo.env_dec(osc_select, params:get("lane_" .. i .. "_txo_osc_decay") * 1000)
        else -- drone mode: disable envelope, set CV high and leave it on
            crow.ii.txo.env_act(osc_select, 0)
            crow.ii.txo.cv_set(osc_select, params:get("lane_" .. i .. "_txo_osc_volume") * 5)
        end
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_option("lane_" .. i .. "_txo_osc_wave", "Waveform", WAVEFORMS, 1)
    params:set_action("lane_" .. i .. "_txo_osc_wave", function(value)
        if value <= 5 then -- Preset selected: set morph to preset value
            params:set("lane_" .. i .. "_txo_osc_morph", PRESET_MORPH_VALUES[value], true)
            local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
            crow.ii.txo.osc_wave(osc_select, PRESET_MORPH_VALUES[value])
        end
        -- "custom" (6): don't change morph, user controls it directly
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_txo_osc_morph", "Morph", controlspec.new(0, 5000, 'lin', 1, 0, ""),
        function(param) return string.format("%d", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_morph", function(value)
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        crow.ii.txo.osc_wave(osc_select, value)
        -- Update waveform display: show preset name or "custom"
        local preset_idx = nil
        for idx, preset_val in ipairs(PRESET_MORPH_VALUES) do
            if value == preset_val then
                preset_idx = idx
                break
            end
        end
        params:set("lane_" .. i .. "_txo_osc_wave", preset_idx or 6, true)
    end)

    params:add_control("lane_" .. i .. "_txo_osc_width", "Pulse Width", controlspec.new(0, 100, 'lin', 1, 50, "%"),
        function(param) return string.format("%d%%", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_width", function(value)
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        crow.ii.txo.osc_width(osc_select, value)
    end)

    params:add_control("lane_" .. i .. "_txo_osc_slew", "Slew", controlspec.new(0, 2000, 'lin', 1, 0, "ms"),
        function(param) return string.format("%d ms", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_slew", function(value)
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        crow.ii.txo.osc_slew(osc_select, value)
    end)

    -- Envelope params (used in triggered mode) - values in seconds, converted to ms for TXO
    params:add_control("lane_" .. i .. "_txo_osc_attack", "Attack", controlspec.new(0, 10, 'lin', 0.01, 0, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_attack", function(value)
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        crow.ii.txo.env_att(osc_select, value * 1000)
    end)

    params:add_control("lane_" .. i .. "_txo_osc_decay", "Decay", controlspec.new(0, 10, 'lin', 0.01, 1, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_decay", function(value)
        local osc_select = params:get("lane_" .. i .. "_txo_osc_select")
        crow.ii.txo.env_dec(osc_select, value * 1000)
    end)
end

return txo_osc

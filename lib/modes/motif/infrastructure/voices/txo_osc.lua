-- txo_osc.lua
-- TXO oscillator voice parameters for lane configuration
-- Uses TXO's built-in oscillators as sound source (not CV/Gate to external gear)
-- Supports polyphonic round-robin voice allocation across configurable output range

local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")

local txo_osc = {}

-- Waveform presets: sine=0, tri=1000, saw=2000, pulse=3000, noise=4000
-- "custom" shown when morph is at a non-preset value (user controlling manually)
local WAVEFORMS = {"sine", "triangle", "saw", "pulse", "noise", "custom"}
local PRESET_MORPH_VALUES = {0, 1000, 2000, 3000, 4000}

-- Mode options for envelope behavior
local MODES = {"drone", "triggered"}

-- Round-robin allocation state per lane
local osc_pools = {}
-- Per-oscillator morph values: osc_morphs[lane_id][osc_num] = morph_value
local osc_morphs = {}
-- Per-oscillator volume values: osc_volumes[lane_id][osc_num] = volume_value
local osc_volumes = {}
for i = 1, 8 do
    osc_pools[i] = {
        next_index = 1  -- Position within lane's oscillator range (1 to count)
    }
    osc_morphs[i] = {0, 0, 0, 0}  -- Default morph for oscillators 1-4
    osc_volumes[i] = {1, 1, 1, 1}  -- Default volume for oscillators 1-4
end

-- Get stored morph value for a specific oscillator
function txo_osc.get_osc_morph(lane_id, osc_num)
    return osc_morphs[lane_id][osc_num] or 0
end

-- Set stored morph value for a specific oscillator
function txo_osc.set_osc_morph(lane_id, osc_num, value)
    osc_morphs[lane_id][osc_num] = value
end

-- Get stored volume for a specific oscillator
function txo_osc.get_osc_volume(lane_id, osc_num)
    return osc_volumes[lane_id][osc_num] or 1
end

-- Set stored volume for a specific oscillator
function txo_osc.set_osc_volume(lane_id, osc_num, value)
    osc_volumes[lane_id][osc_num] = value
end

-- Get list of available (non-CV-claimed) outputs for a lane
function txo_osc.get_available_outputs(lane_id)
    local start = params:get("lane_" .. lane_id .. "_txo_osc_start")
    local count = params:get("lane_" .. lane_id .. "_txo_osc_count")
    local available = {}

    for i = 0, count - 1 do
        local osc_num = start + i
        if not EurorackUtils.is_txo_cv_active(osc_num) then
            table.insert(available, osc_num)
        end
    end

    return available
end

-- Get next oscillator output for a lane using round-robin allocation
-- Skips outputs that are claimed by CV mode
function txo_osc.get_next_osc(lane_id)
    local start = params:get("lane_" .. lane_id .. "_txo_osc_start")
    local count = params:get("lane_" .. lane_id .. "_txo_osc_count")
    local pool = osc_pools[lane_id]

    -- Try each output in range, skip CV-active ones
    for _ = 1, count do
        local osc_num = start + pool.next_index - 1
        pool.next_index = (pool.next_index % count) + 1

        if not EurorackUtils.is_txo_cv_active(osc_num) then
            return osc_num
        end
    end

    -- All outputs in range are CV-active, no available voices
    return nil
end

-- Apply a function to each oscillator in this lane's output range
local function apply_to_all_oscs(lane_id, fn)
    local start = params:get("lane_" .. lane_id .. "_txo_osc_start")
    local count = params:get("lane_" .. lane_id .. "_txo_osc_count")
    for offset = 0, count - 1 do
        local osc_num = start + offset
        fn(osc_num)
    end
end

-- Reinitialize all oscillators with current param values (called when range or mode changes)
local function reinit_all_oscs(lane_id)
    if params:get("lane_" .. lane_id .. "_txo_osc_active") ~= 1 then return end

    local mode = params:get("lane_" .. lane_id .. "_txo_osc_mode")
    local width = params:get("lane_" .. lane_id .. "_txo_osc_width")
    local slew = params:get("lane_" .. lane_id .. "_txo_osc_slew")
    local attack = params:get("lane_" .. lane_id .. "_txo_osc_attack") * 1000
    local decay = params:get("lane_" .. lane_id .. "_txo_osc_decay") * 1000
    local volume = params:get("lane_" .. lane_id .. "_txo_osc_volume")

    local start = params:get("lane_" .. lane_id .. "_txo_osc_start")
    local count = params:get("lane_" .. lane_id .. "_txo_osc_count")

    for idx = 1, count do
        local osc_num = start + idx - 1
        local morph = osc_morphs[lane_id][osc_num] or 0

        crow.ii.txo.osc_wave(osc_num, morph)
        crow.ii.txo.osc_width(osc_num, width)
        crow.ii.txo.osc_slew(osc_num, slew)

        if mode == 2 then -- triggered mode
            crow.ii.txo.env_act(osc_num, 1)
            crow.ii.txo.env_att(osc_num, attack)
            crow.ii.txo.env_dec(osc_num, decay)
        else -- drone mode
            crow.ii.txo.env_act(osc_num, 0)
            crow.ii.txo.cv_set(osc_num, volume * 5)
        end
    end
end

-- Reset all TXO oscillators to defaults on script boot
function txo_osc.init()
    for osc_num = 1, 4 do
        crow.ii.txo.cv_set(osc_num, 0)
        crow.ii.txo.env_act(osc_num, 0)
        crow.ii.txo.osc_wave(osc_num, 0)
        crow.ii.txo.osc_width(osc_num, 50)
        crow.ii.txo.osc_slew(osc_num, 0)
    end
end

function txo_osc.create_params(i)
    params:add_binary("lane_" .. i .. "_txo_osc_active", "TXO Osc Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_txo_osc_active", function(value)
        _seeker.lanes[i].txo_osc_active = (value == 1)

        if value == 0 then
            -- Reset oscillators to defaults (silence, disable envelope, sine wave)
            apply_to_all_oscs(i, function(osc_num)
                crow.ii.txo.cv_set(osc_num, 0)  -- Silence
                crow.ii.txo.env_act(osc_num, 0)  -- Disable envelope
                crow.ii.txo.osc_wave(osc_num, 0)  -- Reset to sine
                crow.ii.txo.osc_width(osc_num, 50)  -- Reset pulse width
                crow.ii.txo.osc_slew(osc_num, 0)  -- Reset slew
            end)
        elseif value == 1 then
            local mode = params:get("lane_" .. i .. "_txo_osc_mode")
            local morph = params:get("lane_" .. i .. "_txo_osc_morph")
            local width = params:get("lane_" .. i .. "_txo_osc_width")
            local slew = params:get("lane_" .. i .. "_txo_osc_slew")
            local attack = params:get("lane_" .. i .. "_txo_osc_attack") * 1000
            local decay = params:get("lane_" .. i .. "_txo_osc_decay") * 1000
            local volume = params:get("lane_" .. i .. "_txo_osc_volume")

            -- Initialize all oscillators in range with current morph
            apply_to_all_oscs(i, function(osc_num)
                osc_morphs[i][osc_num] = morph
                crow.ii.txo.osc_wave(osc_num, morph)
                crow.ii.txo.osc_width(osc_num, width)
                crow.ii.txo.osc_slew(osc_num, slew)

                if mode == 2 then -- triggered mode: enable envelope
                    crow.ii.txo.env_act(osc_num, 1)
                    crow.ii.txo.env_att(osc_num, attack)
                    crow.ii.txo.env_dec(osc_num, decay)
                else -- drone mode: disable envelope, set CV high
                    crow.ii.txo.env_act(osc_num, 0)
                    crow.ii.txo.cv_set(osc_num, volume * 5)
                end
            end)

            -- Reset round-robin allocation
            osc_pools[i].next_index = 1
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_txo_osc_volume", "Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_txo_osc_volume", function(value)
        _seeker.lanes[i].txo_osc_volume = value
        -- Set all oscillators in range to this volume
        apply_to_all_oscs(i, function(osc_num)
            osc_volumes[i][osc_num] = value
        end)
        -- Update CV immediately in drone mode
        local mode = params:get("lane_" .. i .. "_txo_osc_mode")
        if mode == 1 and params:get("lane_" .. i .. "_txo_osc_active") == 1 then
            apply_to_all_oscs(i, function(osc_num)
                crow.ii.txo.cv_set(osc_num, value * 5)
            end)
        end
    end)

    params:add_option("lane_" .. i .. "_txo_osc_start", "Start Output", {"1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_txo_osc_start", function(value)
        _seeker.lanes[i].txo_osc_start = value
        osc_pools[i].next_index = 1
        -- Reset selection and update per-osc displays
        params:set("lane_" .. i .. "_txo_osc_selected", 1, true)
        local osc_num = value  -- start + (1-1) = start
        params:set("lane_" .. i .. "_txo_osc_ind_morph", osc_morphs[i][osc_num] or 0, true)
        params:set("lane_" .. i .. "_txo_osc_ind_volume", osc_volumes[i][osc_num] or 1, true)
        reinit_all_oscs(i)
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_option("lane_" .. i .. "_txo_osc_count", "Osc Count", {"1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_txo_osc_count", function(value)
        _seeker.lanes[i].txo_osc_count = value
        osc_pools[i].next_index = 1
        -- Clamp selection and update per-osc displays
        local selected = params:get("lane_" .. i .. "_txo_osc_selected")
        if selected > value then
            params:set("lane_" .. i .. "_txo_osc_selected", value, true)
            selected = value
        end
        local start = params:get("lane_" .. i .. "_txo_osc_start")
        local osc_num = start + selected - 1
        params:set("lane_" .. i .. "_txo_osc_ind_morph", osc_morphs[i][osc_num] or 0, true)
        params:set("lane_" .. i .. "_txo_osc_ind_volume", osc_volumes[i][osc_num] or 1, true)
        reinit_all_oscs(i)
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_option("lane_" .. i .. "_txo_osc_mode", "Mode", MODES, 1)
    params:set_action("lane_" .. i .. "_txo_osc_mode", function(value)
        _seeker.lanes[i].txo_osc_mode = value
        local attack = params:get("lane_" .. i .. "_txo_osc_attack") * 1000
        local decay = params:get("lane_" .. i .. "_txo_osc_decay") * 1000
        local volume = params:get("lane_" .. i .. "_txo_osc_volume")

        apply_to_all_oscs(i, function(osc_num)
            if value == 2 then -- triggered mode: enable envelope for AD shaping
                crow.ii.txo.env_act(osc_num, 1)
                crow.ii.txo.env_att(osc_num, attack)
                crow.ii.txo.env_dec(osc_num, decay)
            else -- drone mode: disable envelope, set CV high
                crow.ii.txo.env_act(osc_num, 0)
                crow.ii.txo.cv_set(osc_num, volume * 5)
            end
        end)
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_option("lane_" .. i .. "_txo_osc_wave", "Waveform", WAVEFORMS, 1)
    params:set_action("lane_" .. i .. "_txo_osc_wave", function(value)
        if value <= 5 then -- Preset selected: set morph to preset value
            local morph_value = PRESET_MORPH_VALUES[value]
            params:set("lane_" .. i .. "_txo_osc_morph", morph_value, true)
            apply_to_all_oscs(i, function(osc_num)
                crow.ii.txo.osc_wave(osc_num, morph_value)
            end)
        end
        -- "custom" (6): don't change morph, user controls it directly
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_txo_osc_morph", "Morph", controlspec.new(0, 5000, 'lin', 1, 0, ""),
        function(param) return string.format("%d", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_morph", function(value)
        -- Set all oscillators in range to this morph value
        apply_to_all_oscs(i, function(osc_num)
            osc_morphs[i][osc_num] = value
            crow.ii.txo.osc_wave(osc_num, value)
        end)

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
        apply_to_all_oscs(i, function(osc_num)
            crow.ii.txo.osc_width(osc_num, value)
        end)
    end)

    params:add_control("lane_" .. i .. "_txo_osc_slew", "Slew", controlspec.new(0, 2000, 'lin', 1, 0, "ms"),
        function(param) return string.format("%d ms", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_slew", function(value)
        apply_to_all_oscs(i, function(osc_num)
            crow.ii.txo.osc_slew(osc_num, value)
        end)
    end)

    -- Envelope params (used in triggered mode) - values in seconds, converted to ms for TXO
    params:add_control("lane_" .. i .. "_txo_osc_attack", "Attack", controlspec.new(0, 10, 'lin', 0.01, 0, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_attack", function(value)
        local attack_ms = value * 1000
        apply_to_all_oscs(i, function(osc_num)
            crow.ii.txo.env_att(osc_num, attack_ms)
        end)
    end)

    params:add_control("lane_" .. i .. "_txo_osc_decay", "Decay", controlspec.new(0, 10, 'lin', 0.01, 1, "s"),
        function(param) return string.format("%.2f s", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_decay", function(value)
        local decay_ms = value * 1000
        apply_to_all_oscs(i, function(osc_num)
            crow.ii.txo.env_dec(osc_num, decay_ms)
        end)
    end)

    -- Per-oscillator configuration: select which oscillator to configure individually
    params:add_number("lane_" .. i .. "_txo_osc_selected", "Select Osc", 1, 4, 1,
        function(param)
            local start = params:get("lane_" .. i .. "_txo_osc_start")
            local osc_num = start + param:get() - 1
            return "Osc " .. osc_num
        end)
    params:set_action("lane_" .. i .. "_txo_osc_selected", function(value)
        -- Clamp to current oscillator count
        local count = params:get("lane_" .. i .. "_txo_osc_count")
        if value > count then
            params:set("lane_" .. i .. "_txo_osc_selected", count, true)
            return
        end
        -- Update per-osc displays to show selected oscillator's current values
        local start = params:get("lane_" .. i .. "_txo_osc_start")
        local osc_num = start + value - 1
        params:set("lane_" .. i .. "_txo_osc_ind_morph", osc_morphs[i][osc_num] or 0, true)
        params:set("lane_" .. i .. "_txo_osc_ind_volume", osc_volumes[i][osc_num] or 1, true)
        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    -- Per-oscillator morph: affects only the selected oscillator
    params:add_control("lane_" .. i .. "_txo_osc_ind_morph", "Osc Morph", controlspec.new(0, 5000, 'lin', 1, 0, ""),
        function(param) return string.format("%d", param:get()) end)
    params:set_action("lane_" .. i .. "_txo_osc_ind_morph", function(value)
        local start = params:get("lane_" .. i .. "_txo_osc_start")
        local selected = params:get("lane_" .. i .. "_txo_osc_selected")
        local osc_num = start + selected - 1
        osc_morphs[i][osc_num] = value
        crow.ii.txo.osc_wave(osc_num, value)
    end)

    -- Per-oscillator volume: affects only the selected oscillator
    params:add_control("lane_" .. i .. "_txo_osc_ind_volume", "Osc Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_txo_osc_ind_volume", function(value)
        local start = params:get("lane_" .. i .. "_txo_osc_start")
        local selected = params:get("lane_" .. i .. "_txo_osc_selected")
        local osc_num = start + selected - 1
        osc_volumes[i][osc_num] = value
        -- Update CV immediately in drone mode
        local mode = params:get("lane_" .. i .. "_txo_osc_mode")
        if mode == 1 and params:get("lane_" .. i .. "_txo_osc_active") == 1 then
            crow.ii.txo.cv_set(osc_num, value * 5)
        end
    end)
end

return txo_osc

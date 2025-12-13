-- wsyn.lua
-- w/syn voice parameters for lane configuration

local wsyn = {}

function wsyn.create_params(i)
    params:add_binary("lane_" .. i .. "_wsyn_active", "w/syn Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_wsyn_active", function(value)
        if value == 1 then
            _seeker.lanes[i].wsyn_active = true
        else
            _seeker.lanes[i].wsyn_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_wsyn_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_wsyn_voice_volume", function(value)
        _seeker.lanes[i].wsyn_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_wsyn_voice_select", "w/syn Voice", {"All", "1", "2", "3", "4"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_voice_select", function(value)
        _seeker.lanes[i].wsyn_voice_select = value
    end)

    params:add_binary("lane_" .. i .. "_wsyn_ar_mode", "Pluck Mode", "toggle", 0)
    params:set_action("lane_" .. i .. "_wsyn_ar_mode", function(value)
        crow.ii.wsyn.ar_mode(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_curve", "Curve", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_curve", function(value)
        crow.ii.wsyn.curve(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_ramp", "Ramp", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_ramp", function(value)
        crow.ii.wsyn.ramp(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_index", "FM Index", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_index", function(value)
        crow.ii.wsyn.fm_index(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_env", "FM Env", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_env", function(value)
        crow.ii.wsyn.fm_env(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_num", "FM Ratio Numerator", controlspec.new(0.01, 1, 'lin', 0.001, 0.5),
        function(param) return string.format("%.3f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_num", function(numerator)
        if _seeker.lanes[i] then
            local denominator = params:get("lane_" .. i .. "_wsyn_fm_ratio_denom")
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_fm_ratio_denom", "FM Ratio Denominator", controlspec.new(0.01, 1, 'lin', 0.001, 0.5),
        function(param) return string.format("%.3f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_fm_ratio_denom", function(denominator)
        if _seeker.lanes[i] then
            local numerator = params:get("lane_" .. i .. "_wsyn_fm_ratio_num")
            crow.ii.wsyn.fm_ratio(numerator, denominator)
        end
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_time", "LPG Time", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_lpg_time", function(value)
        crow.ii.wsyn.lpg_time(value)
    end)

    params:add_control("lane_" .. i .. "_wsyn_lpg_symmetry", "LPG Symmetry", controlspec.new(-5, 5, 'lin', 0.01, 0, ""),
        function(param) return string.format("%.2f", param:get()) end)
    params:set_action("lane_" .. i .. "_wsyn_lpg_symmetry", function(value)
        crow.ii.wsyn.lpg_symmetry(value)
    end)

    params:add_option("lane_" .. i .. "_wsyn_patch_this", "THIS",
        {"ramp", "curve", "fm_env", "fm_index", "lpg_time", "lpg_symmetry", "gate", "pitch", "fm_ratio_num", "fm_ratio_denom"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_patch_this", function(value)
        local param_map = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local param_num = param_map[value]
        crow.ii.wsyn.patch(1, param_num)
    end)

    params:add_option("lane_" .. i .. "_wsyn_patch_that", "THAT",
        {"ramp", "curve", "fm_env", "fm_index", "lpg_time", "lpg_symmetry", "gate", "pitch", "fm_ratio_num", "fm_ratio_denom"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_patch_that", function(value)
        local param_map = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local param_num = param_map[value]
        crow.ii.wsyn.patch(2, param_num)
    end)
end

return wsyn

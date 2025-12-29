-- wsyn.lua
-- w/syn voice parameters for lane configuration

local wsyn = {}

wsyn.name = "w/syn"

-- Send all current param values to w/syn hardware
function wsyn.init(i)
    crow.ii.wsyn.ar_mode(params:get("lane_" .. i .. "_wsyn_ar_mode"))
    crow.ii.wsyn.curve(params:get("lane_" .. i .. "_wsyn_curve"))
    crow.ii.wsyn.ramp(params:get("lane_" .. i .. "_wsyn_ramp"))
    crow.ii.wsyn.fm_index(params:get("lane_" .. i .. "_wsyn_fm_index"))
    crow.ii.wsyn.fm_env(params:get("lane_" .. i .. "_wsyn_fm_env"))
    crow.ii.wsyn.fm_ratio(
        params:get("lane_" .. i .. "_wsyn_fm_ratio_num"),
        params:get("lane_" .. i .. "_wsyn_fm_ratio_denom")
    )
    crow.ii.wsyn.lpg_time(params:get("lane_" .. i .. "_wsyn_lpg_time"))
    crow.ii.wsyn.lpg_symmetry(params:get("lane_" .. i .. "_wsyn_lpg_symmetry"))
end

function wsyn.create_params(i)
    params:add_binary("lane_" .. i .. "_wsyn_active", "w/syn Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_wsyn_active", function(value)
        if value == 1 then
            _seeker.lanes[i].wsyn_active = true
            wsyn.init(i)
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
        crow.ii.wsyn.patch(1, value)
    end)

    params:add_option("lane_" .. i .. "_wsyn_patch_that", "THAT",
        {"ramp", "curve", "fm_env", "fm_index", "lpg_time", "lpg_symmetry", "gate", "pitch", "fm_ratio_num", "fm_ratio_denom"}, 1)
    params:set_action("lane_" .. i .. "_wsyn_patch_that", function(value)
        crow.ii.wsyn.patch(2, value)
    end)
end

function wsyn.get_ui_params(lane_idx)
    local ui_params = {}
    table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_active" })

    if params:get("lane_" .. lane_idx .. "_wsyn_active") == 1 then
        table.insert(ui_params, { separator = true, title = "Voice" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_voice_volume", arc_multi_float = {0.1, 0.05, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_voice_select" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_ar_mode" })

        table.insert(ui_params, { separator = true, title = "Oscillator" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_curve", arc_multi_float = {1.0, 0.1, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_ramp", arc_multi_float = {1.0, 0.1, 0.01} })

        table.insert(ui_params, { separator = true, title = "FM" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_fm_index", arc_multi_float = {1.0, 0.1, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_fm_env", arc_multi_float = {1.0, 0.1, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_num", arc_multi_float = {0.1, 0.01, 0.001} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_fm_ratio_denom", arc_multi_float = {0.1, 0.01, 0.001} })

        table.insert(ui_params, { separator = true, title = "LPG" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_lpg_time", arc_multi_float = {1.0, 0.1, 0.01} })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_lpg_symmetry", arc_multi_float = {1.0, 0.1, 0.01} })

        table.insert(ui_params, { separator = true, title = "CV Patching" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_patch_this" })
        table.insert(ui_params, { id = "lane_" .. lane_idx .. "_wsyn_patch_that" })
    end

    return ui_params
end

return wsyn

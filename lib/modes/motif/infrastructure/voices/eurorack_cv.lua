-- eurorack_cv.lua
-- Crow and TXO CV/Gate voice parameters for lane configuration

local eurorack_cv = {}

function eurorack_cv.create_params(i)
    params:add_binary("lane_" .. i .. "_eurorack_active", "CV/Gate Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_eurorack_active", function(value)
        if value == 1 then
            _seeker.lanes[i].eurorack_active = true
        else
            _seeker.lanes[i].eurorack_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_eurorack_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_eurorack_voice_volume", function(value)
        _seeker.lanes[i].eurorack_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_gate_out", "Gate Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
    params:add_option("lane_" .. i .. "_cv_out", "CV Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo cv 1", "txo cv 2", "txo cv 3", "txo cv 4"}, 1)
    params:add_option("lane_" .. i .. "_loop_start_trigger", "Loop Start Out",
        {"none", "crow 1", "crow 2", "crow 3", "crow 4", "txo tr 1", "txo tr 2", "txo tr 3", "txo tr 4"}, 1)
end

return eurorack_cv

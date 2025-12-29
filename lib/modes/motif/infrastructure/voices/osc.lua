-- osc.lua
-- OSC voice parameters for lane configuration

local osc_voice = {}

osc_voice.name = "OSC"

function osc_voice.create_params(i)
    params:add_binary("lane_" .. i .. "_osc_active", "OSC Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_osc_active", function(value)
        if value == 1 then
            _seeker.lanes[i].osc_active = true
        else
            _seeker.lanes[i].osc_active = false
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)
end

function osc_voice.get_ui_params(lane_idx)
    local ui_params = {}
    table.insert(ui_params, { id = "lane_" .. lane_idx .. "_osc_active" })
    return ui_params
end

return osc_voice

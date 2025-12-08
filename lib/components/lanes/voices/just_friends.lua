-- just_friends.lua
-- Just Friends voice parameters for lane configuration

local just_friends = {}

function just_friends.create_params(i)
    params:add_binary("lane_" .. i .. "_just_friends_active", "Just Friends Active", "toggle", 0)
    params:set_action("lane_" .. i .. "_just_friends_active", function(value)
        if value == 1 then
            _seeker.lanes[i].just_friends_active = true
            crow.ii.jf.mode(1)
        else
            _seeker.lanes[i].just_friends_active = false
            crow.ii.jf.mode(0)
        end

        _seeker.lane_config.screen:rebuild_params()
        _seeker.screen_ui.set_needs_redraw()
    end)

    params:add_control("lane_" .. i .. "_just_friends_voice_volume", "Voice Volume", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action("lane_" .. i .. "_just_friends_voice_volume", function(value)
        _seeker.lanes[i].just_friends_voice_volume = value
    end)

    params:add_option("lane_" .. i .. "_just_friends_voice_select", "JF Voice", {"All", "1", "2", "3", "4", "5", "6"}, 1)
    params:set_action("lane_" .. i .. "_just_friends_voice_select", function(value)
        _seeker.lanes[i].just_friends_voice_select = value
    end)
end

return just_friends

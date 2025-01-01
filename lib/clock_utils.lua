local clock_utils = {}

function clock_utils.start_clock(idx, clock_mod, callback)
    local clock_thread = clock.run(function()
        while true do
            callback(idx)
            clock.sync(clock_mod)
        end
    end)
    return clock_thread
end

function clock_utils.cancel_clock(clock_thread)
    if clock_thread then
        clock.cancel(clock_thread)
    end
end

return clock_utils
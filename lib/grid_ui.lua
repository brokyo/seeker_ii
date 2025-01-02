-- Grid UI module for Seeker II
local GridUI = {}

local g = grid.connect()

-- Constants
local BRIGHT = 15
local DIM = 4
local PULSE_LEVEL = 8
local GRID_FPS = 30
local PULSE_TIME = 0.1

-- State
local channel_pulses = {}
local pulse_metros = {}

function GridUI.init(channels)
    GridUI.channels = channels
    
    -- Connect grid key handler
    g.key = GridUI.key
    
    -- Set up grid redraw metro
    GridUI.metro = metro.init()
    GridUI.metro.time = 1/GRID_FPS
    GridUI.metro.event = GridUI.redraw
    GridUI.metro:start()
    
    -- Initialize pulse state and metros for each channel
    for i = 1, #channels do
        channel_pulses[i] = false
        -- Create a metro for this channel's pulses
        pulse_metros[i] = metro.init(function()
            channel_pulses[i] = false
            GridUI.redraw()
        end, PULSE_TIME, 1) -- one-shot metro with PULSE_TIME duration
        
        -- Add pulse callback to each channel
        channels[i]:add_pulse_callback(function(channel_id)
            channel_pulses[channel_id] = true
            pulse_metros[channel_id]:start() -- Start the one-shot metro
            GridUI.redraw()
        end)
    end
end

function GridUI.key(x, y, z)
    -- Calculate which section we're in (1-4)
    local section = math.ceil(x/4)
    
    -- Check if we're in the bottom row and within a valid section
    if y == 8 and section <= #GridUI.channels then
        -- Check if this is the leftmost key in the section
        if x == (section-1)*4 + 1 then
            if z == 1 then -- key pressed
                if GridUI.channels[section].running then
                    GridUI.channels[section]:stop_channel(section)
                else
                    GridUI.channels[section]:start(section)
                end
                -- Update main UI
                redraw()
            end
        end
    end
    
    -- Force grid redraw
    GridUI.redraw()
end

function GridUI.redraw()
    if not g then return end
    
    g:all(0) -- clear grid
    
    -- Draw start/stop buttons for each channel
    for i = 1, #GridUI.channels do
        local x = (i-1)*4 + 1 -- leftmost position in each section
        local y = 8 -- bottom row
        local brightness = GridUI.channels[i].running and 
            (channel_pulses[i] and BRIGHT or PULSE_LEVEL) or -- if running, pulse between BRIGHT and PULSE_LEVEL
            DIM -- if stopped, just DIM
        g:led(x, y, brightness)
    end
    
    g:refresh()
end

return GridUI 
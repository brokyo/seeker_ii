-- Grid UI module for Seeker II
local GridUI = {}

local g = grid.connect()
local musicutil = require("musicutil")

-- Constants
local BRIGHT = 15
local DIM = 2
local PULSE_LEVEL = 8
local OUT_OF_BOUNDS_LEVEL = 4  -- New constant for out-of-bounds flash
local GRID_FPS = 30
local PULSE_TIME = 0.1

-- Grid layout constants
local GRID_ROWS = 7
local GRID_COLS = 3
local CHANNEL_WIDTH = 4

-- State
local channel_pulses = {}
local pulse_metros = {}
local active_notes = {}  -- Tracks currently playing notes per channel
local out_of_bounds = {} -- Tracks out-of-bounds indicators per channel

-- Convert MIDI note to grid position
local function note_to_grid_pos(note, channel_id)
    local channel = GridUI.channels[channel_id]
    
    -- Get all global position modifiers
    local root = params:get("global_key") - 1
    local transpose = params:get("global_transpose") or 0
    local global_octave = params:get("global_octave") or 0
    
    -- Adjust note for global modifiers
    note = note - root - transpose - (global_octave * 12)
    
    -- Calculate octave position
    local start_octave = params:get("chord_octave_" .. channel_id)
    local note_octave = math.floor(note / 12)
    local relative_octave = note_octave - start_octave
    
    -- Get note's position within octave
    local note_in_scale = note % 12
    
    -- Get current scale
    local scale_num = params:get("global_scale")
    local scale = musicutil.SCALES[scale_num]
    
    -- Find degree in scale (1-7)
    -- This now represents theoretical position regardless of current scale
    local degree = 1
    local intervals = {
        {0},    -- 1 (root)
        {2},    -- 2
        {3,4},  -- 3 (includes both minor and major third)
        {5},    -- 4
        {6,7,8}, -- 5 (includes diminished, perfect, and augmented fifth)
        {9},    -- 6
        {10,11} -- 7
    }
    
    -- Find matching degree
    for i, possible_intervals in ipairs(intervals) do
        for _, interval in ipairs(possible_intervals) do
            if note_in_scale == interval then
                degree = i
                break
            end
        end
    end
    
    -- Check if note is in visible range
    if relative_octave < 0 or relative_octave >= GRID_COLS then
        return nil, true -- Out of bounds
    end
    
    -- Convert to grid position
    local x = (channel_id - 1) * CHANNEL_WIDTH + relative_octave + 1
    local y = GRID_ROWS - degree + 1  -- Flip Y-axis so degree 1 is at bottom
    
    return {x = x, y = y}, false
end

function GridUI.init(channels)
    GridUI.channels = channels
    
    -- Connect grid key handler
    g.key = GridUI.key
    
    -- Set up grid redraw metro
    GridUI.metro = metro.init()
    GridUI.metro.time = 1/GRID_FPS
    GridUI.metro.event = GridUI.redraw
    GridUI.metro:start()
    
    -- Initialize state for each channel
    for i = 1, #channels do
        channel_pulses[i] = false
        active_notes[i] = {}
        out_of_bounds[i] = false
        
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
        
        -- Add note callback to track playing notes
        channels[i]:add_note_callback(function(channel_id, note, is_start)
            if is_start then
                table.insert(active_notes[channel_id], note)
                local pos, is_out = note_to_grid_pos(note, channel_id)
                out_of_bounds[channel_id] = is_out
            else
                for i, n in ipairs(active_notes[channel_id]) do
                    if n == note then
                        table.remove(active_notes[channel_id], i)
                        break
                    end
                end
            end
            GridUI.redraw()
        end)
    end
end

function GridUI.key(x, y, z)
    -- Calculate which section we're in (1-4)
    local section = math.ceil(x/CHANNEL_WIDTH)
    
    -- Check if we're in the bottom row and within a valid section
    if y == 8 and section <= #GridUI.channels then
        -- Check if this is the leftmost key in the section
        if x == (section-1)*CHANNEL_WIDTH + 1 then
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
    
    -- Draw scale degree grid and active notes for each channel
    for i = 1, #GridUI.channels do
        local x_offset = (i-1) * CHANNEL_WIDTH
        
        -- Draw available scale degrees
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                g:led(x_offset + x, y, DIM)
            end
        end
        
        -- Draw active notes
        for _, note in ipairs(active_notes[i]) do
            local pos, is_out = note_to_grid_pos(note, i)
            if pos then
                g:led(pos.x, pos.y, BRIGHT)
            end
        end
        
        -- Draw out-of-bounds indicator if needed
        if out_of_bounds[i] then
            -- Flash the edge columns
            if (util.time() * 4) % 1 < 0.5 then
                for y = 1, GRID_ROWS do
                    g:led(x_offset + 1, y, OUT_OF_BOUNDS_LEVEL)
                    g:led(x_offset + GRID_COLS, y, OUT_OF_BOUNDS_LEVEL)
                end
            end
        end
        
        -- Draw start/stop button
        local x = x_offset + 1
        local y = 8
        local brightness = GridUI.channels[i].running and 
            (channel_pulses[i] and BRIGHT or PULSE_LEVEL) or
            DIM
        g:led(x, y, brightness)
    end
    
    g:refresh()
end

return GridUI 
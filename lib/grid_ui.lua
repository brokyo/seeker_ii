-- Grid UI module for Seeker II
local GridUI = {}

-- Constants for grid layout
local GRID = {
    WIDTH = 3,          -- Width of each octave section
    ROWS = 7,          -- Height of the note area (7 scale degrees)
    CONTROL_ROW = 8,   -- Bottom row for controls
    BRIGHTNESS = {
        OFF = 0,
        DIM = 4,
        BRIGHT = 15
    }
}

-- State
local g = nil  -- grid device
local current_row = 1
local grid_dirty = true
local channels_table = nil

function GridUI.init(channels)
    print("Initializing Grid UI...")
    channels_table = channels
    g = grid.connect()
    
    if g then
        print("Grid connected:", g.name, g.cols.."x"..g.rows)
        g.key = GridUI.grid_key
        
        -- Start the grid redraw clock
        clock.run(function()
            while true do
                clock.sleep(1/30)
                if grid_dirty then
                    GridUI.grid_redraw()
                    grid_dirty = false
                end
            end
        end)
        
        -- Start the beat clock
        clock.run(function()
            while true do
                clock.sync(1)  -- Sync to one beat
                -- Move to next row
                current_row = current_row % GRID.ROWS + 1
                grid_dirty = true
                print("Beat: lighting up row", current_row)
            end
        end)
    else
        print("No grid device found!")
    end
    
    return GridUI
end

-- Handle grid key press
function GridUI.grid_key(x, y, z)
    if z == 1 then  -- Key pressed
        if y == GRID.CONTROL_ROW and x == 1 and channels_table[1] then
            if channels_table[1].running then
                channels_table[1]:stop_channel(1)
            else
                channels_table[1]:start(1)
            end
            grid_dirty = true
            redraw()
        end
    end
end

-- Main grid redraw function
function GridUI.grid_redraw()
    if not g then return end
    
    g:all(0)  -- Clear grid
    
    -- Light up all positions in current row
    for x = 1, GRID.WIDTH do
        g:led(x, current_row, GRID.BRIGHTNESS.BRIGHT)
    end
    
    -- Draw start/stop button
    if channels_table[1] then
        g:led(1, GRID.CONTROL_ROW, 
            channels_table[1].running and GRID.BRIGHTNESS.BRIGHT or GRID.BRIGHTNESS.DIM)
    end
    
    g:refresh()
end

-- These functions are kept but simplified to do nothing for now
function GridUI.note_on(channel, octave, degree) end
function GridUI.note_off(channel, octave, degree) end
function GridUI.set_available_notes(channel, notes) end
function GridUI.clear_channel(channel) end

return GridUI 
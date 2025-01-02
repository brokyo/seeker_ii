-- Seeker
-- 
-- Textural generation channels
-- awakening.systems

------------------------
-- External Libraries --
------------------------
local nb = require("nb/lib/nb")
local musicutil = require("musicutil")

------------------------
-- Internal Libraries --
------------------------
local Channel = include('lib/channel')
local theory_utils = include('lib/theory_utils')
local utils = include('lib/utils')
local params_manager = include('lib/params_manager')

-----------------
-- Core Config --
-----------------
SEEKER_DEBUG = true -- For event tables and musical debugging 
SEEKER_VERBOSE = false -- For detailed event logging
local NUM_CHANNELS = 4

local channels = {}
local selected_channel = 1

function init()
    -- Initialize timing for logging
    utils.init_timing()
    
    -- Initialize N.B
    nb:init()
    
    -- Initialize channels
    init_channels(NUM_CHANNELS)
    
    -- Add global parameters
    add_global_config()
    
    -- Add N.B player parameters
    nb:add_player_params()
    
    -- Initialize UI state
    init_ui_state()
    
    -- Set up preset system
    params:add_separator("presets", "Presets")
    params:add_group("pset", "Preset Management", 2)
    params:add{
        type = "file",
        id = "pset_load",
        name = "Load Preset",
        path = _path.data .. "seeker_ii/presets",
        action = function(file) 
            params:read(file)
            utils.debug_print("Loaded preset: " .. file)
        end
    }
    params:add{
        type = "file",
        id = "pset_save", 
        name = "Save Preset",
        path = _path.data .. "seeker_ii/presets",
        action = function(file)
            params:write(file)
            utils.debug_print("Saved preset: " .. file)
        end
    }
    
    -- Create presets directory if it doesn't exist
    os.execute("mkdir -p " .. _path.data .. "seeker_ii/presets")
    
    -- Initial screen draw
    redraw()
end

-- Preset callbacks
function cleanup()
    -- Save current state as last.pset
    params:write(_path.data .. "seeker_ii/presets/last.pset")
end

function add_global_config()
    params:add_separator("seeker_app_header", "Seeker Config")
    
    -- Global Tuning Configuration
    params:add_group("Tuning", 4)
    
    -- Key selection
    params:add {
        type = "option",
        id = "global_key",
        name = "Key",
        options = theory_utils.note_names,
        default = 1,
        action = function(value)
            utils.debug_print("Global key set to " .. theory_utils.note_names[value])
            -- Regenerate notes for all channels
            for i = 1, NUM_CHANNELS do
                if channels[i] then
                    channels[i]:generate_chord_notes(i)
                end
            end
        end
    }
    
    -- Scale selection
    local scale_names = {}
    for i = 1, #musicutil.SCALES do
        table.insert(scale_names, musicutil.SCALES[i].name)
    end
    
    params:add {
        type = "option",
        id = "global_scale",
        name = "Scale",
        options = scale_names,
        default = 1,
        action = function(value)
            utils.debug_print("Global scale set to " .. scale_names[value])
            -- Regenerate notes for all channels
            for i = 1, NUM_CHANNELS do
                if channels[i] then
                    channels[i]:generate_chord_notes(i)
                end
            end
        end
    }
    
    -- Transposition (useful for quick key changes)
    params:add {
        type = "number",
        id = "global_transpose",
        name = "Transpose",
        min = -12,
        max = 12,
        default = 0,
        action = function(value)
            utils.debug_print("Global transpose set to " .. value)
            -- Regenerate notes for all channels
            for i = 1, NUM_CHANNELS do
                if channels[i] then
                    channels[i]:generate_chord_notes(i)
                end
            end
        end
    }
    
    -- Root octave offset (useful for overall register control)
    params:add {
        type = "number",
        id = "global_octave",
        name = "Octave",
        min = -2,
        max = 2,
        default = 0,
        action = function(value)
            utils.debug_print("Global octave set to " .. value)
            -- Regenerate notes for all channels
            for i = 1, NUM_CHANNELS do
                if channels[i] then
                    channels[i]:generate_chord_notes(i)
                end
            end
        end
    }
end

function init_channels(channel_count)
    -- First add all parameters for all channels
    for i = 1, channel_count do
        channels[i] = Channel.new(i)
        channels[i]:add_params(i)
    end
    
    -- Then update visibility for all channels
    for i = 1, channel_count do
        params_manager.update_behavior_visibility(i, 1)  -- 1 is the default "Pulse" behavior
    end
end

function enc(n, d)
    if n == 1 then
        -- Change selected channel
        selected_channel = util.clamp(selected_channel + d, 1, NUM_CHANNELS)
        redraw()
    end
end

function key(n, z)
    if n == 2 and z == 1 then
        -- Toggle channel state
        if channels[selected_channel].running then
            channels[selected_channel]:stop_channel(selected_channel)
        else
            channels[selected_channel]:start(selected_channel)
        end
        redraw()
    end
end

function redraw()
    screen.clear()
    
    -- Draw channel info
    screen.move(64, 32)
    screen.level(15)
    screen.text_center("Channel " .. selected_channel)
    
    -- Draw status
    screen.move(64, 42)
    screen.level(channels[selected_channel].running and 15 or 3)
    screen.text_center(channels[selected_channel].running and "Running" or "Stopped")
    
    screen.update()
end

function init_ui_state()
    -- Initialize UI state variables
    selected_channel = 1
end
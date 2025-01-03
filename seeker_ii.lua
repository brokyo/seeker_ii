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
local GridUI = include('lib/grid_ui')
local LatticeManager = include('lib/lattice_manager')

-----------------
-- Core Config --
-----------------
SEEKER_DEBUG = true -- For event tables and musical debugging 
SEEKER_VERBOSE = false -- For detailed event logging
local NUM_CHANNELS = 4

local channels = {}
local selected_channel = 1
local PSET_FILE = _path.data .. "seeker_ii/last.pset"

function init()
    -- Initialize timing for logging
    utils.init_timing()
    
    -- Run error tests if in debug mode
    if SEEKER_DEBUG then
        local test_errors = include('lib/test_errors')
        test_errors.run_tests()
    end
    
    -- Initialize N.B
    nb:init()
    
    -- Initialize lattice system BEFORE channels
    if not LatticeManager.init() then
        utils.debug_print("ERROR: Failed to initialize LatticeManager")
        return
    end
    if SEEKER_DEBUG then
        utils.debug_print("Successfully initialized LatticeManager")
    end
    
    -- Initialize channels AFTER lattice
    init_channels(NUM_CHANNELS, LatticeManager)
    
    -- Add global parameters
    add_global_config()
    
    -- Add N.B player parameters
    nb:add_player_params()
    
    -- Initialize UI state
    init_ui_state()
    
    -- Create data directory if it doesn't exist
    os.execute("mkdir -p " .. _path.data .. "seeker_ii")
    
    -- Set up auto-save
    params:add_group("seeker_ii_auto_save_group", "Auto Save", 1)
    params:add_option("seeker_ii_auto_save", "Auto Save", {"Off", "On"}, 2)
    
    -- Set up auto-save on parameter changes
    params.action_write = function(filename, name, number)
        -- Only auto-save if:
        -- 1. Auto-save is enabled
        -- 2. The current write isn't already our auto-save file
        if params:get("seeker_ii_auto_save") == 2 and filename ~= PSET_FILE then
            params:write(PSET_FILE)
            utils.debug_print("Auto-saved preset")
        end
    end
    
    -- Load last preset if it exists
    if util.file_exists(PSET_FILE) then
        params:read(PSET_FILE)
        utils.debug_print("Loaded last preset")
    end
    
    -- Initialize grid UI
    GridUI.init(channels)
    
    -- Set up clock callbacks
    clock.run(function()
        while true do
            clock.sync(1/4) -- Sync to quarter notes
            GridUI.set_pulse(true)
            clock.sleep(0.1) -- Pulse duration
            GridUI.set_pulse(false)
        end
    end)
end

-- Preset callbacks
function cleanup()
    -- Save current state as last.pset
    params:write(PSET_FILE)
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

function init_channels(channel_count, lattice_manager)
    -- First add all parameters for all channels
    for i = 1, channel_count do
        channels[i] = Channel.new(i, lattice_manager)
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
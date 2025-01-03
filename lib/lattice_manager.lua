--[[
  lattice_manager.lua
  Centralized timing control for Seeker II

  Design Philosophy:
  - Timing divisions (sprockets) are primary, shared resources
  - Channels register with divisions for timing triggers
  - Perfect sync through shared triggers
  - Clean separation of timing and behavior

  See build_plan.md for detailed architecture documentation
]]--

local lattice = require("lattice")
local utils = include("lib/utils")

local LatticeManager = {}

-- Store our lattice state
LatticeManager.main_lattice = nil
LatticeManager.division_sprockets = {}  -- Sprockets for each division
LatticeManager.channel_actions = {}     -- Actions for each channel

function LatticeManager.init()
    if SEEKER_DEBUG then
        utils.debug_print("Initializing LatticeManager")
    end
    
    if LatticeManager.main_lattice then
        if SEEKER_DEBUG then
            utils.debug_print("WARNING: Main lattice already exists, destroying old instance")
        end
        LatticeManager.main_lattice:destroy()
        LatticeManager.division_sprockets = {}
        LatticeManager.channel_actions = {}
    end
    
    -- Create new lattice with explicit sync parameters
    LatticeManager.main_lattice = lattice:new{
        auto = true,
        ppqn = 96,  -- Industry standard, gives us precise timing resolution
        meter = 4   -- Standard 4/4 time
    }
    
    if not LatticeManager.main_lattice then
        utils.debug_print("ERROR: Failed to create main lattice")
        return false
    end
    
    if SEEKER_DEBUG then
        utils.debug_print("Starting main lattice")
    end
    
    -- Start the lattice and hard restart to ensure sync
    LatticeManager.main_lattice:start()
    clock.run(function()
        clock.sleep(0.1)
        LatticeManager.main_lattice:hard_restart()
    end)
    
    if SEEKER_DEBUG then
        utils.debug_print("Main lattice created successfully with ppqn: 96")
        utils.debug_print("Main lattice started and running")
    end
    
    return true
end

function LatticeManager.set_division(channel_id, division)
    if not LatticeManager.main_lattice then
        utils.debug_print("ERROR: Main lattice not initialized")
        return
    end
    
    -- Create sprocket for this division if it doesn't exist
    if not LatticeManager.division_sprockets[division] then
        if SEEKER_DEBUG then
            utils.debug_print("Creating new sprocket for division: " .. division)
        end
        LatticeManager.division_sprockets[division] = LatticeManager.main_lattice:new_sprocket{
            action = function(t)
                -- Call all channel actions registered for this division
                for ch_id, action in pairs(LatticeManager.channel_actions) do
                    if action.division == division and action.enabled then
                        if SEEKER_DEBUG then
                            utils.debug_print("Channel " .. ch_id .. " pulse at transport: " .. t)
                        end
                        action.fn(t)
                    end
                end
            end,
            division = division,
            enabled = true  -- Always enabled, we control channels individually
        }
    end
    
    -- Update channel's division
    if LatticeManager.channel_actions[channel_id] then
        LatticeManager.channel_actions[channel_id].division = division
    end
end

function LatticeManager.start_channel(channel_id, action)
    if not LatticeManager.main_lattice then 
        utils.debug_print("ERROR: Main lattice not initialized")
        return false
    end
    
    if SEEKER_DEBUG then
        utils.debug_print("Starting Channel " .. channel_id .. " with lattice state:")
        utils.debug_print("- Main lattice enabled: " .. tostring(LatticeManager.main_lattice.enabled))
        utils.debug_print("- Transport position: " .. tostring(LatticeManager.main_lattice.transport))
    end
    
    -- Store channel action with default division
    local division = 1/4  -- default to quarter notes
    LatticeManager.channel_actions[channel_id] = {
        fn = function(t)
            if SEEKER_DEBUG then
                utils.debug_print("Channel " .. channel_id .. " pulse triggered")
            end
            action(t)
        end,
        division = division,
        enabled = true
    }
    
    -- Ensure sprocket exists for this division
    if not LatticeManager.division_sprockets[division] then
        LatticeManager.set_division(channel_id, division)
    end
    
    if SEEKER_DEBUG then
        utils.debug_print("Channel " .. channel_id .. " registered for division: " .. division)
    end
    
    return true
end

function LatticeManager.stop_channel(channel_id)
    if LatticeManager.channel_actions[channel_id] then
        LatticeManager.channel_actions[channel_id].enabled = false
        if SEEKER_DEBUG then
            utils.debug_print("Stopped channel " .. channel_id)
        end
    end
end

function LatticeManager.cleanup()
    if LatticeManager.main_lattice then
        if SEEKER_DEBUG then
            utils.debug_print("Cleaning up LatticeManager")
        end
        LatticeManager.main_lattice:destroy()
        LatticeManager.division_sprockets = {}
        LatticeManager.channel_actions = {}
    end
end

return LatticeManager 
-- sync_manager.lua
-- Centralized global synchronization manager

local SyncManager = {}
SyncManager.__index = SyncManager

-- Global synchronization function that handles all sync operations
function SyncManager.sync_all()
    clock.run(function()
        -- Cancel all existing Eurorack clocks
        if _seeker and _seeker.eurorack_output then
            for output_id, clock_id in pairs(_seeker.eurorack_output.active_clocks or {}) do
                if clock_id then
                    clock.cancel(clock_id)
                    _seeker.eurorack_output.active_clocks[output_id] = nil
                end
            end
        end
        
        -- Cancel all OSC clocks
        if _seeker and _seeker.osc_config then
            -- Cancel OSC trigger clocks
            for trigger_id, clock_id in pairs(_seeker.osc_config.active_trigger_clocks or {}) do
                if clock_id then
                    clock.cancel(clock_id)
                end
            end
            _seeker.osc_config.active_trigger_clocks = {}
            
            -- Cancel OSC LFO sync clocks
            for lfo_id, clock_id in pairs(_seeker.osc_config.active_lfo_sync_clocks or {}) do
                if clock_id then
                    clock.cancel(clock_id)
                end
            end
            _seeker.osc_config.active_lfo_sync_clocks = {}
        end
        
        -- Reset all Eurorack outputs
        for i = 1, 4 do
            crow.output[i].volts = 0
            crow.ii.txo.tr(i, 0)
            crow.ii.txo.cv(i, 0)
        end
        
        -- Sync to next whole beat
        local current_beat = math.floor(clock.get_beats())
        local next_beat = current_beat + 1
        local beats_to_wait = next_beat - clock.get_beats()
        clock.sync(beats_to_wait)
        
        -- Start all Eurorack clocks fresh
        if _seeker and _seeker.eurorack_output then
            for i = 1, 4 do
                _seeker.eurorack_output.update_crow(i)
                _seeker.eurorack_output.update_txo_tr(i)
                _seeker.eurorack_output.update_txo_cv(i)
            end
        end
        
        -- Restart all OSC clocks
        if _seeker and _seeker.osc_config then
            -- Restart trigger clocks
            for i = 1, 4 do
                _seeker.osc_config.update_trigger_clock(i)
            end
            
            -- Restart LFO sync clocks
            for i = 1, 4 do
                _seeker.osc_config.send_lfo_frequency(i)
            end
        end
        
        -- Sync all lanes to start of first stage
        if _seeker and _seeker.conductor then
            _seeker.conductor.sync_lanes()
        end
        
        print("⚡ Global synchronization complete")
    end)
end

function SyncManager.init()
    return {
        sync_all = SyncManager.sync_all
    }
end

return SyncManager 
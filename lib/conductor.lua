-- conductor.lua
-- Conductor is an event processor that enables easy global scheduling.
-- The timeline that runs underneath the application. Lanes insert events. Conductor emits them.
local Conductor = {}

Conductor.events = {}

-- Insert an event into the queue, sorted by time
function Conductor.insert_event(evt)
  table.insert(Conductor.events, evt)
  table.sort(Conductor.events, function(a, b)
    return a.time < b.time
  end)
end

function Conductor.process_events()
  if #Conductor.events > 0 then
    local now = clock.get_beats()
    local next_evt = Conductor.events[1]
    local wait_beats = next_evt.time - now
    
    -- If event is in the future, wait for next check
    if wait_beats > 0 then
      return
    end
    
    -- Event is due now or overdue, execute it
    table.remove(Conductor.events, 1)
    if next_evt.callback then
      next_evt.callback(next_evt)
    end
  end
end

function Conductor.clear_events()
  Conductor.events = {}
end

-- Synchronize all lanes by stopping and restarting them
function Conductor.sync_lanes()
  -- Stop all lanes
  for _, lane in pairs(_seeker.lanes) do
    lane:stop()
  end
  
  -- Clear all past events
  Conductor.clear_events()
  
  -- Schedule restart at next beat
  local next_beat = math.ceil(clock.get_beats())
  Conductor.insert_event({
    time = next_beat,
    callback = function()
      for _, lane in pairs(_seeker.lanes) do
        lane:play()
      end
    end
  })
end

-- Debug function to print all scheduled events
function Conductor.print_events()
  print("\n=== Conductor Events ===")
  if #Conductor.events == 0 then
    print("No events scheduled")
    return
  end
  
  local now = clock.get_beats()
  for i, evt in ipairs(Conductor.events) do
    local time_delta = evt.time - now
    print(string.format("[%d] Time: %.2f (%.2f beats from now)", 
      i, evt.time, time_delta))
  end
  print("=====================\n")
end

return Conductor

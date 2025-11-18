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

-- Clear all events for a specific lane
function Conductor.clear_events_for_lane(lane_id)
  -- Get the lane's currently active notes
  local lane = _seeker.lanes[lane_id]
  local active_notes = lane.active_notes

  -- First pass: execute note_off events only for currently active notes
  for _, evt in ipairs(Conductor.events) do
    if evt.lane_id == lane_id and evt.type == "note_off" and evt.callback then
      -- Check if this note_off is for a currently active note
      local note = evt.note or evt.original_note -- Try both since the event might store it differently
      if active_notes[note] then
        evt.callback(evt)
      end
    end
  end

  -- Second pass: remove all events for this lane
  local i = 1
  while i <= #Conductor.events do
    local evt = Conductor.events[i]
    if evt.lane_id == lane_id then
      table.remove(Conductor.events, i)
    else
      i = i + 1
    end
  end
end

-- Clear all events from the conductor's event queue
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

-- Synchronize all timed outputs (lanes + eurorack outputs)
function Conductor.sync_all()
  clock.run(function()
    -- Calculate next whole beat
    local current_beat = math.floor(clock.get_beats())
    local next_beat = current_beat + 1
    local beats_to_wait = next_beat - clock.get_beats()

    -- Reset all eurorack outputs
    for i = 1, 4 do
      crow.output[i].volts = 0
      crow.ii.txo.tr(i, 0)
      crow.ii.txo.cv(i, 0)
    end

    -- Sync each component that has a sync method
    if _seeker.crow_output and _seeker.crow_output.sync then
      _seeker.crow_output.sync()
    end
    if _seeker.txo_tr_output and _seeker.txo_tr_output.sync then
      _seeker.txo_tr_output.sync()
    end
    if _seeker.txo_cv_output and _seeker.txo_cv_output.sync then
      _seeker.txo_cv_output.sync()
    end

    -- Wait for next beat
    clock.sync(beats_to_wait)

    -- Sync all lanes
    Conductor.sync_lanes()
  end)
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

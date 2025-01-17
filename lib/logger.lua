-- logger.lua
-- Logging system following the Norns Application Logging Specification

local Logger = {}

-- Configuration defaults
Logger.config = {
  suppress = {
    music = false,
    flow = false,
    status = false,
    debug = false,
    playback = false  -- New category for play/loop events
  },
  detail_level = {
    music = 2,    -- 1: Basic notes only
                  -- 2: + context
                  -- 3: + all attributes
    flow = 1,     -- 1: Basic flow
                  -- 2: + data details
    status = 1,   -- 1: Basic status
                  -- 2: + context
    debug = 1,    -- 1: Messages only
                  -- 2: + stack traces
    playback = 2  -- 1: Loop starts only
                  -- 2: + Note events
                  -- 3: + Detailed timing
  }
}

Logger.style = {
  use_decorations = true,
  color_enabled = true,
  compact_mode = false
}

-- Get source location for all logs
local function get_source_location()
  local info = debug.getinfo(3, "Sl")
  -- Extract just the filename from the path
  local filename = string.match(info.short_src, "[^/]+$")
  return string.format("%s:%d", filename, info.currentline)
end

-- Rate limiting support
local last_time = {}
function Logger.rate_limited(key, interval, fn)
  local now = os.time()
  if not last_time[key] or (now - last_time[key] > interval) then
    last_time[key] = now
    fn()
  end
end

-- Helper function for safe table printing
local function table_to_string(tbl, indent)
  indent = indent or "   "
  local str = ""
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      str = str .. string.format("\n%s%s: <table>", indent, k)
    else
      str = str .. string.format("\n%s%s: %s", indent, k, tostring(v))
    end
  end
  return str
end

-- Helper function for compact event formatting
local function format_compact_event(data)
  local parts = {}
  -- Put event type first and format distinctly
  if data.event then
    table.insert(parts, string.format("[evt:%s]", data.event:gsub("grid_", "")))
    data.event = nil  -- Remove so it's not printed again
  end
  
  for k, v in pairs(data) do
    if type(v) == "table" then
      -- Format position as x,y
      if k == "position" and v.x and v.y then
        -- Make sure x and y are numbers
        local x = tonumber(v.x) or 0
        local y = tonumber(v.y) or 0
        table.insert(parts, string.format("pos:%d,%d", x, y))
      else
        table.insert(parts, string.format("%s:<table>", k))
      end
    else
      -- Convert nil to "nil" string
      local val = v ~= nil and tostring(v) or "nil"
      table.insert(parts, string.format("%s:%s", k, val))
    end
  end
  return table.concat(parts, " ")
end

-- Musical event logging (for note events)
function Logger.music(data, decorator)
  if Logger.config.suppress.music then return end
  
  local location = get_source_location()
  
  -- For note events, use compact technical format
  if data.event and (data.event:match("note_on") or data.event:match("note_off")) then
    if Logger.config.detail_level.music >= 2 then
      -- Format: [TECH:NOTE] operation @ source | n=60 v=100 b=0.00 pos=8,7 t=0.00 d=0.00
      local parts = {}
      for k, v in pairs(data) do
        if k ~= "event" then  -- Skip event since it's in the prefix
          table.insert(parts, string.format("%s=%s", k, tostring(v)))
        end
      end
      
      local msg = string.format("[TECH:NOTE] %s @ %s | %s",
        data.event,
        location,
        table.concat(parts, " ")
      )
      print(msg)
    end
    return
  end
  
  -- For complex events, use multi-line format
  local msg = string.format("[TECH] %s @ %s", 
    data.event,
    location
  )
  
  if Logger.config.detail_level.music >= 2 then
    msg = msg .. table_to_string(data)
  end
  
  print(msg)
end

-- Status event logging
function Logger.status(data, decorator)
  if Logger.config.suppress.status then return end
  
  local location = get_source_location()
  
  -- Format: [source] ▓▓ Message ▓▓
  local msg = string.format("[%s] ▓▓ %s ▓▓", 
    location,
    format_compact_event(data)
  )
  print(msg)
end

-- Debug event logging (for motif dumps)
function Logger.debug(data, decorator)
  if Logger.config.suppress.debug then return end
  
  if type(data) == "table" and data.motif then
    local events = data.motif
    -- Use block style with headers
    print("▓▓▓▓▓▓▓▓▓▓▓▓▓ MOTIF RECORDED ▓▓▓▓▓▓▓▓▓▓▓▓▓")
    print(string.format("Events: %d", #events))
    print("  #  Beat   Note  Vel   Dur    Pos")
    print("----------------------------------------")
    
    for i, evt in ipairs(events) do
      print(string.format("%3d  %.2f  %3d   %3d   %.2f   %d,%d",
        i,
        evt.time,
        evt.pitch,
        evt.velocity,
        evt.duration,
        evt.pos.x or 0,
        evt.pos.y or 0
      ))
    end
    print("▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓")
    return
  end
end

-- Data flow event logging
function Logger.flow(data, decorator)
  if Logger.config.suppress.flow then return end
  
  local location = get_source_location()
  local msg = string.format("⟿ %s %s", 
    decorator or "---",
    location
  )
  
  if Logger.config.detail_level.flow >= 2 then
    msg = msg .. "\n   " .. tab.print(data)
  end
  
  print(msg)
end

-- Add new playback logging function
function Logger.playback(data, decorator)
  if Logger.config.suppress.playback then return end
  
  local location = get_source_location()
  local absolute_beat = clock.get_beats()
  
  if data.event == "motif_note_played" and Logger.config.detail_level.playback >= 2 then
    print(string.format("[PLAY] @%.3f note=%d vel=%d time=%.2f dur=%.2f @ %s",
      absolute_beat,
      data.n,
      data.v,
      data.t,
      data.d,
      location
    ))
  elseif data.event == "loop_started" then
    print(string.format("[LOOP START] @%.3f loop=%d/%d quantum=%.3f @ %s",
      absolute_beat,
      data.loop,
      data.max_loops or 0,
      data.quantum or 0,
      location
    ))
  elseif data.event == "motif_loop_complete" then
    print("DEBUG - start_beat type:", type(data.start_beat), "value:", data.start_beat)
    print(string.format("[LOOP END] @%.3f loop=%d/%d duration=%.3f @ %s",
      absolute_beat,
      data.loop,
      data.max_loops,
      absolute_beat - data.start_beat,
      location
    ))
  end
end

return Logger

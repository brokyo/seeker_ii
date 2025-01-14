-- logger.lua
-- Logging system following the Norns Application Logging Specification

local Logger = {}

-- Toggle debug prints
local DEBUG = true

-- Basic logging with type decoration
function Logger.log(msg)
  if DEBUG then
    print("[SEEKER] "..tostring(msg))
  end
end

-- Musical event logging
function Logger.music(event_type, data)
  if not DEBUG then return end
  
  local decorators = {
    note = "▽△▽",
    pattern = "═══",
    chord = "║║║",
    transform = "◆◇◆"
  }
  
  local decorator = decorators[event_type] or "♪ ---"
  local source = debug.getinfo(2, "Sl")
  local location = string.format("[%s:%d]", source.short_src, source.currentline)
  
  -- Format all data in a single line with source at the end
  local context_str = ""
  if data.context then
    context_str = " → " .. table.concat(data.context, " | ")
  end
  
  print(string.format("♪ %s %s%s | %s", decorator, data.message, context_str, location))
end

return Logger

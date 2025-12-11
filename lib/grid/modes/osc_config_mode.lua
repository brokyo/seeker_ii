-- osc_config_mode.lua
-- Full-page grid mode for OSC configuration
-- Mode button at (14, 2) provides virtual navigation (handled by ModeSwitcher)

local OscConfigMode = {}

function OscConfigMode.draw_full_page(layers)
  -- Draw OSC type selector grid (3 rows of 4 buttons)
  _seeker.osc.float.grid:draw(layers)     -- Row y=5
  _seeker.osc.lfo.grid:draw(layers)       -- Row y=6
  _seeker.osc.trigger.grid:draw(layers)   -- Row y=7
end

function OscConfigMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Check each OSC component's grid region
  if _seeker.osc.float.grid:contains(x, y) then
    _seeker.osc.float.grid:handle_key(x, y, z)
  elseif _seeker.osc.lfo.grid:contains(x, y) then
    _seeker.osc.lfo.grid:handle_key(x, y, z)
  elseif _seeker.osc.trigger.grid:contains(x, y) then
    _seeker.osc.trigger.grid:handle_key(x, y, z)
  end

  return true
end

return OscConfigMode

-- osc_config_mode.lua
-- Full-page grid mode for OSC configuration
-- Orchestrates OSC-specific regions

local OscSelector = include("lib/grid/regions/osc/osc_selector")

local OscConfigMode = {}

-- Draw all OSC config mode elements
function OscConfigMode.draw_full_page(layers)
  -- Draw OSC selector grid
  OscSelector.draw(layers)
end

-- Handle all OSC config mode input
function OscConfigMode.handle_full_page_key(x, y, z)
  -- Register activity for any interaction
  _seeker.ui_state.register_activity()

  -- Check OSC selector region
  if OscSelector.contains(x, y) then
    return OscSelector.handle_key(x, y, z)
  end

  return false
end

return OscConfigMode

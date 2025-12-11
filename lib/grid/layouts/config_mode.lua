-- config_mode.lua
-- Full-page grid mode for Config - shows only config button, no keyboard UI

local ConfigMode = {}

function ConfigMode.draw_full_page(layers)
  -- Draw only the config button itself
  _seeker.config.grid:draw(layers)
end

function ConfigMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Only handle config button
  if _seeker.config.grid:contains(x, y) then
    _seeker.config.grid:handle_key(x, y, z)
  end

  return true
end

return ConfigMode

-- form_mode.lua
-- Full-page grid layout for form mode.
-- The form grid handles lane buttons + per-lane stages (rows 4-7, cols 1-9).

local FormMode = {}

function FormMode.draw_full_page(layers)
  _seeker.form_mode.form.grid:draw(layers)
end

function FormMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  if _seeker.form_mode.form.grid:contains(x, y) then
    _seeker.form_mode.form.grid:handle_key(x, y, z)
  end

  return true
end

return FormMode

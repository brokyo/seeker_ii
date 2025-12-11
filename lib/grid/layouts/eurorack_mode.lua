-- eurorack_mode.lua
-- Full-page grid mode for Eurorack output configuration
-- Orchestrates crow_output, txo_tr_output, txo_cv_output components

local EurorackMode = {}

function EurorackMode.draw_full_page(layers)
  -- Draw all three component grid selectors
  _seeker.eurorack.crow_output.grid:draw(layers)
  _seeker.eurorack.txo_tr_output.grid:draw(layers)
  _seeker.eurorack.txo_cv_output.grid:draw(layers)
end

function EurorackMode.handle_full_page_key(x, y, z)
  _seeker.ui_state.register_activity()

  -- Route to appropriate component based on grid position
  if _seeker.eurorack.crow_output.grid:contains(x, y) then
    _seeker.eurorack.crow_output.grid:handle_key(x, y, z)
  elseif _seeker.eurorack.txo_tr_output.grid:contains(x, y) then
    _seeker.eurorack.txo_tr_output.grid:handle_key(x, y, z)
  elseif _seeker.eurorack.txo_cv_output.grid:contains(x, y) then
    _seeker.eurorack.txo_cv_output.grid:handle_key(x, y, z)
  end

  return true
end

return EurorackMode

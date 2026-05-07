-- rc_overlay.lua
-- Displays a temporary full-screen parameter editor.
-- Shows specified params; user adjusts via encoders and arc. K3 dismisses.

local NornsUI = include('lib/ui/base/norns_ui')

local rc_overlay = {}
local overlay_ui = nil          -- Active overlay NornsUI, nil when dismissed
local previous_section_id = nil -- Section ID to restore on dismiss

function rc_overlay.show(param_list)
  -- Only save restore target on first show (not when re-showing with new params)
  local already_showing = _seeker.ui_state.get_current_section() == "RC_OVERLAY"
  if not already_showing then
    previous_section_id = _seeker.ui_state.get_current_section()
  end

  -- Build a fresh NornsUI section with the given params
  overlay_ui = NornsUI.new({
    id = "RC_OVERLAY",
    name = "RC",
    icon = "~",
    params = param_list,
  })

  -- K3 dismisses the overlay, returning to previous screen
  overlay_ui.on_key = function(n, z)
    if n == 3 and z == 1 then
      rc_overlay.dismiss()
      return true
    end
    return false
  end

  -- Register and switch to overlay section
  _seeker.screen_ui.sections["RC_OVERLAY"] = overlay_ui
  if already_showing then
    -- Re-show: enter() manually since set_current_section short-circuits on same ID
    overlay_ui:enter()
    _seeker.screen_ui.set_needs_redraw()
  else
    _seeker.ui_state.set_current_section("RC_OVERLAY")
  end
end

function rc_overlay.dismiss()
  if previous_section_id then
    _seeker.ui_state.set_current_section(previous_section_id)
    previous_section_id = nil
  end
  _seeker.screen_ui.sections["RC_OVERLAY"] = nil
  overlay_ui = nil
end

return rc_overlay

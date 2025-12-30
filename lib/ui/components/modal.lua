-- modal.lua
-- Modal overlay system - routes to specialized modal implementations

local Description = include("lib/ui/components/modals/description")
local Status = include("lib/ui/components/modals/status")
local Warning = include("lib/ui/components/modals/warning")
local Recording = include("lib/ui/components/modals/recording")
local ADSR = include("lib/ui/components/modals/adsr")
local Waveform = include("lib/ui/components/modals/waveform")

local Modal = {}

-- Modal types
Modal.TYPE = {
  DESCRIPTION = "description",
  STATUS = "status",
  RECORDING = "recording",
  ADSR = "adsr",
  WARNING = "warning",
  WAVEFORM = "waveform"
}

-- Shared state
local state = {
  active = false,
  modal_type = nil,
  on_key = nil,
  on_enc = nil
}

-- Returns the handler module for the currently active modal type
local function get_modal_handler()
  if state.modal_type == Modal.TYPE.DESCRIPTION then return Description
  elseif state.modal_type == Modal.TYPE.STATUS then return Status
  elseif state.modal_type == Modal.TYPE.WARNING then return Warning
  elseif state.modal_type == Modal.TYPE.RECORDING then return Recording
  elseif state.modal_type == Modal.TYPE.ADSR then return ADSR
  elseif state.modal_type == Modal.TYPE.WAVEFORM then return Waveform
  end
  return nil
end

----------------------------------------
-- Show functions
----------------------------------------

function Modal.show_description(config)
  state.active = true
  state.modal_type = Modal.TYPE.DESCRIPTION
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  Description.show(state, config)
end

function Modal.show_status(config)
  state.active = true
  state.modal_type = Modal.TYPE.STATUS
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  Status.show(state, config)
end

-- Brief auto-dismissing status message (toast notification)
-- config.body: message text
-- config.duration: seconds before auto-dismiss (default 0.75)
function Modal.show_toast(config)
  -- Cancel any existing toast timer
  if state.toast_clock then
    clock.cancel(state.toast_clock)
    state.toast_clock = nil
  end

  state.active = true
  state.modal_type = Modal.TYPE.STATUS
  state.on_key = nil
  state.on_enc = nil
  Status.show(state, config)

  -- Auto-dismiss after duration
  local duration = config.duration or 0.75
  state.toast_clock = clock.run(function()
    clock.sleep(duration)
    -- Only dismiss if still showing this toast (not replaced by another modal)
    if state.active and state.modal_type == Modal.TYPE.STATUS then
      Modal.dismiss()
      if _seeker and _seeker.screen_ui then
        _seeker.screen_ui.set_needs_redraw()
      end
    end
    state.toast_clock = nil
  end)
end

function Modal.show_warning(config)
  state.active = true
  state.modal_type = Modal.TYPE.WARNING
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  Warning.show(state, config, Modal.dismiss)
end

function Modal.show_recording(config)
  state.active = true
  state.modal_type = Modal.TYPE.RECORDING
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  Recording.show(state, config)
end

function Modal.show_adsr(config)
  state.active = true
  state.modal_type = Modal.TYPE.ADSR
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  ADSR.show(state, config)
end

function Modal.show_waveform(config)
  state.active = true
  state.modal_type = Modal.TYPE.WAVEFORM
  state.on_key = config.on_key
  state.on_enc = config.on_enc
  Waveform.show(state, config)
end

----------------------------------------
-- Core functions
----------------------------------------

function Modal.dismiss()
  local impl = get_modal_handler()
  if impl and impl.cleanup then
    impl.cleanup(state)
  end

  state.active = false
  state.modal_type = nil
  state.on_key = nil
  state.on_enc = nil

  -- Restore arc to default param display
  if _seeker and _seeker.arc then
    _seeker.arc.clear_display()
  end
end

function Modal.is_active()
  return state.active
end

function Modal.get_type()
  return state.modal_type
end

function Modal.draw()
  if not state.active then return end

  local impl = get_modal_handler()
  if impl and impl.draw then
    impl.draw(state)
  end
end

----------------------------------------
-- Input handling
----------------------------------------

function Modal.handle_key(n, z)
  if not state.active then return false end

  -- Custom callback first
  if state.on_key then
    local handled = state.on_key(n, z)
    if handled then return true end
  end

  -- Modal-specific handling
  local impl = get_modal_handler()
  if impl and impl.handle_key then
    local handled = impl.handle_key(state, n, z)
    if handled then return true end
  end

  -- K2 or K3 press dismisses description/adsr/waveform modals
  if (n == 2 or n == 3) and z == 1 then
    if state.modal_type == Modal.TYPE.DESCRIPTION or
       state.modal_type == Modal.TYPE.ADSR or
       state.modal_type == Modal.TYPE.WAVEFORM then
      Modal.dismiss()
      return true
    end
  end

  return false
end

function Modal.handle_enc(n, d, source)
  if not state.active then return false end

  source = source or "norns"

  -- Custom callback first
  if state.on_enc then
    local handled = state.on_enc(n, d, source)
    if handled then return true end
  end

  -- Modal-specific handling
  local impl = get_modal_handler()
  if impl and impl.handle_enc then
    return impl.handle_enc(state, n, d, source)
  end

  return false
end

----------------------------------------
-- Type-specific accessors
----------------------------------------

-- ADSR accessors (for Arc display)
function Modal.get_adsr_selected()
  return ADSR.get_selected(state)
end

function Modal.set_adsr_selected(idx)
  ADSR.set_selected(state, idx)
end

function Modal.get_adsr_data()
  return ADSR.get_data(state)
end

function Modal.get_adsr_param_ids()
  return ADSR.get_param_ids(state)
end

-- Waveform accessors (for Arc display and chop updates)
function Modal.get_waveform_selected()
  return Waveform.get_selected(state)
end

function Modal.set_waveform_selected(idx)
  Waveform.set_selected(state, idx)
end

function Modal.get_waveform_positions()
  return Waveform.get_positions(state)
end

function Modal.adjust_waveform_selected(step_type, delta)
  Waveform.adjust_selected(state, step_type, delta)
end

function Modal.update_waveform_chop(config)
  if state.modal_type ~= Modal.TYPE.WAVEFORM then return end
  Waveform.update_chop(state, config)
end

-- Status immediate draw (no state management)
function Modal.draw_status_immediate(config)
  Status.draw_immediate(config)
end

return Modal

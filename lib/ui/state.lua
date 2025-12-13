-- state.lua
local GridModeRegistry = include("lib/grid/mode_registry")

local UIState = {}

-- Initial state
UIState.state = {
  focused_lane = 1,
  focused_stage = 1,
  current_section = "LANE",
  last_action_time = util.time(),
  long_press_in_progress = false,
  long_press_section = nil,
  recently_triggered = {},
  trigger_clocks = {},
  knob_recording_active = false
}

-- Constants
UIState.TRIGGER_VISUAL_DURATION = 0.5 -- Duration in seconds to show trigger feedback

-- Encoder smoothing for DIY norns with noisy encoders (Shield Encoder Fix)
-- Sum deltas over a window (magnitude matters), emit ±1 based on net direction
local ENC_ACCUM_WINDOW = 0.05  -- 50ms accumulation window

local function filter_enc_bounce(enc_num, delta)
  -- Check if Shield Encoder Fix is enabled (params may not exist during early init)
  local fix_enabled = params and params.lookup["shield_encoder_fix"] and params:get("shield_encoder_fix") == 1
  if not fix_enabled then
    return delta  -- Pass through unfiltered
  end

  local now = util.time()

  -- Initialize accumulator state
  UIState.state.enc_accum = UIState.state.enc_accum or {0, 0, 0}
  UIState.state.enc_accum_start = UIState.state.enc_accum_start or {0, 0, 0}

  -- Start window if not running
  if UIState.state.enc_accum_start[enc_num] == 0 then
    UIState.state.enc_accum_start[enc_num] = now
  end

  -- Accumulate delta (magnitude weighted)
  UIState.state.enc_accum[enc_num] = UIState.state.enc_accum[enc_num] + delta

  -- Check if window has closed
  local elapsed = now - UIState.state.enc_accum_start[enc_num]
  if elapsed >= ENC_ACCUM_WINDOW then
    local sum = UIState.state.enc_accum[enc_num]

    -- Reset for next window
    UIState.state.enc_accum[enc_num] = 0
    UIState.state.enc_accum_start[enc_num] = 0

    -- Emit ±1 based on sign of sum (capped to avoid jumps)
    if sum > 0 then
      return 1
    elseif sum < 0 then
      return -1
    end
    -- Zero sum = no movement
  end

  return nil  -- Suppress until window completes
end

function UIState.init()
  print("⎍ UI state tracking")
  return UIState
end

-- Methods for global trigger state tracking
function UIState.trigger_activated(param_id)
  -- Cancel any existing cleanup clock for this parameter
  if UIState.state.trigger_clocks[param_id] then
    clock.cancel(UIState.state.trigger_clocks[param_id])
  end
  
  -- Record activation time
  UIState.state.recently_triggered[param_id] = util.time()
  
  -- Schedule cleanup at exact expiration time
  UIState.state.trigger_clocks[param_id] = clock.run(function()
    -- Sleep exactly the visual duration
    clock.sleep(UIState.TRIGGER_VISUAL_DURATION)
    
    -- Remove the trigger state
    UIState.state.recently_triggered[param_id] = nil
    UIState.state.trigger_clocks[param_id] = nil
    
    -- Request redraw if available
    if _seeker and _seeker.screen_ui then
      _seeker.screen_ui.set_needs_redraw()
    end
  end)
  
  -- Request immediate redraw to show the activated trigger
  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
  
  -- Trigger arc animation if arc is available
  if _seeker and _seeker.arc and _seeker.arc.animate_trigger then
    _seeker.arc.animate_trigger(param_id)
  end
end

function UIState.is_recently_triggered(param_id)
  return UIState.state.recently_triggered[param_id] ~= nil
end

function UIState.set_focused_lane(lane_idx)
  if lane_idx == UIState.state.focused_lane then return end
  
  UIState.state.focused_lane = lane_idx
  
  -- Update UI
  if _seeker.screen_ui.sections.LANE_CONFIG and _seeker.screen_ui.sections.LANE_CONFIG.rebuild_params then
    _seeker.screen_ui.sections.LANE_CONFIG:rebuild_params()
  end

  -- Rebuild tape_create screen to show/hide duration based on new lane's motif state
  if _seeker.tape and _seeker.tape.create and _seeker.tape.create.screen then
    _seeker.tape.create.screen:rebuild_params()
  end
  
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_focused_stage(stage_idx)
  if stage_idx == UIState.state.focused_stage then return end
  
  UIState.state.focused_stage = stage_idx
  
  -- Update UI
  if _seeker.screen_ui.sections.STAGE then
    _seeker.screen_ui.sections.STAGE:update_focused_stage(stage_idx)
  end
  _seeker.screen_ui.set_needs_redraw()
  
  -- Update grid
  _seeker.grid_ui.redraw()
end

function UIState.set_current_section(section_id)
  if section_id == UIState.state.current_section then return end

  -- Stop active recording when leaving lane config section
  if UIState.state.current_section == "LANE_CONFIG" and _seeker.sampler and _seeker.sampler.is_recording then
    local lane = UIState.get_focused_lane()
    _seeker.sampler.stop_recording(lane)
    print("≋ Sampler: Recording stopped (navigation)")
  end

  -- Validate and auto-switch mode if needed
  if _seeker.current_mode then
    local required_mode = GridModeRegistry.get_mode_for_section(section_id)

    if required_mode and required_mode ~= _seeker.current_mode then
      print("⚠ Auto-switching mode: " .. _seeker.current_mode .. " → " .. required_mode .. " (section: " .. section_id .. ")")
      _seeker.current_mode = required_mode
    elseif not required_mode then
      print("⚠ Warning: Section '" .. section_id .. "' not registered in any mode")
    end
  end

  -- Exit old section
  local old_section = _seeker.screen_ui.sections[UIState.state.current_section]
  if old_section then
    old_section:exit()
  end

  UIState.state.current_section = section_id

  -- Enter new section
  local new_section = _seeker.screen_ui.sections[section_id]
  if new_section then
    new_section:enter()
  end

  if _seeker and _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

function UIState.get_focused_lane()
  return UIState.state.focused_lane
end

function UIState.get_focused_stage()
  return UIState.state.focused_stage
end

function UIState.get_current_section()
  return UIState.state.current_section
end

function UIState.register_activity()
  UIState.state.last_action_time = util.time()
end

function UIState.key(n, z)
  UIState.register_activity()

  -- Handle global controls first
  if n == 1 and z == 1 then
    -- Toggle app visibility
    if _seeker.screen_ui then
      _seeker.screen_ui.state.app_on_screen = not _seeker.screen_ui.state.app_on_screen
      return
    end
  end

  -- Pass to screen UI if visible
  if _seeker.screen_ui and _seeker.screen_ui.state.app_on_screen then
    _seeker.screen_ui.key(n, z)
  end
end

function UIState.enc(n, d)
  UIState.register_activity()

  -- Filter encoder bounce on DIY norns
  local filtered = filter_enc_bounce(n, d)
  if not filtered then return end

  -- Pass to screen UI (Modal routing happens inside norns_ui.handle_enc_default)
  if _seeker.screen_ui and _seeker.screen_ui.state.app_on_screen then
    _seeker.screen_ui.enc(n, filtered)
  end
end

-- Add new methods for long press tracking
function UIState.set_long_press_state(is_active, section_id)
  UIState.state.long_press_in_progress = is_active
  UIState.state.long_press_section = section_id
  _seeker.screen_ui.set_needs_redraw()
end

function UIState.is_long_press_active()
  return UIState.state.long_press_in_progress
end

function UIState.get_long_press_section()
  return UIState.state.long_press_section
end

return UIState 
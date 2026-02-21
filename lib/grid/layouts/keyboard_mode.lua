-- keyboard_mode.lua
-- Full-page grid mode for motif creation and performance.
-- Sub-mode buttons at (15,3) and (16,3) switch between Tape and Wheel layouts.
-- Tape: keyboard + type-specific components + lane config.
-- Wheel: lane selector + cycling chord stage controls.

local GridAnimations = include("lib/grid/animations")
local GridConstants = include("lib/grid/constants")
local type_registry = include("lib/modes/motif/type_registry")
local WheelLayout = include("lib/grid/layouts/cycling_mode")

local KeyboardMode = {}

-- Sub-mode stored on _seeker so mode_switcher can read it.
-- "tape" = keyboard layout, "wheel" = cycling chord layout.
local function get_sub_mode()
  return _seeker.motif_sub_mode or "tape"
end

local function set_sub_mode(mode)
  _seeker.motif_sub_mode = mode
end

-- Draw sub-mode selector buttons at (15,3) and (16,3)
local function draw_sub_mode_buttons(layers)
  local sm = get_sub_mode()
  local tape_brightness = sm == "tape"
    and GridConstants.BRIGHTNESS.UI.FOCUSED
    or GridConstants.BRIGHTNESS.UI.NORMAL
  local wheel_brightness = sm == "wheel"
    and GridConstants.BRIGHTNESS.UI.FOCUSED
    or GridConstants.BRIGHTNESS.UI.NORMAL

  layers.ui[15][3] = tape_brightness
  layers.ui[16][3] = wheel_brightness
end

-- Handle sub-mode button press. Returns true if consumed.
local function handle_sub_mode_key(x, y, z)
  if z ~= 1 then return false end
  if y ~= 3 then return false end

  if x == 15 then
    set_sub_mode("tape")
    _seeker.ui_state.set_current_section("LANE_CONFIG")
    return true
  elseif x == 16 then
    set_sub_mode("wheel")
    _seeker.ui_state.set_current_section("CYCLING_LIVE")
    return true
  end

  return false
end

-- Draw all keyboard mode elements
function KeyboardMode.draw_full_page(layers)
  draw_sub_mode_buttons(layers)

  if get_sub_mode() == "wheel" then
    WheelLayout.draw_full_page(layers)
    return
  end

  -- Tape sub-mode: keyboard + type-specific components
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local current_type = type_registry.get_current()

  if current_type then
    current_type.draw(layers)
  end

  -- Shared infrastructure (skip when type declares fullscreen)
  local is_fullscreen = current_type and current_type.is_fullscreen and current_type.is_fullscreen()
  if not is_fullscreen then
    _seeker.lane_config.grid:draw(layers)
  end

  -- Response layer elements
  local focused_lane = _seeker.lanes[focused_lane_id]
  GridAnimations.update_trails(layers.response, focused_lane.trails)
  GridAnimations.update_keyboard_outline(layers.response, { fps = 30 }, _seeker.motif_recorder)
end

-- Handle all keyboard mode input
function KeyboardMode.handle_full_page_key(x, y, z)
  -- Block non-keyboard input during sampler recording
  if _seeker.sampler and _seeker.sampler.is_recording then
    return true
  end

  _seeker.ui_state.register_activity()

  -- Sub-mode buttons first
  if handle_sub_mode_key(x, y, z) then
    return true
  end

  -- Delegate to wheel layout
  if get_sub_mode() == "wheel" then
    return WheelLayout.handle_full_page_key(x, y, z)
  end

  -- Tape sub-mode: type-specific handling
  local current_type = type_registry.get_current()
  local is_fullscreen = current_type and current_type.is_fullscreen and current_type.is_fullscreen()

  if not is_fullscreen then
    if _seeker.lane_config.grid:contains(x, y) then
      _seeker.lane_config.grid:handle_key(x, y, z)
      return true
    end
  end

  if current_type then
    if current_type.handle_key(x, y, z) then
      return true
    end
  end

  return true
end

return KeyboardMode

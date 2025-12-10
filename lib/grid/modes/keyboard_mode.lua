-- keyboard_mode.lua
-- Full-page grid mode for keyboard/performance interface
-- Orchestrates type-specific components via registry, plus shared infrastructure

local KeyboardRegion = include("lib/grid/keyboard_region")
local GridAnimations = include("lib/grid/animations")
local type_registry = include("lib/modes/motif/type_registry")

local KeyboardMode = {}

-- Motif type constants
local TAPE_MODE = 1
local ARPEGGIO_MODE = 2
local SAMPLER_MODE = 3

-- Draw all keyboard mode elements
function KeyboardMode.draw_full_page(layers)
  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

  -- Try registry-based type first
  local current_type = type_registry.get_current()
  if current_type then
    current_type.draw(layers)
  else
    -- Fallback for types not yet in registry (Tape, Composer)
    if motif_type == TAPE_MODE then
      _seeker.velocity.grid:draw(layers)
      _seeker.motif_playback.grid:draw(layers)
      _seeker.tuning.grid:draw(layers)
      _seeker.clear_motif.grid:draw(layers)
      _seeker.create_motif.grid:draw(layers)
      _seeker.tape_stage_config.grid:draw(layers)
      KeyboardRegion.draw(layers)
    elseif motif_type == ARPEGGIO_MODE then
      _seeker.motif_playback.grid:draw(layers)
      _seeker.clear_motif.grid:draw(layers)
      _seeker.create_motif.grid:draw(layers)
      KeyboardRegion.draw(layers)
    end

    -- Shared components for legacy types
    _seeker.harmonic_config.grid:draw(layers)
    _seeker.expression_config.grid:draw(layers)
  end

  -- Shared infrastructure (all types)
  _seeker.lane_config.grid:draw(layers)

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

  -- Register activity for non-keyboard interactions
  _seeker.ui_state.register_activity()

  local focused_lane_id = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

  -- Shared infrastructure first (lane config)
  if _seeker.lane_config.grid:contains(x, y) then
    _seeker.lane_config.grid:handle_key(x, y, z)
    return true
  end

  -- Try registry-based type
  local current_type = type_registry.get_current()
  if current_type then
    if current_type.handle_key(x, y, z) then
      return true
    end
  else
    -- Fallback for types not yet in registry (Tape, Composer)
    if KeyboardRegion.contains(x, y) then
      KeyboardRegion.handle_key(x, y, z)
      return true
    end

    if motif_type == TAPE_MODE then
      if _seeker.velocity.grid:contains(x, y) then
        _seeker.velocity.grid:handle_key(x, y, z)
        return true
      elseif _seeker.tuning.grid:contains(x, y) then
        _seeker.tuning.grid:handle_key(x, y, z)
        return true
      elseif _seeker.tape_stage_config.grid:contains(x, y) then
        _seeker.tape_stage_config.grid:handle_key(x, y, z)
        return true
      end
    end

    if motif_type == TAPE_MODE or motif_type == ARPEGGIO_MODE then
      if _seeker.motif_playback.grid:contains(x, y) then
        _seeker.motif_playback.grid:handle_key(x, y, z)
        return true
      elseif _seeker.clear_motif.grid:contains(x, y) then
        _seeker.clear_motif.grid:handle_key(x, y, z)
        return true
      elseif _seeker.create_motif.grid:contains(x, y) then
        _seeker.create_motif.grid:handle_key(x, y, z)
        return true
      end
    end

    -- Shared components for legacy types
    if _seeker.harmonic_config.grid:contains(x, y) then
      _seeker.harmonic_config.grid:handle_key(x, y, z)
      return true
    elseif _seeker.expression_config.grid:contains(x, y) then
      _seeker.expression_config.grid:handle_key(x, y, z)
      return true
    end
  end

  return true
end

return KeyboardMode

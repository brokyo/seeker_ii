-- modals/adsr.lua
-- ADSR envelope editor modal with integrated encoder handling

local Base = include("lib/ui/components/modals/base")

local ADSR = {}

-- State keys this modal uses
ADSR.state_keys = {
  "hint",
  "adsr_data",
  "adsr_param_ids",
  "adsr_selected"
}

-- Arc display: rings 1-4 show A/D/S/R values, selected stage is brighter
local function draw_arc_display()
  local arc = _seeker.arc
  local Modal = _seeker.modal
  if not arc or not Modal then return end

  local selected = Modal.get_adsr_selected()
  local param_ids = Modal.get_adsr_param_ids()

  -- Fallback to lane params if modal didn't provide param IDs
  if not param_ids then
    local lane_idx = _seeker.ui_state.get_focused_lane()
    param_ids = {
      "lane_" .. lane_idx .. "_attack",
      "lane_" .. lane_idx .. "_decay",
      "lane_" .. lane_idx .. "_sustain",
      "lane_" .. lane_idx .. "_release"
    }
  end

  -- Each ring displays its corresponding ADSR stage value
  for ring = 1, 4 do
    local param_id = param_ids[ring]
    local value = params:get(param_id)

    -- Get param range
    local p = params:lookup_param(param_id)
    local min_val, max_val
    if p.controlspec then
      min_val = p.controlspec.minval
      max_val = p.controlspec.maxval
    elseif p.min and p.max then
      min_val = p.min
      max_val = p.max
    else
      min_val = 0
      max_val = 1
    end

    -- Normalize value to 0-1 range
    local normalized = (value - min_val) / (max_val - min_val)
    normalized = util.clamp(normalized, 0, 1)

    -- Calculate LED position
    local led_pos = math.floor(normalized * 63) + 1

    -- Selected stage (for Norns E3) has brighter highlight
    local is_selected = (ring == selected)
    local base_level = 2
    local highlight_level = is_selected and 15 or 10
    local edge_level = is_selected and 10 or 6

    -- Uniform base illumination across all rings
    for i = 1, 64 do
      arc:led(ring, i, base_level)
    end

    -- Highlight value position
    arc:led(ring, led_pos, highlight_level)
    if led_pos > 1 then arc:led(ring, led_pos - 1, edge_level) end
    if led_pos < 64 then arc:led(ring, led_pos + 1, edge_level) end
  end

  arc:refresh()
end

-- Get the fine step size for a param by looking up its controlspec
local function get_fine_step(param_id)
  local p = params:lookup_param(param_id)
  if not p then return 0.01 end

  if p.controlspec then
    -- Use controlspec step, or derive from range
    local step = p.controlspec.step
    if step and step > 0 then
      return step
    end
    -- Fallback: 1% of range
    local range = p.controlspec.maxval - p.controlspec.minval
    return range * 0.01
  elseif p.min ~= nil and p.max ~= nil then
    -- Number param: use 1 for integer-like ranges, derive for others
    local range = p.max - p.min
    if range <= 10 then
      return 0.01
    else
      return 1
    end
  end
  return 0.01
end

-- Adjust a specific ADSR stage by delta using fine step
local function adjust_stage(state, stage, delta)
  local param_ids = state.adsr_param_ids
  if not param_ids or not param_ids[stage] then return end

  local param_id = param_ids[stage]
  local step = get_fine_step(param_id)
  local current = params:get(param_id)
  local new_val = current + (delta * step)
  params:set(param_id, new_val)

  -- Update Arc display
  draw_arc_display()
end

function ADSR.show(state, config)
  state.adsr_data = config.get_data
  state.adsr_param_ids = config.param_ids
  state.adsr_selected = config.selected or 1
  state.hint = config.hint or "e2 select e3 adjust k3 close"

  -- Stop Arc pulse animation and register ADSR display
  if _seeker.arc then
    if _seeker.arc.stop_action_pulse then
      _seeker.arc.stop_action_pulse()
    end
    if _seeker.arc.set_display then
      _seeker.arc.set_display(draw_arc_display)
    end
  end
end

function ADSR.draw(state)
  local modal_x = Base.MODAL_MARGIN
  local modal_y = Base.MODAL_MARGIN
  local modal_width = Base.SCREEN_WIDTH - (Base.MODAL_MARGIN * 2)
  local modal_height = Base.SCREEN_HEIGHT - (Base.MODAL_MARGIN * 2)

  -- Get live data from callback
  local info = state.adsr_data and state.adsr_data() or {a = 0.1, d = 0.2, s = 0.7, r = 0.3}
  local a = info.a or 0.1
  local d = info.d or 0.2
  local s = info.s or 0.7
  local r = info.r or 0.3
  local selected = state.adsr_selected

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Envelope visualization area
  local env_x = modal_x + Base.PADDING + 2
  local env_y = modal_y + 12
  local env_width = modal_width - (Base.PADDING * 2) - 4
  local env_height = 22

  -- Calculate envelope segment widths
  local sustain_time = 0.5
  local raw_total = a + d + sustain_time + r
  local base_scale = env_width / raw_total

  local w_attack = a * base_scale
  local w_decay = d * base_scale
  local w_sustain = sustain_time * base_scale
  local w_release = r * base_scale

  -- Scale down if total exceeds available width
  local total_width = w_attack + w_decay + w_sustain + w_release
  if total_width > env_width then
    local shrink = env_width / total_width
    w_attack = w_attack * shrink
    w_decay = w_decay * shrink
    w_sustain = w_sustain * shrink
    w_release = w_release * shrink
  end

  local x_start = env_x
  local x_attack = x_start + w_attack
  local x_decay = x_attack + w_decay
  local x_sustain = x_decay + w_sustain
  local x_release = x_sustain + w_release

  local y_bottom = env_y + env_height
  local y_top = env_y
  local y_sustain = env_y + (env_height * (1 - s))

  -- Draw envelope shape
  screen.level(10)
  screen.move(x_start, y_bottom)
  screen.line(x_attack, y_top)
  screen.line(x_decay, y_sustain)
  screen.line(x_sustain, y_sustain)
  screen.line(x_release, y_bottom)
  screen.stroke()

  -- Draw stage labels with selection highlight
  local labels = {"A", "D", "S", "R"}
  local x_positions = {
    (x_start + x_attack) / 2,
    (x_attack + x_decay) / 2,
    (x_decay + x_sustain) / 2,
    (x_sustain + x_release) / 2
  }

  screen.font_face(1)
  screen.font_size(8)

  local label_y = y_bottom + 9

  for i, label in ipairs(labels) do
    local x = x_positions[i]
    local is_selected = (i == selected)

    if is_selected then
      screen.level(15)
      local label_width = screen.text_extents(label)
      screen.rect(x - label_width/2 - 2, label_y - 7, label_width + 4, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(6)
    end

    local label_width = screen.text_extents(label)
    screen.move(x - label_width/2, label_y)
    screen.text(label)
  end

  -- Title
  screen.level(10)
  screen.move(modal_x + modal_width / 2 - screen.text_extents("ENVELOPE") / 2, modal_y + 8)
  screen.text("ENVELOPE")

  Base.draw_hint(state.hint, modal_x, modal_y, modal_width, modal_height)
end

-- Encoder handling: Arc 1-4 map to A/D/S/R, Norns E2 selects E3 adjusts
function ADSR.handle_enc(state, n, d, source)
  source = source or "norns"

  if source == "arc" then
    -- Arc encoders 1-4 directly control A/D/S/R stages
    if n >= 1 and n <= 4 then
      adjust_stage(state, n, d)
      _seeker.screen_ui.set_needs_redraw()
      return true
    end
  else
    -- Norns E2: select stage
    if n == 2 then
      local current = state.adsr_selected or 1
      local new_sel = util.clamp(current + util.round(d), 1, 4)
      state.adsr_selected = new_sel
      draw_arc_display()
      _seeker.screen_ui.set_needs_redraw()
      return true
    -- Norns E3: adjust selected stage with fine step
    elseif n == 3 then
      local selected = state.adsr_selected or 1
      adjust_stage(state, selected, d)
      _seeker.screen_ui.set_needs_redraw()
      return true
    end
  end

  return false
end

-- Getters for external access (Arc display)
function ADSR.get_selected(state)
  return state.adsr_selected
end

function ADSR.set_selected(state, idx)
  state.adsr_selected = util.clamp(idx, 1, 4)
end

function ADSR.get_data(state)
  if state.adsr_data then
    return state.adsr_data()
  end
  return nil
end

function ADSR.get_param_ids(state)
  return state.adsr_param_ids
end

function ADSR.cleanup(state)
  state.adsr_data = nil
  state.adsr_param_ids = nil
  state.adsr_selected = 1
  state.hint = nil
end

return ADSR

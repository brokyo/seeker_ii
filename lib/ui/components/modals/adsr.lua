-- modals/adsr.lua
-- ADSR envelope editor modal

local Base = include("lib/ui/components/modals/base")

local ADSR = {}

-- State keys this modal uses
ADSR.state_keys = {
  "hint",
  "adsr_data",
  "adsr_param_ids",
  "adsr_selected"
}

function ADSR.show(state, config)
  state.adsr_data = config.get_data
  state.adsr_param_ids = config.param_ids
  state.adsr_selected = config.selected or 1
  state.hint = config.hint or "k2 cancel - k3 save"
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

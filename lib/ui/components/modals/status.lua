-- modals/status.lua
-- Centered status message modal

local Base = include("lib/ui/components/modals/base")

local Status = {}

-- State keys this modal uses
Status.state_keys = {
  "body",
  "hint",
  "allows_norns_input"
}

function Status.show(state, config)
  state.body = config.body or ""
  state.hint = config.hint or nil
  state.allows_norns_input = config.allows_norns_input == true
end

function Status.draw(state)
  local modal_x = 10
  local modal_y = 18
  local modal_width = Base.SCREEN_WIDTH - 20
  local modal_height = 28

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  -- Status text (centered, large)
  screen.level(15)
  screen.font_face(Base.FONTS.STATUS)
  screen.font_size(Base.SIZES.STATUS)
  local text_width = screen.text_extents(state.body)
  screen.move(Base.SCREEN_WIDTH / 2 - text_width / 2, modal_y + modal_height / 2 + Base.SIZES.STATUS / 3)
  screen.text(state.body)

  -- Hint text (below status)
  if state.hint then
    screen.level(6)
    screen.font_face(Base.FONTS.HINT)
    screen.font_size(Base.SIZES.HINT)
    local hint_width = screen.text_extents(state.hint)
    screen.move(Base.SCREEN_WIDTH / 2 - hint_width / 2, modal_y + modal_height + 10)
    screen.text(state.hint)
  end

  Base.reset_font()
end

function Status.handle_enc(state, n, d, source)
  -- Always block Arc, block Norns unless allows_norns_input is true
  if source == "arc" then
    return true
  end
  return not state.allows_norns_input
end

function Status.handle_key(state, n, z)
  return not state.allows_norns_input
end

function Status.cleanup(state)
  state.body = nil
  state.hint = nil
  state.allows_norns_input = false
end

-- Draw status without managing state (for transient overlays)
function Status.draw_immediate(config)
  local body = config.body or ""
  local hint = config.hint or nil

  local modal_x = 10
  local modal_y = 18
  local modal_width = Base.SCREEN_WIDTH - 20
  local modal_height = 28

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  screen.level(15)
  screen.font_face(Base.FONTS.STATUS)
  screen.font_size(Base.SIZES.STATUS)
  local text_width = screen.text_extents(body)
  screen.move(Base.SCREEN_WIDTH / 2 - text_width / 2, modal_y + modal_height / 2 + Base.SIZES.STATUS / 3)
  screen.text(body)

  if hint then
    screen.level(6)
    screen.font_face(Base.FONTS.HINT)
    screen.font_size(Base.SIZES.HINT)
    local hint_width = screen.text_extents(hint)
    screen.move(Base.SCREEN_WIDTH / 2 - hint_width / 2, modal_y + modal_height + 10)
    screen.text(hint)
  end

  Base.reset_font()
end

return Status

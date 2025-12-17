-- modals/description.lua
-- Scrollable text modal for help and info display

local Base = include("lib/ui/components/modals/base")

local Description = {}

-- State keys this modal uses
Description.state_keys = {
  "body",
  "hint",
  "scroll_offset",
  "wrapped_lines",
  "max_scroll"
}

function Description.show(state, config)
  state.body = config.body or ""
  state.hint = config.hint or "release k2"
  state.scroll_offset = 0

  -- Pre-wrap body text (leave room for scrollbar)
  screen.font_face(Base.FONTS.BODY)
  screen.font_size(Base.SIZES.BODY)
  local text_width = Base.SCREEN_WIDTH - (Base.MODAL_MARGIN * 2) - (Base.PADDING * 2) - 6
  state.wrapped_lines = Base.wrap_text(state.body, text_width)

  -- Calculate max scroll based on visible area
  local hint_space = state.hint and (Base.SIZES.HINT + 4) or 0
  local available_height = Base.SCREEN_HEIGHT - (Base.MODAL_MARGIN * 2) - hint_space - Base.PADDING
  local visible_lines = math.floor(available_height / Base.LINE_HEIGHT)
  state.max_scroll = math.max(0, #state.wrapped_lines - visible_lines)
end

function Description.draw(state)
  local modal_x = Base.MODAL_MARGIN
  local modal_y = Base.MODAL_MARGIN
  local modal_width = Base.SCREEN_WIDTH - (Base.MODAL_MARGIN * 2)
  local modal_height = Base.SCREEN_HEIGHT - (Base.MODAL_MARGIN * 2)

  Base.draw_frame(modal_x, modal_y, modal_width, modal_height)

  local content_x = modal_x + Base.PADDING
  local content_y = modal_y + Base.PADDING

  local hint_space = state.hint and (Base.SIZES.HINT + 6) or 0
  local available_height = (modal_y + modal_height - hint_space) - content_y - 2

  -- Draw lines with variable height for empty lines
  local y_pos = content_y
  local lines_drawn = 0
  for i = state.scroll_offset + 1, #state.wrapped_lines do
    local line = state.wrapped_lines[i]
    local line_height = line.is_empty and Base.EMPTY_LINE_HEIGHT or Base.LINE_HEIGHT

    if y_pos + line_height > content_y + available_height then break end

    y_pos = y_pos + line_height

    if not line.is_empty then
      screen.font_face(Base.FONTS.BODY)
      screen.font_size(Base.SIZES.BODY)
      screen.level(12)
      screen.move(content_x, y_pos - 2)
      screen.text(line.text)
    end

    lines_drawn = lines_drawn + 1
  end

  -- Draw scrollbar if content exceeds visible area
  if state.max_scroll > 0 then
    local track_x = modal_x + modal_width - 3
    local track_top = content_y + 2
    local track_height = available_height - 4

    screen.level(2)
    screen.rect(track_x, track_top, 2, track_height)
    screen.fill()

    local total_lines = #state.wrapped_lines
    local thumb_height = math.max(4, math.floor((lines_drawn / total_lines) * track_height))
    local scroll_range = track_height - thumb_height
    local thumb_y = track_top + math.floor((state.scroll_offset / state.max_scroll) * scroll_range)

    screen.level(10)
    screen.rect(track_x, thumb_y, 2, thumb_height)
    screen.fill()
  end

  Base.draw_hint(state.hint, modal_x, modal_y, modal_width, modal_height)
  Base.reset_font()
end

function Description.handle_enc(state, n, d, source)
  if n == 3 then
    state.scroll_offset = util.clamp(
      state.scroll_offset + util.round(d),
      0,
      state.max_scroll
    )
    return true
  end
  return false
end

function Description.cleanup(state)
  state.body = nil
  state.hint = nil
  state.scroll_offset = 0
  state.wrapped_lines = {}
  state.max_scroll = 0
end

return Description

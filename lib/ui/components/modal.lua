-- modal.lua
-- Modal overlay system with two display modes: scrollable description dialogs and centered status messages

local Modal = {}

-- Font constants (Norns font indices)
local FONTS = {
  TITLE = 7,      -- Roboto Bold
  BODY = 1,       -- norns default
  STATUS = 5,     -- Roboto Regular
  HINT = 1        -- norns default
}

local SIZES = {
  TITLE = 10,
  BODY = 8,
  STATUS = 14,
  HINT = 8
}

-- Layout constants
local SCREEN_WIDTH = 128
local SCREEN_HEIGHT = 64
local PADDING = 6
local LINE_HEIGHT = 10
local MODAL_MARGIN = 4

-- Modal types
Modal.TYPE = {
  DESCRIPTION = "description",
  STATUS = "status"
}

-- Internal state
local state = {
  active = false,
  modal_type = nil,
  title = nil,
  body = nil,
  hint = nil,
  scroll_offset = 0,
  wrapped_lines = {},
  max_scroll = 0
}

-- Word-wrap text to fit within max_width using current font settings
local function wrap_text(text, max_width)
  local lines = {}
  local words = {}

  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end

  local current_line = ""
  for _, word in ipairs(words) do
    local test_line = current_line == "" and word or (current_line .. " " .. word)
    local width = screen.text_extents(test_line)

    if width > max_width then
      if current_line ~= "" then
        table.insert(lines, current_line)
      end
      current_line = word
    else
      current_line = test_line
    end
  end

  if current_line ~= "" then
    table.insert(lines, current_line)
  end

  return lines
end

-- Draw a rounded rectangle (using arcs at corners)
local function draw_rounded_rect(x, y, w, h, r, fill)
  r = math.min(r, w/2, h/2)

  -- Draw the four corners as arcs
  screen.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)           -- top-left
  screen.arc(x + w - r, y + r, r, 1.5 * math.pi, 2 * math.pi)   -- top-right
  screen.arc(x + w - r, y + h - r, r, 0, 0.5 * math.pi)         -- bottom-right
  screen.arc(x + r, y + h - r, r, 0.5 * math.pi, math.pi)       -- bottom-left

  -- Connect the arcs with lines
  screen.move(x + r, y)
  screen.line(x + w - r, y)           -- top edge
  screen.move(x + w, y + r)
  screen.line(x + w, y + h - r)       -- right edge
  screen.move(x + w - r, y + h)
  screen.line(x + r, y + h)           -- bottom edge
  screen.move(x, y + h - r)
  screen.line(x, y + r)               -- left edge

  if fill then
    screen.fill()
  else
    screen.stroke()
  end
end

-- Draw shadow/depth effect (stacked rectangles)
local function draw_shadow(x, y, w, h)
  screen.level(2)
  screen.rect(x + 2, y + 2, w, h)
  screen.fill()
end

-- Show a description modal (scrollable text with title)
function Modal.show_description(config)
  state.active = true
  state.modal_type = Modal.TYPE.DESCRIPTION
  state.title = config.title or nil
  state.body = config.body or ""
  state.hint = config.hint or "release k2"
  state.scroll_offset = 0

  -- Pre-wrap body text
  screen.font_face(FONTS.BODY)
  screen.font_size(SIZES.BODY)
  local text_width = SCREEN_WIDTH - (MODAL_MARGIN * 2) - (PADDING * 2)
  state.wrapped_lines = wrap_text(state.body, text_width)

  -- Calculate max scroll based on visible area
  local title_space = state.title and (SIZES.TITLE + 6) or 0
  local hint_space = state.hint and (SIZES.HINT + 4) or 0
  local available_height = SCREEN_HEIGHT - (MODAL_MARGIN * 2) - title_space - hint_space - PADDING
  local visible_lines = math.floor(available_height / LINE_HEIGHT)
  state.max_scroll = math.max(0, #state.wrapped_lines - visible_lines)
end

-- Show a status modal (centered message, no scroll)
function Modal.show_status(config)
  state.active = true
  state.modal_type = Modal.TYPE.STATUS
  state.title = config.title or nil
  state.body = config.body or ""
  state.hint = config.hint or nil
  state.scroll_offset = 0
  state.wrapped_lines = {}
  state.max_scroll = 0
end

-- Dismiss the modal
function Modal.dismiss()
  state.active = false
  state.modal_type = nil
  state.title = nil
  state.body = nil
  state.hint = nil
  state.scroll_offset = 0
  state.wrapped_lines = {}
  state.max_scroll = 0
end

-- Check if modal is currently active
function Modal.is_active()
  return state.active
end

-- Get current modal type
function Modal.get_type()
  return state.modal_type
end

-- Handle encoder input (for scrolling descriptions)
-- Returns true if the modal consumed the input
function Modal.handle_enc(n, d)
  if not state.active then return false end

  -- Only intercept e3 for description scrolling
  if n == 3 and state.modal_type == Modal.TYPE.DESCRIPTION then
    state.scroll_offset = util.clamp(
      state.scroll_offset + d,
      0,
      state.max_scroll
    )
    return true  -- Consumed the input
  end

  return false
end

-- Draw the modal
function Modal.draw()
  if not state.active then return end

  if state.modal_type == Modal.TYPE.DESCRIPTION then
    Modal._draw_description()
  elseif state.modal_type == Modal.TYPE.STATUS then
    Modal._draw_status()
  end
end

-- Draw description modal (scrollable text)
function Modal._draw_description()
  local mx = MODAL_MARGIN
  local my = MODAL_MARGIN
  local mw = SCREEN_WIDTH - (MODAL_MARGIN * 2)
  local mh = SCREEN_HEIGHT - (MODAL_MARGIN * 2)

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(mx, my, mw, mh)

  -- Modal background
  screen.level(1)
  screen.rect(mx, my, mw, mh)
  screen.fill()

  -- Border
  screen.level(6)
  screen.rect(mx, my, mw, mh)
  screen.stroke()

  local content_x = mx + PADDING
  local content_y = my + PADDING

  -- Title (if provided)
  if state.title then
    screen.level(15)
    screen.font_face(FONTS.TITLE)
    screen.font_size(SIZES.TITLE)
    screen.move(content_x, content_y + SIZES.TITLE - 2)
    screen.text(state.title)
    content_y = content_y + SIZES.TITLE + 4

    -- Subtle divider line
    screen.level(3)
    screen.move(content_x, content_y)
    screen.line(mx + mw - PADDING, content_y)
    screen.stroke()
    content_y = content_y + 4
  end

  -- Body text (scrollable)
  screen.font_face(FONTS.BODY)
  screen.font_size(SIZES.BODY)
  screen.level(12)

  local hint_space = state.hint and (SIZES.HINT + 6) or 0
  local available_height = (my + mh - hint_space) - content_y - 2
  local visible_lines = math.floor(available_height / LINE_HEIGHT)

  for i = 1, visible_lines do
    local line_idx = i + state.scroll_offset
    if line_idx <= #state.wrapped_lines then
      screen.move(content_x, content_y + (i * LINE_HEIGHT) - 2)
      screen.text(state.wrapped_lines[line_idx])
    end
  end

  -- Scroll indicators
  if state.scroll_offset > 0 then
    screen.level(6)
    screen.move(mx + mw - PADDING, content_y + 4)
    screen.text("▲")
  end
  if state.scroll_offset < state.max_scroll then
    screen.level(6)
    screen.move(mx + mw - PADDING, content_y + available_height - 4)
    screen.text("▼")
  end

  -- Hint text (bottom)
  if state.hint then
    screen.level(4)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_y = my + mh - 4
    screen.move(mx + mw / 2 - screen.text_extents(state.hint) / 2, hint_y)
    screen.text(state.hint)
  end
end

-- Draw status modal (centered, prominent)
function Modal._draw_status()
  local mx = 10
  local my = 18
  local mw = SCREEN_WIDTH - 20
  local mh = 28

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(mx, my, mw, mh)

  -- Modal background
  screen.level(1)
  screen.rect(mx, my, mw, mh)
  screen.fill()

  -- Border
  screen.level(8)
  screen.rect(mx, my, mw, mh)
  screen.stroke()

  -- Status text (centered, large)
  screen.level(15)
  screen.font_face(FONTS.STATUS)
  screen.font_size(SIZES.STATUS)
  local text_width = screen.text_extents(state.body)
  screen.move(SCREEN_WIDTH / 2 - text_width / 2, my + mh / 2 + SIZES.STATUS / 3)
  screen.text(state.body)

  -- Hint text (below status)
  if state.hint then
    screen.level(6)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_width = screen.text_extents(state.hint)
    screen.move(SCREEN_WIDTH / 2 - hint_width / 2, my + mh + 10)
    screen.text(state.hint)
  end
end

-- Draw a status modal immediately without managing internal state
-- For transient overlays where state is managed externally
function Modal.draw_status_immediate(config)
  local body = config.body or ""
  local hint = config.hint or nil

  local mx = 10
  local my = 18
  local mw = SCREEN_WIDTH - 20
  local mh = 28

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(mx, my, mw, mh)

  -- Modal background
  screen.level(1)
  screen.rect(mx, my, mw, mh)
  screen.fill()

  -- Border
  screen.level(8)
  screen.rect(mx, my, mw, mh)
  screen.stroke()

  -- Status text (centered, large)
  screen.level(15)
  screen.font_face(FONTS.STATUS)
  screen.font_size(SIZES.STATUS)
  local text_width = screen.text_extents(body)
  screen.move(SCREEN_WIDTH / 2 - text_width / 2, my + mh / 2 + SIZES.STATUS / 3)
  screen.text(body)

  -- Hint text (below status)
  if hint then
    screen.level(6)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_width = screen.text_extents(hint)
    screen.move(SCREEN_WIDTH / 2 - hint_width / 2, my + mh + 10)
    screen.text(hint)
  end

  -- Reset font to default
  screen.font_face(1)
  screen.font_size(8)
end

return Modal

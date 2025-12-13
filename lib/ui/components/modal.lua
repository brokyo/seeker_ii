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
local EMPTY_LINE_HEIGHT = 4
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
  body = nil,
  hint = nil,
  scroll_offset = 0,
  wrapped_lines = {},
  max_scroll = 0
}

-- Word-wrap text to fit within max_width using current font settings
-- Handles explicit newlines by splitting paragraphs first
-- Returns table of {text, is_empty, bold_prefix} entries
local function wrap_text(text, max_width)
  local lines = {}

  -- Split on newlines first to preserve explicit line breaks
  for paragraph in text:gmatch("([^\n]*)\n?") do
    if paragraph == "" then
      -- Empty line (explicit blank line from \n\n)
      table.insert(lines, {text = "", is_empty = true})
    else
      -- Word-wrap this paragraph
      local words = {}
      for word in paragraph:gmatch("%S+") do
        table.insert(words, word)
      end

      if #words == 0 then
        table.insert(lines, {text = "", is_empty = true})
      else
        local current_line = ""
        for _, word in ipairs(words) do
          local test_line = current_line == "" and word or (current_line .. " " .. word)
          local width = screen.text_extents(test_line)

          if width > max_width then
            if current_line ~= "" then
              -- Check if line starts with "Word:" pattern for uppercase styling
              local bold_prefix = current_line:match("^([%w%s]+:)")
              table.insert(lines, {text = current_line, is_empty = false, bold_prefix = bold_prefix})
            end
            current_line = word
          else
            current_line = test_line
          end
        end

        if current_line ~= "" then
          local bold_prefix = current_line:match("^([%w%s]+:)")
          table.insert(lines, {text = current_line, is_empty = false, bold_prefix = bold_prefix})
        end
      end
    end
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

-- Show a description modal (scrollable text)
function Modal.show_description(config)
  state.active = true
  state.modal_type = Modal.TYPE.DESCRIPTION
  state.body = config.body or ""
  state.hint = config.hint or "release k2"
  state.scroll_offset = 0

  -- Pre-wrap body text (leave room for scrollbar)
  screen.font_face(FONTS.BODY)
  screen.font_size(SIZES.BODY)
  local text_width = SCREEN_WIDTH - (MODAL_MARGIN * 2) - (PADDING * 2) - 6
  state.wrapped_lines = wrap_text(state.body, text_width)

  -- Calculate max scroll based on visible area
  local hint_space = state.hint and (SIZES.HINT + 4) or 0
  local available_height = SCREEN_HEIGHT - (MODAL_MARGIN * 2) - hint_space - PADDING
  local visible_lines = math.floor(available_height / LINE_HEIGHT)
  state.max_scroll = math.max(0, #state.wrapped_lines - visible_lines)
end

-- Show a status modal (centered message, no scroll)
function Modal.show_status(config)
  state.active = true
  state.modal_type = Modal.TYPE.STATUS
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
      state.scroll_offset + util.round(d),
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
  local modal_x = MODAL_MARGIN
  local modal_y = MODAL_MARGIN
  local modal_width = SCREEN_WIDTH - (MODAL_MARGIN * 2)
  local modal_height = SCREEN_HEIGHT - (MODAL_MARGIN * 2)

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(modal_x, modal_y, modal_width, modal_height)

  -- Modal background
  screen.level(1)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.fill()

  -- Border
  screen.level(6)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.stroke()

  local content_x = modal_x + PADDING
  local content_y = modal_y + PADDING

  local hint_space = state.hint and (SIZES.HINT + 6) or 0
  local available_height = (modal_y + modal_height - hint_space) - content_y - 2

  -- Draw lines with variable height for empty lines
  local y_pos = content_y
  local lines_drawn = 0
  for i = state.scroll_offset + 1, #state.wrapped_lines do
    local line = state.wrapped_lines[i]
    local line_height = line.is_empty and EMPTY_LINE_HEIGHT or LINE_HEIGHT

    -- Stop if we'd overflow
    if y_pos + line_height > content_y + available_height then break end

    y_pos = y_pos + line_height

    if not line.is_empty then
      screen.font_face(FONTS.BODY)
      screen.font_size(SIZES.BODY)
      screen.level(12)
      screen.move(content_x, y_pos - 2)

      -- Uppercase prefix if present, otherwise draw normal text
      if line.bold_prefix then
        local upper_prefix = string.upper(line.bold_prefix)
        local rest = line.text:sub(#line.bold_prefix + 1)
        screen.text(upper_prefix .. rest)
      else
        screen.text(line.text)
      end
    end

    lines_drawn = lines_drawn + 1
  end

  -- Draw scrollbar if content exceeds visible area
  if state.max_scroll > 0 then
    local track_x = modal_x + modal_width - 3
    local track_top = content_y + 2
    local track_height = available_height - 4

    -- Draw track (dim background)
    screen.level(2)
    screen.rect(track_x, track_top, 2, track_height)
    screen.fill()

    -- Calculate thumb size and position
    local total_lines = #state.wrapped_lines
    local thumb_height = math.max(4, math.floor((lines_drawn / total_lines) * track_height))
    local scroll_range = track_height - thumb_height
    local thumb_y = track_top + math.floor((state.scroll_offset / state.max_scroll) * scroll_range)

    -- Draw thumb (bright)
    screen.level(10)
    screen.rect(track_x, thumb_y, 2, thumb_height)
    screen.fill()
  end

  -- Hint text (bottom)
  if state.hint then
    screen.level(4)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_y = modal_y + modal_height - 4
    screen.move(modal_x + modal_width / 2 - screen.text_extents(state.hint) / 2, hint_y)
    screen.text(state.hint)
  end
end

-- Draw status modal (centered, prominent)
function Modal._draw_status()
  local modal_x = 10
  local modal_y = 18
  local modal_width = SCREEN_WIDTH - 20
  local modal_height = 28

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(modal_x, modal_y, modal_width, modal_height)

  -- Modal background
  screen.level(1)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.fill()

  -- Border
  screen.level(8)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.stroke()

  -- Status text (centered, large)
  screen.level(15)
  screen.font_face(FONTS.STATUS)
  screen.font_size(SIZES.STATUS)
  local text_width = screen.text_extents(state.body)
  screen.move(SCREEN_WIDTH / 2 - text_width / 2, modal_y + modal_height / 2 + SIZES.STATUS / 3)
  screen.text(state.body)

  -- Hint text (below status)
  if state.hint then
    screen.level(6)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_width = screen.text_extents(state.hint)
    screen.move(SCREEN_WIDTH / 2 - hint_width / 2, modal_y + modal_height + 10)
    screen.text(state.hint)
  end
end

-- Draw a status modal immediately without managing internal state
-- For transient overlays where state is managed externally
function Modal.draw_status_immediate(config)
  local body = config.body or ""
  local hint = config.hint or nil

  local modal_x = 10
  local modal_y = 18
  local modal_width = SCREEN_WIDTH - 20
  local modal_height = 28

  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  draw_shadow(modal_x, modal_y, modal_width, modal_height)

  -- Modal background
  screen.level(1)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.fill()

  -- Border
  screen.level(8)
  screen.rect(modal_x, modal_y, modal_width, modal_height)
  screen.stroke()

  -- Status text (centered, large)
  screen.level(15)
  screen.font_face(FONTS.STATUS)
  screen.font_size(SIZES.STATUS)
  local text_width = screen.text_extents(body)
  screen.move(SCREEN_WIDTH / 2 - text_width / 2, modal_y + modal_height / 2 + SIZES.STATUS / 3)
  screen.text(body)

  -- Hint text (below status)
  if hint then
    screen.level(6)
    screen.font_face(FONTS.HINT)
    screen.font_size(SIZES.HINT)
    local hint_width = screen.text_extents(hint)
    screen.move(SCREEN_WIDTH / 2 - hint_width / 2, modal_y + modal_height + 10)
    screen.text(hint)
  end

  -- Reset font to default
  screen.font_face(1)
  screen.font_size(8)
end

return Modal

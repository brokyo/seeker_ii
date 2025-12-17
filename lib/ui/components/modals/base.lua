-- modals/base.lua
-- Shared constants and helpers for all modal types

local Base = {}

-- Font constants (Norns font indices)
Base.FONTS = {
  TITLE = 7,      -- Roboto Bold
  BODY = 1,       -- norns default
  STATUS = 5,     -- Roboto Regular
  HINT = 1        -- norns default
}

Base.SIZES = {
  TITLE = 10,
  BODY = 8,
  STATUS = 14,
  HINT = 8
}

-- Layout constants
Base.SCREEN_WIDTH = 128
Base.SCREEN_HEIGHT = 64
Base.PADDING = 6
Base.LINE_HEIGHT = 10
Base.EMPTY_LINE_HEIGHT = 4
Base.MODAL_MARGIN = 4

-- Draw shadow/depth effect
function Base.draw_shadow(x, y, w, h)
  screen.level(2)
  screen.rect(x + 2, y + 2, w, h)
  screen.fill()
end

-- Draw modal frame (background, shadow, border)
function Base.draw_frame(x, y, w, h)
  -- Dark background overlay
  screen.level(0)
  screen.rect(0, 0, Base.SCREEN_WIDTH, Base.SCREEN_HEIGHT)
  screen.fill()

  -- Shadow
  Base.draw_shadow(x, y, w, h)

  -- Modal background
  screen.level(1)
  screen.rect(x, y, w, h)
  screen.fill()

  -- Border
  screen.level(6)
  screen.rect(x, y, w, h)
  screen.stroke()
end

-- Draw hint text centered at bottom of modal
function Base.draw_hint(hint, modal_x, modal_y, modal_width, modal_height)
  if not hint then return end
  screen.level(4)
  screen.font_face(Base.FONTS.HINT)
  screen.font_size(Base.SIZES.HINT)
  local hint_width = screen.text_extents(hint)
  screen.move(modal_x + modal_width / 2 - hint_width / 2, modal_y + modal_height - 4)
  screen.text(hint)
end

-- Reset font to default
function Base.reset_font()
  screen.font_face(1)
  screen.font_size(8)
end

-- Word-wrap text to fit within max_width
function Base.wrap_text(text, max_width)
  local lines = {}

  for paragraph in text:gmatch("([^\n]*)\n?") do
    if paragraph == "" then
      table.insert(lines, {text = "", is_empty = true})
    else
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
              table.insert(lines, {text = current_line, is_empty = false})
            end
            current_line = word
          else
            current_line = test_line
          end
        end

        if current_line ~= "" then
          table.insert(lines, {text = current_line, is_empty = false})
        end
      end
    end
  end

  return lines
end

return Base

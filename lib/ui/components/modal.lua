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
  STATUS = "status",
  RECORDING = "recording",
  ADSR = "adsr"
}

-- Internal state
local state = {
  active = false,
  modal_type = nil,
  body = nil,
  hint = nil,
  scroll_offset = 0,
  wrapped_lines = {},
  max_scroll = 0,
  -- Recording modal state
  recording_data = nil,       -- function that returns {data, current_voltage, min, max}
  recording_output = nil,     -- output number being recorded
  -- ADSR modal state
  adsr_data = nil,            -- function that returns {a, d, s, r, selected}
  adsr_selected = 1,          -- currently selected stage (1=A, 2=D, 3=S, 4=R)
  -- Input callbacks (optional, for multi-step interactions)
  on_key = nil,               -- function(n, z) -> bool (return true to block default handling)
  on_enc = nil                -- function(n, d, source) -> bool (return true to block default handling)
}

-- Word-wrap text to fit within max_width using current font settings
-- Handles explicit newlines by splitting paragraphs first
-- Returns table of {text, is_empty} entries
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
-- config.allows_norns_input: if true, norns E2/E3/K3 pass through (for fileselect). Default false.
-- config.on_key: optional key handler (e.g., K3 to stop recording)
function Modal.show_status(config)
  state.active = true
  state.modal_type = Modal.TYPE.STATUS
  state.body = config.body or ""
  state.hint = config.hint or nil
  state.scroll_offset = 0
  state.wrapped_lines = {}
  state.max_scroll = 0
  state.allows_norns_input = config.allows_norns_input == true
  state.on_key = config.on_key
end

-- Show a recording modal (live waveform visualization)
-- config.get_data: function returning {data={}, voltage=0, min=-10, max=10}
-- config.output_num: crow output number (1-4)
-- config.on_key: optional function(n, z) for key handling, return true to block default handling
-- config.on_enc: optional function(n, d, source) for encoder handling, return true to block default handling
function Modal.show_recording(config)
  state.active = true
  state.modal_type = Modal.TYPE.RECORDING
  state.recording_data = config.get_data
  state.recording_output = config.output_num
  state.hint = config.hint or "k2/k3 stop"
  state.on_key = config.on_key
  state.on_enc = config.on_enc
end

-- Show an ADSR editor modal
-- config.get_data: function returning {a, d, s, r} values (0-1 range for time params, 0-1 for sustain)
-- config.on_key: optional function(n, z) for key handling
-- config.on_enc: optional function(n, d, source) for encoder handling
function Modal.show_adsr(config)
  state.active = true
  state.modal_type = Modal.TYPE.ADSR
  state.adsr_data = config.get_data
  state.adsr_param_ids = config.param_ids  -- Store param IDs for Arc display
  state.adsr_selected = config.selected or 1
  state.hint = config.hint or "k2 cancel · k3 save"
  state.on_key = config.on_key
  state.on_enc = config.on_enc
end

-- Get/set ADSR selected stage (for Norns E2 navigation)
function Modal.get_adsr_selected()
  return state.adsr_selected
end

function Modal.set_adsr_selected(idx)
  state.adsr_selected = util.clamp(idx, 1, 4)
end

-- Get ADSR data from callback (for Arc display)
function Modal.get_adsr_data()
  if state.adsr_data then
    return state.adsr_data()
  end
  return nil
end

-- Get ADSR param IDs (for Arc display)
function Modal.get_adsr_param_ids()
  return state.adsr_param_ids
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
  state.recording_data = nil
  state.recording_output = nil
  state.adsr_data = nil
  state.adsr_selected = 1
  state.on_key = nil
  state.on_enc = nil
  state.blocks_norns = true  -- Reset to default
end

-- Check if modal is currently active
function Modal.is_active()
  return state.active
end

-- Get current modal type
function Modal.get_type()
  return state.modal_type
end

-- Handle key input when modal is active
-- Returns true if the modal handled the input (blocks input from reaching underlying UI)
function Modal.handle_key(n, z)
  if not state.active then return false end

  -- If modal has a key callback, let it handle input first
  if state.on_key then
    local handled = state.on_key(n, z)
    if handled then return true end
  end

  -- Status modals block key input unless blocks_norns is false (for fileselect)
  if state.modal_type == Modal.TYPE.STATUS then
    return state.blocks_norns ~= false
  end

  return false
end

-- Handle encoder input (for scrolling descriptions or custom callbacks)
-- source: "norns" or "arc" to differentiate input device
-- Returns true if the modal handled the input (blocks input from reaching underlying UI)
function Modal.handle_enc(n, d, source)
  if not state.active then return false end

  source = source or "norns"

  -- If modal has an encoder callback, let it handle input first
  if state.on_enc then
    local handled = state.on_enc(n, d, source)
    if handled then return true end
  end

  -- Default: e3 scrolls description modals
  if n == 3 and state.modal_type == Modal.TYPE.DESCRIPTION then
    state.scroll_offset = util.clamp(
      state.scroll_offset + util.round(d),
      0,
      state.max_scroll
    )
    return true
  end

  -- Status modals: always block Arc, block Norns only if blocks_norns is true
  if state.modal_type == Modal.TYPE.STATUS then
    if source == "arc" then
      return true  -- Always block Arc during status modals
    end
    return state.blocks_norns ~= false  -- Block Norns unless explicitly allowed
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
  elseif state.modal_type == Modal.TYPE.RECORDING then
    Modal._draw_recording()
  elseif state.modal_type == Modal.TYPE.ADSR then
    Modal._draw_adsr()
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

      screen.text(line.text)
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

-- Draw recording modal (live waveform visualization)
function Modal._draw_recording()
  local modal_x = MODAL_MARGIN
  local modal_y = MODAL_MARGIN
  local modal_width = SCREEN_WIDTH - (MODAL_MARGIN * 2)
  local modal_height = SCREEN_HEIGHT - (MODAL_MARGIN * 2)

  -- Get live data from callback
  local info = state.recording_data and state.recording_data() or {data = {}, voltage = 0, min = -10, max = 10}
  local data = info.data or {}
  local current_voltage = info.voltage or 0
  local v_min = info.min or -10
  local v_max = info.max or 10

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

  -- Waveform area
  local wave_x = modal_x + PADDING
  local wave_y = modal_y + 12
  local wave_width = modal_width - (PADDING * 2) - 24  -- Leave room for voltage display
  local wave_height = modal_height - 24

  -- Draw zero line
  local zero_y = wave_y + wave_height * (v_max / (v_max - v_min))
  screen.level(2)
  screen.move(wave_x, zero_y)
  screen.line(wave_x + wave_width, zero_y)
  screen.stroke()

  -- Draw waveform from recorded data
  if #data > 1 then
    local max_points = wave_width
    local start_idx = math.max(1, #data - max_points + 1)
    local points_to_draw = math.min(#data, max_points)

    screen.level(8)
    for i = 1, points_to_draw do
      local data_idx = start_idx + i - 1
      local v = data[data_idx]
      local x = wave_x + (i - 1)
      local y = wave_y + wave_height * ((v_max - v) / (v_max - v_min))
      y = util.clamp(y, wave_y, wave_y + wave_height)

      if i == 1 then
        screen.move(x, y)
      else
        screen.line(x, y)
      end
    end
    screen.stroke()
  end

  -- Draw current voltage indicator (right side, bright dot)
  local current_y = wave_y + wave_height * ((v_max - current_voltage) / (v_max - v_min))
  current_y = util.clamp(current_y, wave_y, wave_y + wave_height)
  screen.level(15)
  screen.circle(wave_x + wave_width + 4, current_y, 2)
  screen.fill()

  -- Voltage text (right side)
  screen.level(12)
  screen.font_face(1)
  screen.font_size(8)
  local voltage_text = string.format("%.1fv", current_voltage)
  screen.move(wave_x + wave_width + 8, current_y + 3)
  screen.text(voltage_text)

  -- Title
  screen.level(10)
  screen.font_face(1)
  screen.font_size(8)
  local title = "RECORDING"
  screen.move(modal_x + modal_width / 2 - screen.text_extents(title) / 2, modal_y + 8)
  screen.text(title)

  -- Hint text (bottom, centered)
  if state.hint then
    screen.level(4)
    local hint_width = screen.text_extents(state.hint)
    screen.move(modal_x + modal_width / 2 - hint_width / 2, modal_y + modal_height - 4)
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

-- Draw ADSR editor modal
function Modal._draw_adsr()
  local modal_x = MODAL_MARGIN
  local modal_y = MODAL_MARGIN
  local modal_width = SCREEN_WIDTH - (MODAL_MARGIN * 2)
  local modal_height = SCREEN_HEIGHT - (MODAL_MARGIN * 2)

  -- Get live data from callback
  local info = state.adsr_data and state.adsr_data() or {a = 0.1, d = 0.2, s = 0.7, r = 0.3}
  local a = info.a or 0.1
  local d = info.d or 0.2
  local s = info.s or 0.7
  local r = info.r or 0.3
  local selected = state.adsr_selected

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

  -- ADSR envelope visualization area (shifted up to avoid label/hint overlap)
  local env_x = modal_x + PADDING + 2
  local env_y = modal_y + 12
  local env_width = modal_width - (PADDING * 2) - 4
  local env_height = 22

  -- Calculate envelope segment widths
  local sustain_time = 0.5  -- fixed display duration for sustain hold
  local raw_total = a + d + sustain_time + r
  local base_scale = env_width / raw_total

  -- Use simple proportional scaling - let the envelope shape speak for itself
  local w_attack = a * base_scale
  local w_decay = d * base_scale
  local w_sustain = sustain_time * base_scale
  local w_release = r * base_scale

  -- Scale down proportionally if total exceeds available width
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
  screen.line(x_attack, y_top)           -- Attack
  screen.line(x_decay, y_sustain)        -- Decay
  screen.line(x_sustain, y_sustain)      -- Sustain hold
  screen.line(x_release, y_bottom)       -- Release
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

    -- Selection highlight
    if is_selected then
      screen.level(15)
      local label_width = screen.text_extents(label)
      screen.rect(x - label_width/2 - 2, label_y - 7, label_width + 4, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(6)
    end

    -- Label
    local label_width = screen.text_extents(label)
    screen.move(x - label_width/2, label_y)
    screen.text(label)
  end

  -- Title
  screen.level(10)
  screen.move(modal_x + modal_width / 2 - screen.text_extents("ENVELOPE") / 2, modal_y + 8)
  screen.text("ENVELOPE")

  -- Hint text (bottom, centered)
  if state.hint then
    screen.level(4)
    local hint_width = screen.text_extents(state.hint)
    screen.move(modal_x + modal_width / 2 - hint_width / 2, modal_y + modal_height - 4)
    screen.text(state.hint)
  end
end

return Modal

-- page_state.lua
-- Shared paged-param state for live-view sections.
-- Handles page cycling, param cursor, encoder/key input, arc integration, and toast overlay.
--
-- Page definition structure (provided by each section):
--   { name = "harmony", slots = {
--       {label = "Deg", on_delta = fn, get_value = fn, threshold = 56},  -- custom
--       {label = "Sprd", param_id = "rc_composer_spread"},               -- simple param
--   }}

local PageState = {}
PageState.__index = PageState

-- Arc threshold tiers: OPTION for small discrete sets (3-12 values),
-- RANGE for large numeric ranges where full traverse needs to be practical.
PageState.THRESH_OPTION = 56
PageState.THRESH_RANGE = 20

function PageState.new(opts)
  local self = setmetatable({}, PageState)
  self.pages = opts.pages or {}
  self.page = 1
  self.cursor = 1
  self.arc_accum = {0, 0, 0, 0}
  self.overlay = nil  -- {name, value, time, duration?}
  return self
end

-- Replace pages (for dynamic page counts)
function PageState:set_pages(pages)
  self.pages = pages
  if self.page > #pages then self.page = #pages end
  self:_clamp_cursor()
end

-- Advance to next page, reset cursor and arc accumulator, fire a page name flash
function PageState:next_page()
  self.page = (self.page % #self.pages) + 1
  self.cursor = 1
  self.arc_accum = {0, 0, 0, 0}
  self.page_flash = { name = self.pages[self.page].name, time = util.time(), duration = 0.8 }
end

-- Show a toast overlay
function PageState:show_overlay(name, value, duration)
  self.overlay = {
    name = name,
    value = value,
    time = util.time(),
    duration = duration or 1.2,
  }
end

-- Draw the overlay toast if active. Returns true if drawn (caller should skip footer).
function PageState:draw_overlay()
  if not self.overlay then return false end
  local dur = self.overlay.duration
  local elapsed = util.time() - self.overlay.time
  if elapsed >= dur then
    self.overlay = nil
    return false
  end
  local fade = math.max(0, 1 - elapsed / dur)
  screen.level(math.floor(15 * fade))
  screen.move(64, 59)
  screen.text_center(self.overlay.name .. ": " .. self.overlay.value)
  return true
end

-- Draw 4-column footer with labels + values. Shows overlay if active.
function PageState:draw_footer()
  screen.level(0)
  screen.rect(0, 46, 128, 18)
  screen.fill()

  if self:draw_overlay() then return end

  local page_def = self.pages[self.page]
  if not page_def then return end

  local cols = {16, 48, 80, 112}
  local slots = page_def.slots

  -- Labels
  screen.level(5)
  for i = 1, 4 do
    local slot = slots[i]
    if slot then
      screen.move(cols[i], 55)
      screen.text_center(slot.label)
    end
  end

  -- Values (strip unit suffixes for compact footer display)
  for i = 1, 4 do
    local slot = slots[i]
    if slot then
      local val
      if slot.get_value then
        val = slot.get_value()
      elseif slot.param_id and params.lookup[slot.param_id] then
        val = params:string(slot.param_id)
      else
        val = "-"
      end
      val = tostring(val):gsub(" beats$", ""):gsub("v$", ""):gsub("%%$", "")
      screen.level(i == self.cursor and 15 or 12)
      screen.move(cols[i], 63)
      screen.text_center(val)
    end
  end
end

-- E2 moves cursor, E3 adjusts slot value
function PageState:handle_enc(n, d)
  local page_def = self.pages[self.page]
  if not page_def then return end

  if n == 2 then
    local new_cursor = util.clamp(self.cursor + d, 1, #page_def.slots)
    self.cursor = new_cursor
  elseif n == 3 then
    local slot = page_def.slots[self.cursor]
    if not slot then return end
    local direction = d > 0 and 1 or -1
    if slot.on_delta then
      slot.on_delta(direction)
    elseif slot.param_id and params.lookup[slot.param_id] then
      _seeker.arc.step_param(slot.param_id, direction, slot.step)
    end
  end
end

-- K3 cycles page
function PageState:handle_key(n, z)
  if n == 3 and z == 1 then
    self:next_page()
  end
end

-- Arc ring n accumulates delta ticks until threshold, then steps slot n
function PageState:handle_arc_delta(n, d)
  local page_def = self.pages[self.page]
  if not page_def then return end

  local slot = page_def.slots[n]
  if not slot then return end

  local threshold = slot.threshold or 40
  self.arc_accum[n] = self.arc_accum[n] + 1
  if self.arc_accum[n] < threshold then return end
  self.arc_accum[n] = 0

  local direction = d > 0 and 1 or -1

  if slot.on_delta then
    slot.on_delta(direction)
  elseif slot.param_id and params.lookup[slot.param_id] then
    _seeker.arc.step_param(slot.param_id, direction, slot.step)
  end
end

-- Arc button cycles page
function PageState:handle_arc_key(n, z)
  if z ~= 1 then return end
  self:next_page()
end

-- Reset to page 1, cursor 1
function PageState:reset()
  self.page = 1
  self.cursor = 1
  self.arc_accum = {0, 0, 0, 0}
  self.overlay = nil
end

-- Clamp page to max (useful when output type changes and page count shrinks)
function PageState:clamp_page(max)
  if self.page > max then self.page = max end
  self:_clamp_cursor()
end

---------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------

function PageState:_clamp_cursor()
  local page_def = self.pages[self.page]
  if page_def and self.cursor > #page_def.slots then
    self.cursor = #page_def.slots
  end
  if self.cursor < 1 then self.cursor = 1 end
end

function PageState:_show_slot_overlay(slot)
  local val
  if slot.get_value then
    val = slot.get_value()
  elseif slot.param_id and params.lookup[slot.param_id] then
    val = params:string(slot.param_id)
  else
    val = "?"
  end
  self:show_overlay(slot.label, tostring(val))
end

---------------------------------------------------------------
-- wire(): connect PageState to a NornsUI instance for arc/enc/key routing
---------------------------------------------------------------

function PageState:wire(norns_ui, opts)
  opts = opts or {}
  local refresh = opts.refresh or function()
    local dev = _seeker.arc
    if dev then self:update_arc(dev); dev:refresh() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end

  norns_ui.update_arc      = function(_) refresh() end
  norns_ui.handle_arc_key  = function(_, n, z) self:handle_arc_key(n, z); refresh() end
  norns_ui.handle_live_enc = function(_, n, d) self:handle_enc(n, d); refresh() end
  norns_ui.handle_live_key = function(_, n, z) self:handle_key(n, z); refresh() end
  norns_ui.cycle_page      = function(_) self:next_page(); refresh() end

  norns_ui.handle_arc_delta = function(_, n, delta)
    self:handle_arc_delta(n, delta)
    if opts.after_delta then opts.after_delta(n) end
    refresh()
  end
end

---------------------------------------------------------------
-- draw_frame(): own the full live view frame, call content via callbacks
---------------------------------------------------------------

function PageState:draw_frame(opts)
  if #self.pages <= 0 or (self.pages[1] and self.pages[1].name == "---") then
    if opts.draw_fallback then opts.draw_fallback() end
    return
  end

  if opts.draw_header then opts.draw_header() end
  if opts.draw_content then opts.draw_content(12, 33) end

  self:draw_page_indicators()
  self:draw_page_flash()
  self:draw_footer()
end

---------------------------------------------------------------
-- Chrome: page indicator bars and page-change flash
---------------------------------------------------------------

-- Vertical bars top-right. Thick for active page, thin for inactive.
function PageState:draw_page_indicators()
  local num_pages = #self.pages
  if num_pages <= 1 then return end
  for p = 1, num_pages do
    local px = 125 - (num_pages - p) * 4
    screen.level(p == self.page and 12 or 4)
    screen.rect(px, 2, p == self.page and 2 or 1, 4)
    screen.fill()
  end
end

-- Centered black-backed text fading over flash duration. Call after content, before footer.
function PageState:draw_page_flash()
  if not self.page_flash then return end
  local flash = self.page_flash
  local elapsed = util.time() - flash.time
  if elapsed >= flash.duration then
    self.page_flash = nil
    return
  end
  local fade = math.max(0, 1 - elapsed / flash.duration)
  local text_w = screen.text_extents(flash.name)
  screen.level(0)
  screen.rect(64 - text_w / 2 - 3, 22, text_w + 6, 12)
  screen.fill()
  screen.level(math.floor(12 * fade))
  screen.move(64, 31)
  screen.text_center(flash.name)
end

---------------------------------------------------------------
-- Arc primitives: reusable LED patterns for arc rings
---------------------------------------------------------------

-- Segment display for discrete options. Lights one segment of `count` total.
function PageState.draw_arc_segments(dev, ring, idx, count, brightness)
  brightness = brightness or 12
  for i = 1, 64 do dev:led(ring, i, 2) end
  local segment = math.floor(64 / count)
  local start = (idx - 1) * segment + 1
  for i = start, math.min(64, start + segment - 1) do
    dev:led(ring, i, brightness)
  end
end

-- Position needle with dimmer neighbors for continuous values.
function PageState.draw_arc_position(dev, ring, value, min_val, max_val, brightness)
  brightness = brightness or 12
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - min_val) / (max_val - min_val)
  local pos = math.floor(norm * 63) + 1
  dev:led(ring, pos, brightness)
  local dim = math.floor(brightness / 2)
  if pos > 1 then dev:led(ring, pos - 1, dim) end
  if pos < 64 then dev:led(ring, pos + 1, dim) end
end

-- Fill bar from left edge proportional to value within controlspec range.
function PageState.draw_arc_fill(dev, ring, value, spec, brightness)
  brightness = brightness or 10
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - spec.minval) / (spec.maxval - spec.minval)
  local fill_end = math.floor(norm * 64)
  for i = 1, fill_end do dev:led(ring, i, brightness) end
end

-- Auto-detect param type and render appropriate arc pattern.
function PageState.draw_param_ring(dev, ring, param_id, brightness)
  brightness = brightness or 12
  if not params.lookup[param_id] then
    for i = 1, 64 do dev:led(ring, i, 1) end
    return
  end
  local param_obj = params:lookup_param(param_id)
  local current = params:get(param_id)
  if param_obj.t == params.tOPTION then
    PageState.draw_arc_segments(dev, ring, current, #param_obj.options, brightness)
  elseif param_obj.controlspec then
    PageState.draw_arc_position(dev, ring, current, param_obj.controlspec.minval, param_obj.controlspec.maxval, brightness)
  elseif param_obj.min and param_obj.max then
    PageState.draw_arc_position(dev, ring, current, param_obj.min, param_obj.max, brightness)
  else
    for i = 1, 64 do dev:led(ring, i, 1) end
  end
end

---------------------------------------------------------------
-- Arc dispatch: iterate slots, call arc_draw or auto-render.
-- Does NOT call dev:refresh() -- caller owns that.
---------------------------------------------------------------
function PageState:update_arc(dev)
  local page_def = self.pages[self.page]
  if not page_def then return end
  for ring = 1, 4 do
    local slot = page_def.slots[ring]
    if not slot then
      for i = 1, 64 do dev:led(ring, i, 0) end
    elseif slot.arc_draw then
      slot.arc_draw(dev, ring)
    elseif slot.param_id then
      PageState.draw_param_ring(dev, ring, slot.param_id)
    else
      for i = 1, 64 do dev:led(ring, i, 1) end
    end
  end
end

return PageState

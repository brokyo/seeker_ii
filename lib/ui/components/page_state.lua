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

-- Cycle to next page, reset cursor and arc accumulator
function PageState:next_page()
  self.page = (self.page % #self.pages) + 1
  self.cursor = 1
  self.arc_accum = {0, 0, 0, 0}
  self:show_overlay(self.pages[self.page].name, self.page .. "/" .. #self.pages, 0.4)
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

  -- Values
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
      screen.level(i == self.cursor and 15 or 12)
      screen.move(cols[i], 63)
      screen.text_center(tostring(val))
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
    self:_show_slot_overlay(slot)
  end
end

-- K3 cycles page
function PageState:handle_key(n, z)
  if n == 3 and z == 1 then
    self:next_page()
  end
end

-- Arc ring n accumulates delta and steps slot n
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

  self:_show_slot_overlay(slot)
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

return PageState

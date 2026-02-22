-- cv_monitor.lua
-- Dual-mode NornsUI for eurorack CV monitoring.
-- Live view (default): full-width bars showing active output voltages.
-- Param view (K2 toggle): encoder-mapped params for selected output.
-- Uses PageState for paged param navigation (E2/E3/K3/arc).

local NornsUI = include("lib/ui/base/norns_ui")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")
local ArcPages = include("lib/modes/eurorack/arc_pages")

local CvMonitor = {}
CvMonitor.__index = CvMonitor

---------------------------------------------------------------
-- State
---------------------------------------------------------------
local cv_selected = { source = "crow", num = 1 }
local page_state = nil   -- PageState instance, rebuilt on output change
local update_arc  -- forward declaration

-- Rebuild PageState pages for current output (called on output change or type change)
local function rebuild_page_state()
  local pages = ArcPages.build_pages_for_output(cv_selected)
  if page_state then
    page_state:set_pages(pages)
  else
    page_state = PageState.new({ pages = pages })
  end
end

---------------------------------------------------------------
-- Auto-select: pick first active output
---------------------------------------------------------------
local function auto_select()
  local crow_states = {}
  local txo_tr_states = {}
  local txo_cv_states = {}
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_tr_output then
    txo_tr_states = _seeker.eurorack.txo_tr_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_cv_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end

  if params.lookup["eurorack_selected_type"] then
    local type_idx = params:get("eurorack_selected_type") or 1
    local num = params:get("eurorack_selected_number") or 1
    local source = (type_idx == 1) and "crow" or (type_idx == 2) and "txo_tr" or (type_idx == 3) and "txo_cv" or nil
    if source then
      local states = (source == "crow") and crow_states or (source == "txo_tr") and txo_tr_states or txo_cv_states
      if states[num] and states[num].active then
        cv_selected = { source = source, num = num }
        rebuild_page_state()
        return
      end
    end
  end

  for i = 1, 4 do
    if crow_states[i] and crow_states[i].active then
      cv_selected = { source = "crow", num = i }
      rebuild_page_state()
      return
    end
  end
  for i = 1, 4 do
    if txo_tr_states[i] and txo_tr_states[i].active then
      cv_selected = { source = "txo_tr", num = i }
      rebuild_page_state()
      return
    end
  end
  for i = 1, 4 do
    if txo_cv_states[i] and txo_cv_states[i].active then
      cv_selected = { source = "txo_cv", num = i }
      rebuild_page_state()
      return
    end
  end
end

---------------------------------------------------------------
-- Select output (called by grid)
---------------------------------------------------------------
function CvMonitor.select_output(source, num)
  cv_selected = { source = source, num = num }
  local type_map = { crow = 1, txo_tr = 2, txo_cv = 3 }
  if type_map[source] then
    params:set("eurorack_selected_type", type_map[source], true)
    params:set("eurorack_selected_number", num, true)
  end
  rebuild_page_state()
  if update_arc then update_arc() end
end

-- Advance to the next arc page for the current output
function CvMonitor.cycle_page()
  if page_state then
    page_state:next_page()
    if update_arc then update_arc() end
    if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
  end
end

-- Get current selection (for grid to detect re-tap)
function CvMonitor.get_selected()
  return cv_selected
end

-- Generic voltage bar (compact strip for non-focused outputs)
local function draw_voltage_bar(state, y_top, h, level_bg, level_marker)
  screen.level(level_bg)
  screen.rect(0, y_top, 128, h)
  screen.fill()
  if state.min and state.max and state.current then
    local range = state.max - state.min
    if range <= 0 then range = 1 end
    local normalized = util.clamp((state.current - state.min) / range, 0, 1)
    local marker_x = math.floor(normalized * 126)
    screen.level(level_marker)
    screen.rect(marker_x, y_top, 2, h)
    screen.fill()
  end
end

---------------------------------------------------------------
-- Collect outputs into focused + others
---------------------------------------------------------------
local function collect_outputs()
  local crow_states = {}
  local txo_cv_states = {}
  local txo_tr_states = {}
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_cv_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_tr_output then
    txo_tr_states = _seeker.eurorack.txo_tr_output.get_cv_states()
  end

  local focused = nil
  local others = {}

  local function collect(states, source, label_prefix, include_selected_inactive)
    for i = 1, 4 do
      local state = states[i]
      local is_selected = (source == cv_selected.source and i == cv_selected.num)
      if state and (state.active or (include_selected_inactive and is_selected)) then
        local entry = { label = label_prefix .. i, state = state, source = source, num = i }
        if is_selected then
          focused = entry
        else
          table.insert(others, entry)
        end
      end
    end
  end

  collect(crow_states, "crow", "C", true)
  collect(txo_tr_states, "txo_tr", "TR", true)
  collect(txo_cv_states, "txo_cv", "CV", true)

  return focused, others
end

---------------------------------------------------------------
-- Live view: type-specific viz for focused, compact bars for others
---------------------------------------------------------------
local function draw_live()
  local has_pages = page_state and #page_state.pages > 0 and page_state.pages[1].name ~= "---"

  if not has_pages then
    screen.level(8)
    screen.rect(0, 52, 128, 12)
    screen.fill()
    screen.level(0)
    screen.move(2, 60)
    screen.text("Eurorack Config")
    return
  end

  local focused, others = collect_outputs()

  if not focused and #others == 0 then
    screen.level(4)
    screen.move(64, 28)
    screen.text_center("No active outputs")
    page_state:draw_page_indicators()
    page_state:draw_page_flash()
    page_state:draw_footer()
    return
  end

  -- Layout: focused gets main area, others get compact strip below
  local MAIN_TOP = 9
  local MAIN_BOTTOM = #others > 0 and 38 or 45
  local COMPACT_TOP = MAIN_BOTTOM + 1
  local COMPACT_BOTTOM = 45

  if focused then
    local state = focused.state
    local main_h = MAIN_BOTTOM - MAIN_TOP

    -- Header label
    screen.level(12)
    screen.move(2, 7)
    screen.text(focused.label .. " " .. (state.type or "---"))

    -- Type-specific visualization (shared from arc_pages)
    ArcPages.draw_output_viz(state, MAIN_TOP, main_h)
  end

  -- Compact bars for non-focused outputs
  if #others > 0 then
    local compact_h = COMPACT_BOTTOM - COMPACT_TOP
    local row_h = math.max(3, math.floor(compact_h / #others))

    for idx, entry in ipairs(others) do
      local y = COMPACT_TOP + (idx - 1) * row_h
      local h = row_h - 1
      draw_voltage_bar(entry.state, y, h, 3, 10)

      if h >= 6 then
        screen.level(5)
        screen.move(1, y + h)
        screen.text(entry.label)
      end
    end
  end

  page_state:draw_page_indicators()
  page_state:draw_page_flash()
  page_state:draw_footer()
end

---------------------------------------------------------------
-- Screensaver: type-specific viz for focused, compact bars for others
---------------------------------------------------------------
function CvMonitor.draw_screensaver()
  local focused, others = collect_outputs()
  -- In screensaver, only show active outputs (not inactive selected)
  if focused and not focused.state.active then focused = nil end

  if not focused and #others == 0 then return end

  local MAIN_TOP = 2
  local MAIN_BOTTOM = #others > 0 and 48 or 60
  local COMPACT_TOP = MAIN_BOTTOM + 1
  local COMPACT_BOTTOM = 60

  if focused then
    local state = focused.state
    local main_h = MAIN_BOTTOM - MAIN_TOP

    -- Type-specific visualization (shared from arc_pages)
    ArcPages.draw_output_viz(state, MAIN_TOP, main_h)
  end

  if #others > 0 then
    local compact_h = COMPACT_BOTTOM - COMPACT_TOP
    local row_h = math.max(3, math.floor(compact_h / #others))

    for idx, entry in ipairs(others) do
      local y = COMPACT_TOP + (idx - 1) * row_h
      local h = row_h - 1
      draw_voltage_bar(entry.state, y, h, 3, 8)
    end
  end
end

---------------------------------------------------------------
-- Arc display
---------------------------------------------------------------
update_arc = function()
  local dev = _seeker.arc
  if not dev or not page_state then return end
  page_state:update_arc(dev)
  dev:refresh()
end

---------------------------------------------------------------
-- Arc delta/key handlers (delegate to PageState, with type-change clamping)
---------------------------------------------------------------
local function handle_arc_delta(n, delta)
  if not page_state then return end

  local page_def = page_state.pages[page_state.page]
  if not page_def then return end
  local slot = page_def.slots[n]
  if not slot or not slot.param_id then return end

  -- Check if this param is a type/mode selector that could change page count
  local prefix = cv_selected.source .. "_" .. cv_selected.num .. "_"
  local is_type_change = (slot.param_id == prefix .. "type")

  -- Use PageState's accumulator
  page_state:handle_arc_delta(n, delta)

  -- After a type/mode change, rebuild pages since the output type may have changed
  if is_type_change then
    rebuild_page_state()
  end

  update_arc()
  if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

local function handle_arc_key(n, z)
  if not page_state then return end
  page_state:handle_arc_key(n, z)
  update_arc()
  if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
end

---------------------------------------------------------------
-- NornsUI: dual-mode screen
---------------------------------------------------------------
local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "EURORACK_CONFIG",
    name = "CV Monitor",
    description = Descriptions.EURORACK_CONFIG or "Live voltage monitoring for crow and TXO CV outputs",
    params = {},
  })

  norns_ui.needs_playback_refresh = true
  norns_ui.live_view_enabled = true

  norns_ui.rebuild_params = function(self)
    self.params = {}
    if not cv_selected then return end

    params:set("eurorack_selected_number", cv_selected.num, true)

    if cv_selected.source == "crow" then
      local component_screen = _seeker.eurorack.crow_output.screen
      component_screen:rebuild_params()
      self.params = component_screen.params
    elseif cv_selected.source == "txo_cv" then
      local component_screen = _seeker.eurorack.txo_cv_output.screen
      component_screen:rebuild_params()
      self.params = component_screen.params
    elseif cv_selected.source == "txo_tr" then
      local component_screen = _seeker.eurorack.txo_tr_output.screen
      component_screen:rebuild_params()
      self.params = component_screen.params
    end

    if params.lookup["sync_all_eurorack_clocks"] then
      table.insert(self.params, { separator = true, title = "Actions" })
      table.insert(self.params, { id = "sync_all_eurorack_clocks", is_action = true })
    end
  end

  norns_ui.draw_live = function(self) draw_live() end
  norns_ui.update_arc = function(self) update_arc() end
  norns_ui.handle_arc_delta = function(self, n, delta) handle_arc_delta(n, delta) end
  norns_ui.handle_arc_key = function(self, n, z) handle_arc_key(n, z) end
  norns_ui.on_enter = function(self) auto_select() end

  -- E2/E3 in live view: PageState handles cursor + param adjustment
  norns_ui.handle_live_enc = function(self, n, d)
    if not page_state then return end
    page_state:handle_enc(n, d)
    update_arc()
    _seeker.screen_ui.set_needs_redraw()
  end

  -- K3 in live view: cycle page
  norns_ui.handle_live_key = function(self, n, z)
    if n == 3 and z == 1 and page_state then
      page_state:next_page()
      update_arc()
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return norns_ui
end

function CvMonitor.init()
  page_state = PageState.new({ pages = {{ name = "---", slots = {} }} })
  CvMonitor.screen = create_screen_ui()
  return CvMonitor
end

return CvMonitor

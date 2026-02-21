-- cv_monitor.lua
-- Dual-mode NornsUI for eurorack CV monitoring.
-- Live view (default): full-width bars showing active output voltages.
-- Param view (K2 toggle): encoder-mapped params for selected output.
-- Uses PageState for paged param navigation (E2/E3/K3/arc).

local NornsUI = include("lib/ui/base/norns_ui")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")

local CvMonitor = {}
CvMonitor.__index = CvMonitor

---------------------------------------------------------------
-- State
---------------------------------------------------------------
local cv_selected = { source = "crow", num = 1 }
local page_state = nil   -- PageState instance, rebuilt on output change
local update_arc  -- forward declaration

---------------------------------------------------------------
-- Short display names for footer labels (max ~5 chars)
---------------------------------------------------------------
local PARAM_SHORT_NAMES = {
  -- Shared
  Interval       = "Intvl",
  Modifier       = "Mod",
  Offset         = "Offst",
  -- Crow config
  Category       = "Cat",
  Mode           = "Mode",
  -- Gate types
  Voltage        = "Volts",
  ["Gate Length"] = "Gate",
  Length          = "Len",
  Hits           = "Hits",
  Rotation       = "Rot",
  -- Burst
  ["Burst Count"]  = "Count",
  ["Burst Shape"]  = "Shape",
  ["Burst Window"] = "Wndw",
  ["Burst Time"]   = "Time",
  -- LFO
  ["CV Shape"]   = "Shape",
  ["CV Min"]     = "Min",
  ["CV Max"]     = "Max",
  -- Envelope
  ["Envelope Mode"]  = "Mode",
  ["Envelope Shape"] = "Shape",
  ["Max Voltage"]    = "Volts",
  Duration           = "Dur",
  Attack             = "Atk",
  Decay              = "Dec",
  ["Sustain Level"]  = "Sus",
  Release            = "Rel",
  -- Knob Recorder
  Sensitivity        = "Sens",
  ["Loop Crossfade"] = "XFade",
  -- Random
  ["Crow Input"]     = "Input",
  Quantize           = "Quant",
  ["Min Value"]      = "Min",
  ["Max Value"]      = "Max",
  ["Step Size"]      = "Step",
  Steps              = "Steps",
  Loops              = "Loops",
  -- TXO CV (already short: Type, Shape, Morph, Depth, Phase, Rect, Slew, Min, Max)
}

---------------------------------------------------------------
-- Output resolution helpers
---------------------------------------------------------------

local function resolve_cv_output(selected)
  local states, prefix
  if selected.source == "crow" then
    prefix = "crow_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.crow_output and
             _seeker.eurorack.crow_output.get_cv_states() or {}
  elseif selected.source == "txo_tr" then
    prefix = "txo_tr_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.txo_tr_output and
             _seeker.eurorack.txo_tr_output.get_cv_states() or {}
  else
    prefix = "txo_cv_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.txo_cv_output and
             _seeker.eurorack.txo_cv_output.get_cv_states() or {}
  end
  local state = states[selected.num]
  if not state or not state.type then return nil, nil end
  return state, prefix
end

-- Arc page definitions per output type.
-- Each page: { label, r1, r2, r3, r4 } where r1-r4 are optional param suffixes.
local ARC_PAGES = {
  crow = {
    CLK = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "clock_voltage", r2 = "clock_length" },
    },
    PAT = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "pattern_length", r2 = "pattern_hits", r3 = "gate_length", r4 = "pattern_voltage" },
    },
    EUC = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset", r4 = "euclidean_voltage" },
      { label = "perform", r1 = "euclidean_length", r2 = "euclidean_hits", r3 = "euclidean_rotation", r4 = "gate_length" },
    },
    BST = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "burst_count", r2 = "burst_shape", r3 = "burst_time", r4 = "burst_voltage" },
    },
    LFO = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "lfo_min", r2 = "lfo_max", r3 = "lfo_shape" },
    },
    ENV = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",   r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "envelope", r1 = "envelope_attack", r2 = "envelope_decay", r3 = "envelope_sustain", r4 = "envelope_release" },
      { label = "shape",    r1 = "envelope_mode", r2 = "envelope_shape", r3 = "envelope_voltage", r4 = "envelope_duration" },
    },
    KR = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "perform", r1 = "knob_sensitivity", r2 = "knob_crossfade" },
    },
    RW = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset", r4 = "random_walk_mode" },
      { label = "perform", r1 = "random_walk_min", r2 = "random_walk_max", r3 = "random_walk_slew", r4 = "random_walk_shape" },
    },
    CR = {
      { label = "config",  r1 = "category", r2 = "mode", r3 = "clocked_random_trigger" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "clocked_random_min", r2 = "clocked_random_max", r3 = "clocked_random_quantize", r4 = "clocked_random_shape" },
    },
    LR = {
      { label = "config",  r1 = "category", r2 = "mode" },
      { label = "timing",    r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform",   r1 = "looped_random_min", r2 = "looped_random_max", r3 = "looped_random_quantize", r4 = "looped_random_shape" },
      { label = "structure", r1 = "looped_random_steps", r2 = "looped_random_loops" },
    },
  },
  txo_tr = {
    CLK = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "clock_length" },
    },
    PAT = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "pattern_length", r2 = "pattern_hits", r3 = "gate_length" },
    },
    EUC = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "euclidean_length", r2 = "euclidean_hits", r3 = "euclidean_rotation", r4 = "gate_length" },
    },
    BST = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "burst_count", r2 = "burst_time", r3 = "burst_shape" },
    },
  },
  txo_cv = {
    LFO = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "depth", r2 = "offset", r3 = "shape", r4 = "rect" },
      { label = "detail",  r1 = "morph", r2 = "phase" },
    },
    RW = {
      { label = "config",  r1 = "type" },
      { label = "timing",  r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "perform", r1 = "random_walk_min", r2 = "random_walk_max", r3 = "random_walk_slew", r4 = "random_walk_mode" },
    },
    ENV = {
      { label = "config",  r1 = "type" },
      { label = "timing",   r1 = "clock_interval", r2 = "clock_modifier", r3 = "clock_offset" },
      { label = "envelope", r1 = "envelope_attack", r2 = "envelope_decay", r3 = "envelope_sustain", r4 = "envelope_release" },
      { label = "shape",    r1 = "envelope_mode", r2 = "envelope_voltage", r3 = "envelope_duration" },
    },
  },
}

---------------------------------------------------------------
-- Build PageState pages from ARC_PAGES for the current output
---------------------------------------------------------------
local function build_pages_for_output(selected)
  local state, prefix = resolve_cv_output(selected)
  if not state or not prefix then
    return {{ name = "---", slots = {} }}
  end

  local source_pages = ARC_PAGES[selected.source]
  if not source_pages then return {{ name = "---", slots = {} }} end
  local type_pages = source_pages[state.type]
  if not type_pages then return {{ name = "---", slots = {} }} end

  local pages = {}
  for _, page_def in ipairs(type_pages) do
    local slots = {}
    local ring_keys = {"r1", "r2", "r3", "r4"}
    for _, rk in ipairs(ring_keys) do
      if page_def[rk] then
        local param_id = prefix .. page_def[rk]
        local short_label = "-"
        if params.lookup[param_id] then
          local param_obj = params:lookup_param(param_id)
          short_label = PARAM_SHORT_NAMES[param_obj.name] or param_obj.name or param_id
        end
        -- Determine threshold: options get coarser threshold
        local threshold = 20
        if params.lookup[param_id] then
          local param_obj = params:lookup_param(param_id)
          if param_obj.t == params.tOPTION then threshold = 40 end
        end
        table.insert(slots, {
          label = short_label,
          param_id = param_id,
          threshold = threshold,
        })
      end
    end
    table.insert(pages, { name = page_def.label, slots = slots })
  end

  return pages
end

-- Rebuild PageState pages for current output (called on output change or type change)
local function rebuild_page_state()
  local pages = build_pages_for_output(cv_selected)
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

-- Cycle to next page (called by grid on tap of already-selected output)
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

---------------------------------------------------------------
-- Live view drawing
---------------------------------------------------------------
local function draw_live()
  local page_count = page_state and #page_state.pages or 1
  local current_page = page_state and page_state.page or 1

  -- Header: selected output + type, page label, K2 hint
  local sel_state, _ = resolve_cv_output(cv_selected)
  local source_short = cv_selected.source == "crow" and "C"
    or cv_selected.source == "txo_cv" and "CV" or "TR"
  local header = source_short .. cv_selected.num
  if sel_state then header = header .. " " .. sel_state.type end

  screen.level(12)
  screen.move(2, 6)
  screen.text(header)

  local page_name = page_state and page_state.pages[current_page] and page_state.pages[current_page].name or ""
  screen.level(5)
  screen.move(64, 6)
  screen.text_center(page_name .. " " .. current_page .. "/" .. page_count)

  screen.level(3)
  screen.move(126, 6)
  screen.text_right("K2")

  -- Voltage bars
  local BAR_TOP = 9
  local BAR_BOTTOM = 45

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

  local active_outputs = {}

  local function collect(states, source, label_prefix)
    for i = 1, 4 do
      local state = states[i]
      local is_selected = (source == cv_selected.source and i == cv_selected.num)
      if state and (state.active or is_selected) then
        table.insert(active_outputs, { label = label_prefix .. i, state = state, source = source, num = i })
      end
    end
  end

  collect(crow_states, "crow", "C")
  collect(txo_tr_states, "txo_tr", "TR")
  collect(txo_cv_states, "txo_cv", "CV")

  if #active_outputs == 0 then
    screen.level(4)
    screen.move(64, 28)
    screen.text_center("No active outputs")
  else
    local bar_area = BAR_BOTTOM - BAR_TOP
    local row_height = math.floor(bar_area / #active_outputs)
    local show_value = row_height >= 14

    for idx, entry in ipairs(active_outputs) do
      local state = entry.state
      local y_top = BAR_TOP + (idx - 1) * row_height
      local bar_h = row_height - 1
      local is_selected = (entry.source == cv_selected.source and entry.num == cv_selected.num)

      screen.level(is_selected and 6 or 4)
      screen.rect(0, y_top, 128, bar_h)
      screen.fill()

      if state.min and state.max and state.current then
        local range = state.max - state.min
        if range <= 0 then range = 1 end
        local normalized = util.clamp((state.current - state.min) / range, 0, 1)
        local marker_x = math.floor(normalized * 126)
        screen.level(15)
        screen.rect(marker_x, y_top, 2, bar_h)
        screen.fill()
      end

      screen.level(is_selected and 12 or 7)
      screen.move(2, y_top + bar_h - 1)
      screen.text(entry.label .. " " .. (state.type or "---"))

      if show_value and state.current then
        screen.level(is_selected and 10 or 5)
        screen.move(126, y_top + bar_h - 1)
        screen.text_right(string.format("%.1fv", state.current))
      end
    end
  end

  -- Footer: PageState handles overlay and 4-column labels
  if page_state and #page_state.pages > 0 and page_state.pages[1].name ~= "---" then
    page_state:draw_footer()
  end
end

---------------------------------------------------------------
-- Arc display
---------------------------------------------------------------
update_arc = function()
  local dev = _seeker.arc
  if not dev then return end
  if not page_state then return end

  local page_def = page_state.pages[page_state.page]
  if not page_def then return end

  local function draw_param_ring(ring, slot)
    if not slot or not slot.param_id or not params.lookup[slot.param_id] then
      for i = 1, 64 do dev:led(ring, i, 1) end
      return
    end
    for i = 1, 64 do dev:led(ring, i, 2) end
    local param_obj = params:lookup_param(slot.param_id)
    local current = params:get(slot.param_id)

    if param_obj.t == params.tOPTION then
      local total = #param_obj.options
      local segment = math.floor(64 / total)
      local start = (current - 1) * segment + 1
      for i = start, math.min(64, start + segment - 1) do
        dev:led(ring, i, 12)
      end
    elseif param_obj.controlspec then
      local spec = param_obj.controlspec
      local normalized = util.clamp((current - spec.minval) / (spec.maxval - spec.minval), 0, 1)
      local pos = math.floor(normalized * 63) + 1
      dev:led(ring, pos, 12)
      if pos > 1 then dev:led(ring, pos - 1, 6) end
      if pos < 64 then dev:led(ring, pos + 1, 6) end
    end
  end

  for ring = 1, 4 do
    draw_param_ring(ring, page_def.slots[ring])
  end

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
  local is_type_change = (slot.param_id == prefix .. "type" or
                          slot.param_id == prefix .. "mode" or
                          slot.param_id == prefix .. "category")

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
    params = {}
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

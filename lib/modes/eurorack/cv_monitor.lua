-- cv_monitor.lua
-- Dual-mode NornsUI for eurorack CV monitoring.
-- Live view (default): full-width bars showing active output voltages.
-- Param view (K2 toggle): encoder-mapped params for selected output.
-- Registered as the EURORACK_CONFIG section in screen_router.

local NornsUI = include("lib/ui/base/norns_ui")
local Descriptions = include("lib/ui/component_descriptions")

local CvMonitor = {}
CvMonitor.__index = CvMonitor

---------------------------------------------------------------
-- State
---------------------------------------------------------------
local cv_selected = { source = "crow", num = 1 }
local arc_overlay = nil
local arc_accum = {0, 0, 0, 0}
local arc_page = 1  -- index into ARC_PAGES for the selected output type
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

-- Resolve selected output's state and param prefix
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
-- Each page: { label, r1, r2, r3, r4 } where r1-r4 are optional param suffixes,
-- prepended with the output prefix to form full param IDs.
-- Page 1 is always "config" — output type and mode selectors.
-- Subsequent pages are grouped by function: timing, then performable params.
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

local function get_page_count(selected)
  local state, _ = resolve_cv_output(selected)
  if not state then return 1 end
  local source_pages = ARC_PAGES[selected.source]
  if not source_pages then return 1 end
  local type_pages = source_pages[state.type]
  return type_pages and #type_pages or 1
end

local function resolve_arc_params(selected, page)
  local state, prefix = resolve_cv_output(selected)
  if not state then return nil end

  local source_pages = ARC_PAGES[selected.source]
  if not source_pages then return nil end
  local type_pages = source_pages[state.type]
  if not type_pages then return nil end

  local page_def = type_pages[page]
  if not page_def then return nil end

  return {
    r1 = page_def.r1 and (prefix .. page_def.r1) or nil,
    r2 = page_def.r2 and (prefix .. page_def.r2) or nil,
    r3 = page_def.r3 and (prefix .. page_def.r3) or nil,
    r4 = page_def.r4 and (prefix .. page_def.r4) or nil,
    label = page_def.label,
  }
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

  -- Try current eurorack selection
  if params.lookup["eurorack_selected_type"] then
    local type_idx = params:get("eurorack_selected_type") or 1
    local num = params:get("eurorack_selected_number") or 1
    local source = (type_idx == 1) and "crow" or (type_idx == 2) and "txo_tr" or (type_idx == 3) and "txo_cv" or nil
    if source then
      local states = (source == "crow") and crow_states or (source == "txo_tr") and txo_tr_states or txo_cv_states
      if states[num] and states[num].active then
        cv_selected = { source = source, num = num }
        return
      end
    end
  end

  for i = 1, 4 do
    if crow_states[i] and crow_states[i].active then
      cv_selected = { source = "crow", num = i }
      return
    end
  end
  for i = 1, 4 do
    if txo_tr_states[i] and txo_tr_states[i].active then
      cv_selected = { source = "txo_tr", num = i }
      return
    end
  end
  for i = 1, 4 do
    if txo_cv_states[i] and txo_cv_states[i].active then
      cv_selected = { source = "txo_cv", num = i }
      return
    end
  end
end

---------------------------------------------------------------
-- Select output (called by grid)
---------------------------------------------------------------
function CvMonitor.select_output(source, num)
  cv_selected = { source = source, num = num }
  -- Sync eurorack params so rebuild_params can delegate correctly
  local type_map = { crow = 1, txo_tr = 2, txo_cv = 3 }
  if type_map[source] then
    params:set("eurorack_selected_type", type_map[source], true)
    params:set("eurorack_selected_number", num, true)
  end
  -- Reset to page 1 and update arc display
  arc_page = 1
  if update_arc then update_arc() end
end

---------------------------------------------------------------
-- Live view drawing
---------------------------------------------------------------
local function draw_live()
  -- Arc mapping drives both the page label in the header and the param footer
  local mapping = resolve_arc_params(cv_selected, arc_page)
  local page_count = get_page_count(cv_selected)

  -- Header: selected output + type, arc page label, K2 hint
  local sel_state, _ = resolve_cv_output(cv_selected)
  local source_short = cv_selected.source == "crow" and "C"
    or cv_selected.source == "txo_cv" and "CV" or "TR"
  local header = source_short .. cv_selected.num
  if sel_state then header = header .. " " .. sel_state.type end

  screen.level(12)
  screen.move(2, 6)
  screen.text(header)

  local page_label = mapping and mapping.label or ""
  screen.level(5)
  screen.move(64, 6)
  screen.text_center(page_label .. " " .. arc_page .. "/" .. page_count)

  screen.level(3)
  screen.move(126, 6)
  screen.text_right("K2")

  -- Voltage bars (constrained to middle band)
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
  local selected_included = false

  local function collect(states, source, label_prefix)
    for i = 1, 4 do
      local state = states[i]
      local is_selected = (source == cv_selected.source and i == cv_selected.num)
      if state and (state.active or is_selected) then
        table.insert(active_outputs, { label = label_prefix .. i, state = state, source = source, num = i })
        if is_selected then selected_included = true end
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

  -- Footer: 4-column arc ring map with param names and current values
  if mapping then
    screen.level(0)
    screen.rect(0, 46, 128, 18)
    screen.fill()

    local col_w = 32
    local rings = {mapping.r1, mapping.r2, mapping.r3, mapping.r4}
    for i = 1, 4 do
      local param_id = rings[i]
      local cx = (i - 1) * col_w + col_w / 2
      if param_id and params.lookup[param_id] then
        local param_obj = params:lookup_param(param_id)
        local short_name = PARAM_SHORT_NAMES[param_obj.name] or param_obj.name or param_id
        screen.level(5)
        screen.move(cx, 55)
        screen.text_center(short_name)

        local val_str = tostring(params:string(param_id))
        if #val_str > 5 then val_str = val_str:sub(1, 5) end
        screen.level(12)
        screen.move(cx, 63)
        screen.text_center(val_str)
      else
        screen.level(2)
        screen.move(cx, 55)
        screen.text_center("-")
      end
    end
  end
end

---------------------------------------------------------------
-- Arc display
---------------------------------------------------------------
update_arc = function()
  local dev = _seeker.arc
  if not dev then return end

  local mapping = resolve_arc_params(cv_selected, arc_page)

  local function draw_param_ring(ring, param_id)
    if not param_id or not params.lookup[param_id] then
      for i = 1, 64 do dev:led(ring, i, 1) end
      return
    end
    for i = 1, 64 do dev:led(ring, i, 2) end
    local param_obj = params:lookup_param(param_id)
    local current = params:get(param_id)

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

  if mapping then
    draw_param_ring(1, mapping.r1)
    draw_param_ring(2, mapping.r2)
    draw_param_ring(3, mapping.r3)
    draw_param_ring(4, mapping.r4)
  else
    for ring = 1, 4 do
      for i = 1, 64 do dev:led(ring, i, 1) end
    end
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Arc delta/key handlers
---------------------------------------------------------------
-- Ticks needed per step for each ring. Options use more ticks (coarse), controls use fewer (fine).
local ARC_TICKS_PER_STEP = {
  option = 40,
  control = 20,
}

local function handle_arc_delta(n, delta)
  local mapping = resolve_arc_params(cv_selected, arc_page)
  if not mapping then return end

  local param_id
  if n == 1 then param_id = mapping.r1
  elseif n == 2 then param_id = mapping.r2
  elseif n == 3 then param_id = mapping.r3
  elseif n == 4 then param_id = mapping.r4
  end
  if not param_id or not params.lookup[param_id] then return end

  local param_obj = params:lookup_param(param_id)
  local is_option = (param_obj.t == params.tOPTION)
  local threshold = is_option and ARC_TICKS_PER_STEP.option or ARC_TICKS_PER_STEP.control

  arc_accum[n] = arc_accum[n] + 1
  if arc_accum[n] >= threshold then
    arc_accum[n] = 0
    local direction = delta > 0 and 1 or -1
    local current = params:get(param_id)

    if is_option then
      params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
    elseif param_obj.controlspec then
      local step = math.max(param_obj.controlspec.step, 0.1)
      local new_val = current + direction * step
      new_val = util.clamp(new_val, param_obj.controlspec.minval, param_obj.controlspec.maxval)
      params:set(param_id, new_val)
    elseif param_obj.min and param_obj.max then
      params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
    end

    -- Changing output type/mode may alter page count; clamp to stay in bounds
    local prefix = cv_selected.source .. "_" .. cv_selected.num .. "_"
    if param_id == prefix .. "type" or param_id == prefix .. "mode" or param_id == prefix .. "category" then
      arc_page = math.min(arc_page, get_page_count(cv_selected))
    end

    arc_overlay = {
      name = param_obj.name or param_id,
      value = tostring(params:string(param_id)),
      time = util.time()
    }
    update_arc()
  end
end

local function handle_arc_key(n, z)
  if z ~= 1 then return end
  local page_count = get_page_count(cv_selected)
  arc_page = (arc_page % page_count) + 1
  update_arc()
end

-- Expose for arc controller and screensaver routing
CvMonitor.handle_arc_delta = handle_arc_delta
CvMonitor.handle_arc_key = handle_arc_key
CvMonitor.update_arc = update_arc

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

  -- Opt-in to 30fps redraws (voltage meters need continuous refresh)
  norns_ui.needs_playback_refresh = true

  -- Live view is the default
  norns_ui.state.live_view = true

  -- Rebuild param list by delegating to the selected output's component screen
  norns_ui.rebuild_params = function(self)
    self.params = {}
    if not cv_selected then return end

    -- Set eurorack_selected_number so output component reads the right output
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

    -- Append sync action
    if params.lookup["sync_all_eurorack_clocks"] then
      table.insert(self.params, { separator = true, title = "Actions" })
      table.insert(self.params, { id = "sync_all_eurorack_clocks", is_action = true })
    end
  end

  norns_ui.draw = function(self)
    screen.clear()
    if self.state.live_view then
      draw_live()
    else
      self:_draw_standard_ui()
    end
    screen.update()
  end

  norns_ui.handle_key = function(self, n, z)
    if n == 2 then
      if z == 1 then
        self.state.live_view = not self.state.live_view
        if not self.state.live_view then
          self:rebuild_params()
          if _seeker.arc then
            _seeker.arc.clear_display()
            _seeker.arc.new_section(self.params)
            _seeker.arc.sync_display()
          end
        else
          if _seeker.arc then
            _seeker.arc.set_display(function() update_arc() end)
          end
        end
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end

    -- K3 and other keys only route to NornsUI in param view
    if not self.state.live_view then
      NornsUI.handle_key(self, n, z)
    end
  end

  norns_ui.handle_enc = function(self, n, d)
    if self.state.live_view then
      -- Encoders E1-E3 map to arc rings 1-3 of current page
      local mapping = resolve_arc_params(cv_selected, arc_page)
      if not mapping then return end

      local param_id
      if n == 1 then param_id = mapping.r1
      elseif n == 2 then param_id = mapping.r2
      elseif n == 3 then param_id = mapping.r3
      end
      if not param_id or not params.lookup[param_id] then return end

      local param_obj = params:lookup_param(param_id)
      local current = params:get(param_id)
      local direction = d > 0 and 1 or -1

      if param_obj.behavior == "toggle" then
        params:set(param_id, current == 0 and 1 or 0)
      elseif param_obj.t == params.tOPTION then
        params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
      elseif param_obj.controlspec then
        local step = math.max(param_obj.controlspec.step, 0.1)
        params:set(param_id, util.clamp(current + direction * step,
          param_obj.controlspec.minval, param_obj.controlspec.maxval))
      elseif param_obj.min and param_obj.max then
        params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
      end

      arc_overlay = {
        name = param_obj.name or param_id,
        value = tostring(params:string(param_id)),
        time = util.time()
      }
      update_arc()
      return
    end
    self:handle_enc_default(n, d)
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    auto_select()
    self:rebuild_params()
    original_enter(self)
    self.state.live_view = true
    if _seeker.arc then
      _seeker.arc.set_display(function() update_arc() end)
    end
  end

  local original_exit = norns_ui.exit
  norns_ui.exit = function(self)
    if _seeker.arc then
      _seeker.arc.clear_display()
    end
    original_exit(self)
  end

  return norns_ui
end

function CvMonitor.init()
  CvMonitor.screen = create_screen_ui()
  return CvMonitor
end

return CvMonitor

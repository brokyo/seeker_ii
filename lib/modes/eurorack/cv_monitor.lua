-- cv_monitor.lua
-- Dual-mode NornsUI for eurorack CV monitoring.
-- Live view (default): full-width bars showing active output voltages.
-- Param view (K2 toggle): encoder-mapped params for selected output.
-- Replaces EURORACK_CONFIG section in screen_router.

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
  else
    prefix = "txo_cv_" .. selected.num .. "_"
    states = _seeker.eurorack and _seeker.eurorack.txo_cv_output and
             _seeker.eurorack.txo_cv_output.get_cv_states() or {}
  end
  local state = states[selected.num]
  if not state or not state.active then return nil, nil end
  return state, prefix
end

-- Arc ring param mapping: interval, range low, range high
local function resolve_arc_params(selected)
  local state, prefix = resolve_cv_output(selected)
  if not state then return nil end

  local r1, r2, r3
  if state.type ~= "CR" then
    r1 = prefix .. "clock_interval"
  end

  if selected.source == "crow" then
    if state.type == "CLK" then      r3 = prefix .. "clock_voltage"
    elseif state.type == "PAT" then  r3 = prefix .. "pattern_voltage"
    elseif state.type == "EUC" then  r3 = prefix .. "euclidean_voltage"
    elseif state.type == "BST" then  r3 = prefix .. "burst_voltage"
    elseif state.type == "LFO" then  r2 = prefix .. "lfo_min"; r3 = prefix .. "lfo_max"
    elseif state.type == "ENV" then  r3 = prefix .. "envelope_voltage"
    elseif state.type == "RW" then   r2 = prefix .. "random_walk_min"; r3 = prefix .. "random_walk_max"
    elseif state.type == "CR" then   r2 = prefix .. "clocked_random_min"; r3 = prefix .. "clocked_random_max"
    elseif state.type == "LR" then   r2 = prefix .. "looped_random_min"; r3 = prefix .. "looped_random_max"
    end
  else
    if state.type == "LFO" then      r2 = prefix .. "depth"; r3 = prefix .. "offset"
    elseif state.type == "RW" then   r2 = prefix .. "random_walk_min"; r3 = prefix .. "random_walk_max"
    elseif state.type == "ENV" then  r3 = prefix .. "envelope_voltage"
    end
  end

  return { r1 = r1, r2 = r2, r3 = r3 }
end

-- Per-type encoder param suffixes
local CROW_ENC_SUFFIXES = {
  CLK = {"_clock_length"},
  PAT = {"_pattern_length", "_pattern_hits", "_gate_length"},
  EUC = {"_euclidean_length", "_euclidean_hits", "_euclidean_rotation"},
  BST = {"_burst_count"},
  LFO = {"_lfo_shape"},
  ENV = {"_envelope_mode", "_envelope_shape"},
  RW  = {"_random_walk_mode", "_random_walk_shape"},
  CR  = {"_clocked_random_quantize", "_clocked_random_shape"},
  LR  = {"_looped_random_quantize", "_looped_random_shape", "_looped_random_steps"},
}

local TXO_ENC_SUFFIXES = {
  LFO = {"_shape", "_rect"},
  RW  = {"_random_walk_mode"},
  ENV = {"_envelope_mode"},
}

---------------------------------------------------------------
-- Auto-select: pick first active output
---------------------------------------------------------------
local function auto_select()
  local crow_states = {}
  local txo_states = {}
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end

  -- Try current eurorack selection
  if params.lookup["eurorack_selected_type"] then
    local type_idx = params:get("eurorack_selected_type") or 1
    local num = params:get("eurorack_selected_number") or 1
    local source = (type_idx == 1) and "crow" or (type_idx == 3) and "txo_cv" or nil
    if source then
      local states = (source == "crow") and crow_states or txo_states
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
    if txo_states[i] and txo_states[i].active then
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
end

---------------------------------------------------------------
-- Live view drawing
---------------------------------------------------------------
local function draw_live()
  local crow_states = {}
  local txo_states = {}
  if _seeker.eurorack and _seeker.eurorack.crow_output then
    crow_states = _seeker.eurorack.crow_output.get_cv_states()
  end
  if _seeker.eurorack and _seeker.eurorack.txo_cv_output then
    txo_states = _seeker.eurorack.txo_cv_output.get_cv_states()
  end

  local active_outputs = {}
  for i = 1, 4 do
    local state = crow_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "C" .. i, state = state, source = "crow", num = i })
    end
  end
  for i = 1, 4 do
    local state = txo_states[i]
    if state and state.active then
      table.insert(active_outputs, { label = "T" .. i, state = state, source = "txo_cv", num = i })
    end
  end

  if #active_outputs == 0 then
    screen.level(4)
    screen.move(64, 32)
    screen.text_center("No active CV outputs")
    return
  end

  local row_height = math.floor(64 / #active_outputs)
  local show_value = row_height >= 14

  for idx, entry in ipairs(active_outputs) do
    local state = entry.state
    local y_top = (idx - 1) * row_height
    local bar_h = row_height - 1
    local is_selected = (entry.source == cv_selected.source and entry.num == cv_selected.num)

    screen.level(is_selected and 6 or 4)
    screen.rect(0, y_top, 128, bar_h)
    screen.fill()

    local range = state.max - state.min
    if range <= 0 then range = 1 end
    if state.current then
      local normalized = util.clamp((state.current - state.min) / range, 0, 1)
      local marker_x = math.floor(normalized * 126)
      screen.level(15)
      screen.rect(marker_x, y_top, 2, bar_h)
      screen.fill()
    end

    screen.level(is_selected and 12 or 7)
    screen.move(2, y_top + bar_h - 1)
    screen.text(entry.label .. " " .. state.type)

    if show_value and state.current then
      screen.level(is_selected and 10 or 5)
      screen.move(126, y_top + bar_h - 1)
      screen.text_right(string.format("%.1fv", state.current))
    end
  end

  -- Overlay: flash param name + value after encoder/arc change
  if arc_overlay and (util.time() - arc_overlay.time) < 1.2 then
    local fade = math.max(0, 1 - (util.time() - arc_overlay.time) / 1.2)
    screen.level(0)
    screen.rect(20, 52, 88, 12)
    screen.fill()
    screen.level(math.floor(15 * fade))
    screen.move(64, 62)
    screen.text_center(arc_overlay.name .. ": " .. arc_overlay.value)
  end
end

---------------------------------------------------------------
-- Arc display
---------------------------------------------------------------
local function update_arc()
  local dev = _seeker.arc
  if not dev then return end

  local mapping = resolve_arc_params(cv_selected)

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
  else
    for ring = 1, 3 do
      for i = 1, 64 do dev:led(ring, i, 1) end
    end
  end

  -- Ring 4: voltage meter
  local state = resolve_cv_output(cv_selected)
  if state and state.current then
    for i = 1, 64 do dev:led(4, i, 2) end
    local range = state.max - state.min
    if range > 0 then
      local normalized = util.clamp((state.current - state.min) / range, 0, 1)
      local pos = math.floor(normalized * 63) + 1
      dev:led(4, pos, 15)
      if pos > 1 then dev:led(4, pos - 1, 7) end
      if pos < 64 then dev:led(4, pos + 1, 7) end
    end
  else
    for i = 1, 64 do dev:led(4, i, 1) end
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Arc delta/key handlers
---------------------------------------------------------------
local CV_ARC_MAP = {
  {threshold = 40},
  {threshold = 20, delta = 0.1},
  {threshold = 20, delta = 0.1},
}

local function handle_arc_delta(n, delta)
  if n == 4 then return end  -- ring 4 is voltage meter
  local arc_map = CV_ARC_MAP[n]
  if not arc_map then return end

  local mapping = resolve_arc_params(cv_selected)
  if not mapping then return end

  local param_id
  if n == 1 then param_id = mapping.r1
  elseif n == 2 then param_id = mapping.r2
  elseif n == 3 then param_id = mapping.r3
  end
  if not param_id or not params.lookup[param_id] then return end

  arc_accum[n] = arc_accum[n] + 1
  if arc_accum[n] >= arc_map.threshold then
    arc_accum[n] = 0
    local direction = delta > 0 and 1 or -1
    local param_obj = params:lookup_param(param_id)
    local current = params:get(param_id)

    if arc_map.delta then
      local new_val = current + direction * arc_map.delta
      if param_obj.controlspec then
        new_val = util.clamp(new_val, param_obj.controlspec.minval, param_obj.controlspec.maxval)
      end
      params:set(param_id, new_val)
    else
      if param_obj.t == params.tOPTION then
        params:set(param_id, util.clamp(current + direction, 1, #param_obj.options))
      elseif param_obj.min and param_obj.max then
        params:set(param_id, util.clamp(current + direction, param_obj.min, param_obj.max))
      end
    end

    arc_overlay = {
      name = param_obj.name or param_id,
      value = params:string(param_id),
      time = util.time()
    }
    update_arc()
  end
end

local function handle_arc_key(n, z)
  if z ~= 1 then return end
  -- Cycle output type within current category
  local type_param, max_val
  if cv_selected.source == "crow" then
    type_param = "crow_" .. cv_selected.num .. "_mode"
    local category = params:string("crow_" .. cv_selected.num .. "_category")
    max_val = (category == "Gate") and 4 or 6
  else
    type_param = "txo_cv_" .. cv_selected.num .. "_type"
    max_val = 3
  end

  if params.lookup[type_param] then
    local current = params:get(type_param)
    params:set(type_param, (current % max_val) + 1)
    local param_obj = params:lookup_param(type_param)
    arc_overlay = {
      name = param_obj.name or "Type",
      value = params:string(type_param),
      time = util.time()
    }
  end
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

  -- Rebuild param list based on selected output
  norns_ui.rebuild_params = function(self)
    local state, prefix = resolve_cv_output(cv_selected)
    self.params = {}

    if state then
      local suffixes = (cv_selected.source == "crow")
        and CROW_ENC_SUFFIXES[state.type]
        or TXO_ENC_SUFFIXES[state.type]

      -- Add output-specific params
      table.insert(self.params, { separator = true, title = cv_selected.source:upper() .. " " .. cv_selected.num .. " " .. state.type })
      if suffixes then
        for _, suffix in ipairs(suffixes) do
          local param_id = prefix .. suffix
          if params.lookup[param_id] then
            table.insert(self.params, { id = param_id })
          end
        end
      end

      -- Add arc-controlled params
      local arc_mapping = resolve_arc_params(cv_selected)
      if arc_mapping then
        if arc_mapping.r1 and params.lookup[arc_mapping.r1] then
          table.insert(self.params, { id = arc_mapping.r1 })
        end
        if arc_mapping.r2 and params.lookup[arc_mapping.r2] then
          table.insert(self.params, { id = arc_mapping.r2 })
        end
        if arc_mapping.r3 and params.lookup[arc_mapping.r3] then
          table.insert(self.params, { id = arc_mapping.r3 })
        end
      end
    end

    -- Sync action
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

    -- In live view: encoders handle output params, K3 not used
    if not self.state.live_view then
      NornsUI.handle_key(self, n, z)
    end
  end

  norns_ui.handle_enc = function(self, n, d)
    if self.state.live_view then
      -- Route encoders to output-specific params
      local state, prefix = resolve_cv_output(cv_selected)
      if not state then return end

      local suffixes = (cv_selected.source == "crow")
        and CROW_ENC_SUFFIXES[state.type]
        or TXO_ENC_SUFFIXES[state.type]
      if not suffixes or not suffixes[n] then return end

      local param_id = prefix .. suffixes[n]
      if not params.lookup[param_id] then return end

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
        value = params:string(param_id),
        time = util.time()
      }
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

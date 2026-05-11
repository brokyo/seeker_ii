-- arc_pages.lua
-- Shared arc page definitions and page-building helpers for eurorack output sections.
-- Used by cv_monitor (multi-output view) and individual output live views.

local PageState = include("lib/ui/components/page_state")
local EurorackUtils = include("lib/modes/eurorack/eurorack_utils")

local ArcPages = {}

---------------------------------------------------------------
-- Short display names for footer labels (max ~5 chars)
---------------------------------------------------------------
ArcPages.PARAM_SHORT_NAMES = {
  -- Shared
  Interval       = "Intvl",
  Modifier       = "Mod",
  Offset         = "Offst",
  -- Crow config
  Type           = "Type",
  Distribution   = "Dist",
  -- Gate types
  Voltage        = "Volts",
  ["Gate Length"] = "Gate",
  Length          = "Len",
  Hits           = "Hits",
  Rotation       = "Rot",
  Swing          = "Swng",
  Probability    = "Prob",
  -- Burst
  ["Burst Count"]  = "Count",
  ["Burst Shape"]  = "Shape",
  ["Burst Window"] = "Wndw",
  ["Burst Time"]   = "Time",
  -- LFO
  Shape              = "Shape",
  Skew               = "Skew",
  -- Envelope
  ["Envelope Mode"]    = "Mode",
  Peak                 = "Peak",
  Attack               = "Atk",
  ["Attack Shape"]     = "AtkSh",
  Decay                = "Dec",
  Sustain              = "Sus",
  Release              = "Rel",
  ["Release Shape"]    = "RelSh",
  -- Knob Recorder
  Sensitivity        = "Sens",
  ["Loop Crossfade"] = "XFade",
  -- Random
  Source             = "Src",
  Step               = "Step",
  Center             = "Cntr",
  Depth              = "Depth",
  Slew               = "Slew",
  ["Step Size"]      = "StpSz",
  Steps              = "Steps",
  Loops              = "Loops",
  -- TXO CV (already short: Type, Shape, Morph, Depth, Phase, Rect, Slew, Mode, Center)
}

---------------------------------------------------------------
-- Arc page definitions per output source and type.
-- Each page: { label, r1, r2, r3, r4 } where r1-r4 are param suffixes.
---------------------------------------------------------------
ArcPages.ARC_PAGES = {
  crow = {
    RTH = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "rhythm",   r1 = "rhythm_hits", r2 = "rhythm_length", r3 = "rhythm_distribution", r4 = "rhythm_rotation" },
      { label = "gate",     r1 = "rhythm_voltage", r2 = "rhythm_gate_length", r3 = "rhythm_swing", r4 = "rhythm_probability" },
    },
    BST = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "perform",  r1 = "burst_count", r2 = "burst_shape", r3 = "burst_time", r4 = "burst_voltage" },
    },
    LFO = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "perform",  r1 = "lfo_center", r2 = "lfo_depth", r3 = "lfo_shape", r4 = "lfo_skew" },
    },
    ENV = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier", r4 = "envelope_mode" },
      { label = "perform",  r1 = "envelope_attack", r2 = "envelope_decay", r3 = "envelope_sustain", r4 = "envelope_release" },
      { label = "shape",    r1 = "envelope_peak", r2 = "envelope_attack_shape", r3 = "envelope_release_shape" },
    },
    KR = {
      { label = "config",   r1 = "type" },
      { label = "perform",  r1 = "knob_sensitivity", r2 = "knob_crossfade" },
    },
    RND = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier", r4 = "random_step" },
      { label = "perform",  r1 = "random_center", r2 = "random_depth", r3 = "random_slew", r4 = "random_step_size" },
      { label = "sequence", r1 = "random_source", r2 = "random_shape", r3 = "random_steps", r4 = "random_loop_count" },
    },
  },
  txo_tr = {
    RTH = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "rhythm",   r1 = "rhythm_hits", r2 = "rhythm_length", r3 = "rhythm_distribution", r4 = "rhythm_rotation" },
      { label = "gate",     r1 = "rhythm_gate_length", r2 = "rhythm_swing", r3 = "rhythm_probability" },
    },
    BST = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "perform",  r1 = "burst_count", r2 = "burst_time", r3 = "burst_shape" },
    },
  },
  txo_cv = {
    LFO = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier" },
      { label = "perform",  r1 = "depth", r2 = "offset", r3 = "shape", r4 = "rect" },
      { label = "detail",   r1 = "morph", r2 = "phase" },
    },
    RND = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier", r4 = "random_mode" },
      { label = "perform",  r1 = "random_center", r2 = "random_depth", r3 = "random_slew" },
    },
    ENV = {
      { label = "config",   r1 = "type", r2 = "clock_interval", r3 = "clock_modifier", r4 = "envelope_mode" },
      { label = "perform",  r1 = "envelope_attack", r2 = "envelope_decay", r3 = "envelope_sustain", r4 = "envelope_release" },
      { label = "level",    r1 = "envelope_peak" },
    },
  },
}

---------------------------------------------------------------
-- Resolve a selected output to its cv state + param prefix
---------------------------------------------------------------
function ArcPages.resolve_cv_output(selected)
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

---------------------------------------------------------------
-- Build PageState pages from ARC_PAGES for a given output
---------------------------------------------------------------
function ArcPages.build_pages_for_output(selected)
  local state, prefix = ArcPages.resolve_cv_output(selected)
  if not state or not prefix then
    return {{ name = "---", slots = {} }}
  end

  local source_pages = ArcPages.ARC_PAGES[selected.source]
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
          short_label = ArcPages.PARAM_SHORT_NAMES[param_obj.name] or param_obj.name or param_id
        end
        local threshold = PageState.THRESH_RANGE
        if params.lookup[param_id] then
          local param_obj = params:lookup_param(param_id)
          if param_obj.t == params.tOPTION then threshold = PageState.THRESH_OPTION end
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

---------------------------------------------------------------
-- Type-specific visualization helpers for live views.
-- Each takes (state, y_top, h) and draws within 128px width.
-- State comes from get_cv_states() with type-specific fields.
---------------------------------------------------------------

-- Rhythm: row of filled/empty dots, current step highlighted
local function draw_viz_rhythm(state, y_top, h)
  local pattern = state.pattern
  local step = state.current_step
  if not pattern or #pattern == 0 then return end
  local active = state.active

  local n = #pattern
  local dot_spacing = 124 / n
  local mid_y = y_top + math.floor(h / 2)
  local dot_r = util.clamp(math.floor(dot_spacing / 3), 1, 3)

  for i = 1, n do
    local cx = 2 + math.floor((i - 0.5) * dot_spacing)
    local is_current = active and (i == step)

    if pattern[i] then
      screen.level(is_current and 15 or (active and 8 or 4))
      screen.circle(cx, mid_y, dot_r)
      screen.fill()
    else
      screen.level(is_current and 10 or (active and 3 or 1))
      screen.circle(cx, mid_y, dot_r)
      screen.stroke()
    end
  end
end

-- Burst ticks spaced by shape (linear, accelerating, etc).
-- Total width scales with burst_time (0-1 fraction of clock period).
local function draw_viz_burst(state, y_top, h)
  local count = state.burst_count or 4
  local shape = state.burst_shape or "Linear"
  local burst_time = state.burst_time or 0.1

  local intervals = EurorackUtils.get_burst_intervals(count, burst_time, shape)
  local positions = {}
  local t = 0
  for i = 1, count do
    table.insert(positions, t)
    t = t + (intervals[i] or 0)
  end

  -- burst_time (0-1) controls how much of the 128px width the cluster spans
  local burst_width_px = math.max(math.floor(124 * burst_time), 20)
  local active = state.active
  local firing_tick = state.burst_current_tick or 0

  for i = 1, count do
    local frac = burst_time > 0 and (positions[i] / burst_time) or 0
    local tick_x = 2 + math.floor(frac * burst_width_px)
    local is_firing = active and (firing_tick == i)
    screen.level(is_firing and 15 or (active and 7 or 2))
    screen.move(tick_x, y_top + 2)
    screen.line(tick_x, y_top + h - 2)
    screen.stroke()
  end

  -- Window boundary marker
  local boundary_x = 2 + burst_width_px
  screen.level(active and 2 or 1)
  screen.move(boundary_x, y_top + 2)
  screen.line(boundary_x, y_top + h - 2)
  screen.stroke()
end

-- LFO: voltage range band with current-voltage marker.
-- Shows where the LFO operates in voltage space rather than its waveform shape.
local function draw_viz_lfo(state, y_top, h)
  local active = state.active
  local min_v = state.min or -5
  local max_v = state.max or 5
  local current = state.current or 0

  -- Map voltage to y pixel. Default ±5V reference, extends if LFO range exceeds ±5V.
  local ref_min = math.min(-5, min_v)
  local ref_max = math.max(5, max_v)
  local ref_range = ref_max - ref_min
  local function v_to_y(v)
    local norm = util.clamp((v - ref_min) / ref_range, 0, 1)
    return y_top + h - 1 - math.floor(norm * (h - 2))
  end

  -- Zero-volt reference line
  screen.level(active and 2 or 1)
  local zero_y = v_to_y(0)
  screen.move(0, zero_y)
  screen.line(127, zero_y)
  screen.stroke()

  -- Voltage range band (min to max)
  local band_top = v_to_y(max_v)
  local band_bot = v_to_y(min_v)
  local band_h = math.max(band_bot - band_top, 1)
  screen.level(active and 7 or 3)
  screen.rect(0, band_top, 128, band_h)
  screen.fill()

  -- Current voltage marker
  local marker_y = v_to_y(current)
  screen.level(active and 15 or 6)
  screen.move(0, marker_y)
  screen.line(127, marker_y)
  screen.stroke()
end

-- Envelope: ADSR/AR curve with playhead.
-- Attack and release segments are curved when shape params are present.

-- Apply ASL-style curve shaping to a linear 0-1 interpolant
local function shape_interp(t, shape)
  if shape == "exponential" then return t * t
  elseif shape == "logarithmic" then return 1 - (1 - t) * (1 - t)
  elseif shape == "sine" then return 0.5 - 0.5 * math.cos(t * math.pi)
  else return t end -- linear, now, wait, over, under, rebound
end

local function draw_viz_envelope(state, y_top, h)
  local env = state.env_times
  if not env then return end

  local active = state.active
  local peak = state.peak or 5
  local sustain = state.sustain or 0
  local elapsed_frac = state.elapsed_frac or 0
  local a_shape = state.attack_shape or "linear"
  local r_shape = state.release_shape or "linear"
  local total = env.a + (env.d or 0) + (env.s or 0) + env.r + (env.wait or 0)
  if total <= 0 then return end

  local scale_x = 128 / total
  local max_v = math.max(peak, 0.01)
  local bottom = y_top + h
  local function v_to_y(v) return bottom - math.floor((v / max_v) * (h - 2)) end

  local segments = 8  -- interpolation steps per envelope stage

  screen.level(active and 8 or 4)

  -- Attack: 0 -> peak, shaped
  local a_start_x = 0
  local a_width = env.a * scale_x
  screen.move(a_start_x, bottom)
  for s = 1, segments do
    local t = shape_interp(s / segments, a_shape)
    screen.line(a_start_x + (s / segments) * a_width, v_to_y(peak * t))
  end

  if env.mode == "ADSR" then
    -- Decay: peak -> sustain (linear)
    local d_start_x = a_start_x + a_width
    local d_width = (env.d or 0) * scale_x
    screen.line(d_start_x + d_width, v_to_y(sustain))

    -- Sustain hold
    local s_start_x = d_start_x + d_width
    local s_width = (env.s or 0) * scale_x
    screen.line(s_start_x + s_width, v_to_y(sustain))

    -- Release: sustain -> 0, shaped
    local r_start_x = s_start_x + s_width
    local r_width = env.r * scale_x
    for s = 1, segments do
      local t = shape_interp(s / segments, r_shape)
      screen.line(r_start_x + (s / segments) * r_width, v_to_y(sustain * (1 - t)))
    end
  else
    -- AR: peak -> 0, shaped
    local r_start_x = a_start_x + a_width
    local r_width = env.r * scale_x
    for s = 1, segments do
      local t = shape_interp(s / segments, r_shape)
      screen.line(r_start_x + (s / segments) * r_width, v_to_y(peak * (1 - t)))
    end
  end
  screen.stroke()

  -- Retrigger boundary marker when envelope overflows cycle
  local cycle = env.cycle
  if cycle and total > cycle then
    local boundary_x = math.floor((cycle / total) * 127)
    screen.level(2)
    screen.move(boundary_x, y_top + 2)
    screen.line(boundary_x, y_top + h - 2)
    screen.stroke()
  end

  -- Playhead (scaled to cycle proportion when envelope overflows)
  if active then
    local cycle_ratio = (cycle and total > cycle) and (cycle / total) or 1
    local px = math.floor(elapsed_frac * cycle_ratio * 127)
    screen.level(15)
    screen.move(px, y_top + 1)
    screen.line(px, y_top + h - 1)
    screen.stroke()
  end
end

-- Random: scrolling voltage trail with bright tip
local function draw_viz_random(state, y_top, h)
  local history = state.voltage_history
  local min_v = state.min or -5
  local max_v = state.max or 5
  local range = max_v - min_v
  if range <= 0 then range = 1 end

  if not history or #history < 2 then
    if state.current then
      local normalized = util.clamp((state.current - min_v) / range, 0, 1)
      local py = y_top + h - math.floor(normalized * (h - 2)) - 1
      screen.level(15)
      screen.circle(124, py, 2)
      screen.fill()
    end
    return
  end

  local n = #history
  local step_w = 124 / math.max(n - 1, 1)

  screen.level(7)
  for i = 1, n do
    local px = 2 + math.floor((i - 1) * step_w)
    local normalized = util.clamp((history[i] - min_v) / range, 0, 1)
    local py = y_top + h - math.floor(normalized * (h - 2)) - 1
    if i == 1 then screen.move(px, py) else screen.line(px, py) end
  end
  screen.stroke()

  local normalized = util.clamp((history[n] - min_v) / range, 0, 1)
  local py = y_top + h - math.floor(normalized * (h - 2)) - 1
  screen.level(15)
  screen.circle(2 + math.floor((n - 1) * step_w), py, 2)
  screen.fill()
end

-- Knob Recorder: recorded waveform with sweeping playhead
local function draw_viz_kr(state, y_top, h)
  local data = state.recorded_data
  local pos = state.playback_pos or 0

  if not data or #data == 0 then
    screen.level(3)
    screen.move(64, y_top + math.floor(h / 2) + 2)
    screen.text_center("K3 to record")
    return
  end

  local n = #data
  local step_w = 128 / n
  screen.level(6)
  for i = 1, n do
    local px = math.floor((i - 1) * step_w)
    local normalized = util.clamp((data[i] + 10) / 20, 0, 1)
    local py = y_top + h - math.floor(normalized * (h - 2)) - 1
    if i == 1 then screen.move(px, py) else screen.line(px, py) end
  end
  screen.stroke()

  local px = math.floor(pos * 127)
  screen.level(15)
  screen.move(px, y_top + 1)
  screen.line(px, y_top + h - 1)
  screen.stroke()
end

local VIZ_DRAW = {
  RTH = draw_viz_rhythm,
  BST = draw_viz_burst,
  LFO = draw_viz_lfo,
  ENV = draw_viz_envelope,
  RND = draw_viz_random,
  KR  = draw_viz_kr,
}

-- Draw type-specific visualization for a cv_state.
-- Falls back to a generic voltage bar if no viz exists for the type.
function ArcPages.draw_output_viz(state, y_top, h)
  local active = state.active

  -- Background panel — slightly dimmer when inactive
  screen.level(active and 4 or 2)
  screen.rect(0, y_top, 128, h)
  screen.fill()

  local draw_fn = VIZ_DRAW[state.type]
  if draw_fn then
    draw_fn(state, y_top, h)
  elseif state.min and state.max and state.current then
    local range = state.max - state.min
    if range <= 0 then range = 1 end
    local normalized = util.clamp((state.current - state.min) / range, 0, 1)
    local marker_x = math.floor(normalized * 126)
    screen.level(15)
    screen.rect(marker_x, y_top, 2, h)
    screen.fill()
  end

  -- Transport icon: play triangle when stopped, stop square when running.
  -- Illuminates progressively while grid button is held toward toggle threshold.
  local icon_x = 120
  local icon_y = y_top + h - 8
  local icon_size = 5

  -- Check if this output's grid button is currently held
  local hold = _seeker.eurorack and _seeker.eurorack.output_hold
  local is_held = hold and hold.source == state._source and hold.num == state._num
  local hold_frac = 0
  if is_held then
    hold_frac = util.clamp((util.time() - hold.start_time) / 0.5, 0, 1)
  end

  local icon_level = is_held and math.floor(3 + hold_frac * 12) or (active and 3 or 1)
  screen.level(icon_level)

  if active then
    -- Stop icon: small filled square
    screen.rect(icon_x, icon_y, icon_size, icon_size)
    screen.fill()
  else
    -- Play icon: small filled right triangle
    screen.move(icon_x, icon_y)
    screen.line(icon_x + icon_size, icon_y + math.floor(icon_size / 2))
    screen.line(icon_x, icon_y + icon_size)
    screen.close()
    screen.fill()
  end
end

return ArcPages

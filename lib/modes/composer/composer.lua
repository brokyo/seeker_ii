-- composer.lua
-- Core domain logic for the Composer chord progression engine.
-- No UI code — handles chord building, stage overrides, param snapshots, and randomization.
-- The rebuild() function builds progressions from params and applies via RC.form() or RC.stage().

local Composer = {}
Composer.__index = Composer

-- Guard against set_action firing during param creation
local params_initialized = false
-- Suppress rebuild while loading a lane's param snapshot
local snapshot_loading = false

-- Optional callback fired after each rebuild (used by live_view to refresh arc)
Composer.on_rebuild = nil

-- Named option tables for musically meaningful labels
local DEGREE_NAMES = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
local MOVEMENT_NAMES = {
  "7ths Dn", "6ths Dn", "5ths Dn", "4ths Dn", "3rds Dn", "Steps Dn",
  "Pedal",
  "Steps Up", "3rds Up", "4ths Up", "5ths Up", "6ths Up", "7ths Up"
}
local CHORD_LEN_NAMES = {
  "2", "3", "4", "5", "6",
  "7", "8", "9", "10", "11", "12", "13", "14", "15"
}
local ROTATION_NAMES = {
  "-5", "-4", "-3", "-2", "-1",
  "Root", "1st Inv", "2nd Inv", "3rd Inv", "4th Inv", "5th Inv"
}
local VOICING_NAMES = {"Close", "Open", "Drop 2", "Drop 3", "Spread"}
local STRUM_ORDER_NAMES = {"Up", "Down", "Out>In", "In>Out", "Random"}
local GATE_NAMES = {"Staccato", "Normal", "Legato", "Drone"}
local GATE_VALUES = {0.3, 0.6, 0.85, 1.0}
local VEL_STAGE_NAMES = {"Flat", "Crescendo", "Decrescendo", "Arch", "Scoop", "Random"}
local VEL_TONE_NAMES = {"Flat", "Strum", "Swell", "Pluck", "Accent Root", "Random"}

-- Name-to-index lookup tables (avoid linear search in hot paths)
local VOICING_INDEX = {}
for i, name in ipairs(VOICING_NAMES) do VOICING_INDEX[name] = i end
local STRUM_INDEX = {}
for i, name in ipairs(STRUM_ORDER_NAMES) do STRUM_INDEX[name] = i end
local ROTATION_INDEX = {}
for i, name in ipairs(ROTATION_NAMES) do ROTATION_INDEX[name] = i end
local CHORD_LEN_INDEX = {}
for i, name in ipairs(CHORD_LEN_NAMES) do CHORD_LEN_INDEX[name] = i end
local GATE_INDEX = {}
for i, name in ipairs(GATE_NAMES) do GATE_INDEX[name] = i end
local VEL_STAGE_INDEX = {}
for i, name in ipairs(VEL_STAGE_NAMES) do VEL_STAGE_INDEX[name] = i end
local VEL_TONE_INDEX = {}
for i, name in ipairs(VEL_TONE_NAMES) do VEL_TONE_INDEX[name] = i end

-- Export name arrays and index lookups for other modules
Composer.DEGREE_NAMES = DEGREE_NAMES
Composer.VOICING_NAMES = VOICING_NAMES
Composer.STRUM_ORDER_NAMES = STRUM_ORDER_NAMES
Composer.ROTATION_NAMES = ROTATION_NAMES
Composer.CHORD_LEN_NAMES = CHORD_LEN_NAMES
Composer.VOICING_INDEX = VOICING_INDEX
Composer.STRUM_INDEX = STRUM_INDEX
Composer.ROTATION_INDEX = ROTATION_INDEX
Composer.CHORD_LEN_INDEX = CHORD_LEN_INDEX
Composer.GATE_NAMES = GATE_NAMES
Composer.GATE_VALUES = GATE_VALUES
Composer.GATE_INDEX = GATE_INDEX
Composer.VEL_STAGE_NAMES = VEL_STAGE_NAMES
Composer.VEL_TONE_NAMES = VEL_TONE_NAMES
Composer.VEL_STAGE_INDEX = VEL_STAGE_INDEX
Composer.VEL_TONE_INDEX = VEL_TONE_INDEX

-- Option index to actual value conversions
local function movement_value(idx) return idx - 7 end   -- index 7 = Pedal (0)
local function rotation_value(idx) return idx - 6 end   -- index 6 = Root (0)
local function chord_len_value(idx) return idx + 1 end   -- index 1 = Dyad (2)

Composer.movement_value = movement_value
Composer.rotation_value = rotation_value
Composer.chord_len_value = chord_len_value

-- Stage velocity: shaped dynamics across progression stages
function Composer.calculate_stage_velocity(stage_index, num_stages, curve, vel_min, vel_max)
  if num_stages <= 1 then return math.floor((vel_min + vel_max) / 2) end
  local t = (stage_index - 1) / (num_stages - 1)
  local vel
  if curve == "Flat" then vel = (vel_min + vel_max) / 2
  elseif curve == "Crescendo" then vel = vel_min + (vel_max - vel_min) * t
  elseif curve == "Decrescendo" then vel = vel_max - (vel_max - vel_min) * t
  elseif curve == "Arch" then vel = vel_min + (vel_max - vel_min) * math.sin(math.pi * t)
  elseif curve == "Scoop" then vel = vel_max - (vel_max - vel_min) * math.sin(math.pi * t)
  elseif curve == "Random" then vel = vel_min + math.random() * (vel_max - vel_min)
  else vel = (vel_min + vel_max) / 2
  end
  return util.clamp(math.floor(vel), vel_min, vel_max)
end

-- Param definitions for per-lane save/load
local COMPOSER_PARAMS = {
  {id = "rc_composer_start", default = 1},
  {id = "rc_composer_movement", default = 10},   -- 4th Up
  {id = "rc_composer_chord_len", default = 3},    -- Tetrad
  {id = "rc_composer_voicing", default = 1},
  {id = "rc_composer_strum_order", default = 1},
  {id = "rc_composer_rotation", default = 6},     -- Root
  {id = "rc_composer_spread", default = 10},
  {id = "rc_composer_stages", default = 1},
  {id = "rc_composer_loops", default = 2},
  {id = "rc_composer_beats", default = 4},
  {id = "rc_composer_vel_min", default = 70},
  {id = "rc_composer_vel_max", default = 110},
  {id = "rc_composer_vel_stage", default = 1},
  {id = "rc_composer_vel_tone", default = 1},
  {id = "rc_composer_gate", default = 2},
}

Composer.COMPOSER_PARAMS = COMPOSER_PARAMS

---------------------------------------------------------------
-- Strum ordering: reorder notes by strum pattern name.
-- Returns a new array of notes in play order.
---------------------------------------------------------------
function Composer.order_notes(notes, strum_name)
  local ordered = {}
  if strum_name == "Up" then
    for _, n in ipairs(notes) do table.insert(ordered, n) end
  elseif strum_name == "Down" then
    for j = #notes, 1, -1 do table.insert(ordered, notes[j]) end
  elseif strum_name == "Out>In" then
    local lo, hi = 1, #notes
    while lo <= hi do
      table.insert(ordered, notes[lo])
      if lo ~= hi then table.insert(ordered, notes[hi]) end
      lo = lo + 1
      hi = hi - 1
    end
  elseif strum_name == "In>Out" then
    local mid = math.ceil(#notes / 2)
    table.insert(ordered, notes[mid])
    for offset = 1, #notes do
      if mid + offset <= #notes then table.insert(ordered, notes[mid + offset]) end
      if mid - offset >= 1 then table.insert(ordered, notes[mid - offset]) end
    end
  end
  -- Random: empty (no deterministic path to show)
  return ordered
end

---------------------------------------------------------------
-- Read a composer param from a lane's snapshot (non-focused) or live params (focused)
---------------------------------------------------------------
local function get_param(snapshot, param_id)
  if snapshot then return snapshot[param_id] end
  return params:get(param_id)
end

---------------------------------------------------------------
-- Build chord progression from params and apply via RC.
-- Optional lane_id targets a specific lane; nil = focused lane.
---------------------------------------------------------------
function Composer.rebuild(lane_id)
  if not params_initialized then return end
  if snapshot_loading then return end
  if not _seeker or not _seeker.rc then return end

  lane_id = lane_id or _seeker.ui_state.get_focused_lane()
  local is_focused = (lane_id == _seeker.ui_state.get_focused_lane())

  -- For non-focused lanes, read base params from snapshot instead of live params
  local snapshot = nil
  if not is_focused then
    snapshot = _seeker.lanes[lane_id].composer_param_snapshot
    if not snapshot then return end
  end

  local start = get_param(snapshot, "rc_composer_start")
  local movement = movement_value(get_param(snapshot, "rc_composer_movement"))
  local chord_len = chord_len_value(get_param(snapshot, "rc_composer_chord_len"))
  local voicing = VOICING_NAMES[get_param(snapshot, "rc_composer_voicing")]
  local rotation = rotation_value(get_param(snapshot, "rc_composer_rotation"))
  local spread = get_param(snapshot, "rc_composer_spread")
  local base_strum_order = STRUM_ORDER_NAMES[get_param(snapshot, "rc_composer_strum_order")]
  local num_stages = get_param(snapshot, "rc_composer_stages")
  local loops = get_param(snapshot, "rc_composer_loops")
  local beats = get_param(snapshot, "rc_composer_beats")
  local vel_min = get_param(snapshot, "rc_composer_vel_min")
  local vel_max = get_param(snapshot, "rc_composer_vel_max")
  local vel_stage_curve = VEL_STAGE_NAMES[get_param(snapshot, "rc_composer_vel_stage")]
  local vel_tone = VEL_TONE_NAMES[get_param(snapshot, "rc_composer_vel_tone")]
  local lane = _seeker.lanes[lane_id]
  local strum_overrides = lane.composer_strum_overrides or {}
  local voicing_overrides = lane.composer_voicing_overrides or {}
  local chord_len_overrides = lane.composer_chord_len_overrides or {}
  local rotation_overrides = lane.composer_rotation_overrides or {}
  local loops_overrides = lane.composer_loops_overrides or {}
  local vel_min_overrides = lane.composer_vel_min_overrides or {}
  local vel_max_overrides = lane.composer_vel_max_overrides or {}
  local vel_stage_overrides = lane.composer_vel_stage_overrides or {}
  local vel_tone_overrides = lane.composer_vel_tone_overrides or {}

  local stages = {}
  for i = 1, num_stages do
    local degree_overrides = lane.composer_degree_overrides or {}
    local degree = degree_overrides[i] or ((start - 1 + movement * (i - 1)) % 7) + 1
    local stage_strum_order = strum_overrides[i] or base_strum_order
    local stage_voicing = voicing_overrides[i] or voicing

    -- Per-stage overrides store option names (not indices) so they survive reordering.
    -- Convert to values before passing to RC.
    local stage_rotation = rotation
    if rotation_overrides[i] then
      local idx = ROTATION_INDEX[rotation_overrides[i]]
      if idx then stage_rotation = rotation_value(idx) end
    end

    local stage_chord_len = chord_len
    if chord_len_overrides[i] then
      local idx = CHORD_LEN_INDEX[chord_len_overrides[i]]
      if idx then stage_chord_len = chord_len_value(idx) end
    end

    local strum_delay = (spread / 100) * beats / stage_chord_len
    -- Gate shortens as spread increases to prevent strum note overlap
    local base_gate = GATE_VALUES[get_param(snapshot, "rc_composer_gate")]
    local stage_gate = base_gate * (1 - spread / 100 * (1 - 1 / stage_chord_len))

    -- Per-stage velocity overrides
    local stage_vel_min = vel_min_overrides[i] or vel_min
    local stage_vel_max = vel_max_overrides[i] or vel_max
    local stage_vel_curve = vel_stage_overrides[i] or vel_stage_curve
    local stage_vel_tone_name = vel_tone_overrides[i] or vel_tone
    local stage_vel = Composer.calculate_stage_velocity(i, num_stages, stage_vel_curve, stage_vel_min, stage_vel_max)

    table.insert(stages, {
      chords = {{
        degree = degree,
        type = "Diatonic",
        dur = beats,
        gate = stage_gate,
        chord_len = stage_chord_len,
        voicing = stage_voicing,
        rotation = stage_rotation,
        velocity = stage_vel,
        vel_tone = stage_vel_tone_name,
      }},
      octave = 3,
      strum = strum_delay,
      strum_order = stage_strum_order,
      loops = loops_overrides[i] or loops,
    })
  end

  if lane.playing then
    -- Lane is mid-cycle: update stage data without resetting playback position.
    for i, entry in ipairs(stages) do
      _seeker.rc.stage(lane_id, i, entry)
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 2)
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_loops", entry.loops or 2)
    end
    for i = num_stages + 1, 8 do
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_active", 1)
      lane.rc_stage_motifs[i] = nil
    end
    lane:sync_all_stages_from_params()
    _seeker.rc.regen(lane_id)
  else
    -- Prepare motif data without starting playback
    _seeker.rc.form(lane_id, stages)
  end

  -- Only save params for the focused lane (snapshot is source of truth for remote lanes)
  if is_focused then
    Composer.save_params(lane_id)
  end

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end

  if Composer.on_rebuild then Composer.on_rebuild() end
end

---------------------------------------------------------------
-- Per-stage override helpers
---------------------------------------------------------------

-- Advance a per-stage override within a named option list.
-- direction nil = wrap (button press), +1/-1 = clamp at edges (arc).
local function advance_stage_override(names, index_lookup, overrides, stage_index, base_name, direction)
  local current = overrides[stage_index] or base_name
  local current_idx = index_lookup[current] or 1

  local next_idx
  if direction then
    next_idx = util.clamp(current_idx + direction, 1, #names)
  else
    next_idx = (current_idx % #names) + 1
  end
  overrides[stage_index] = names[next_idx]
  return names[next_idx]
end

function Composer.cycle_stage_degree(stage_index, direction)
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  lane.composer_degree_overrides = lane.composer_degree_overrides or {}

  local start = params:get("rc_composer_start")
  local movement = movement_value(params:get("rc_composer_movement"))
  local default_degree = ((start - 1 + movement * (stage_index - 1)) % 7) + 1
  local current = lane.composer_degree_overrides[stage_index] or default_degree

  local next_degree
  if direction then
    next_degree = util.clamp(current + direction, 1, 7)
  else
    next_degree = (current % 7) + 1
  end
  lane.composer_degree_overrides[stage_index] = next_degree
  Composer.rebuild()
  return DEGREE_NAMES[next_degree]
end

function Composer.cycle_stage_rotation(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_rotation_overrides = lane.composer_rotation_overrides or {}
  local base = ROTATION_NAMES[params:get("rc_composer_rotation")]
  local result = advance_stage_override(ROTATION_NAMES, ROTATION_INDEX, lane.composer_rotation_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

function Composer.cycle_stage_strum(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_strum_overrides = lane.composer_strum_overrides or {}
  local base = STRUM_ORDER_NAMES[params:get("rc_composer_strum_order")]
  local result = advance_stage_override(STRUM_ORDER_NAMES, STRUM_INDEX, lane.composer_strum_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

function Composer.cycle_stage_voicing(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_voicing_overrides = lane.composer_voicing_overrides or {}
  local base = VOICING_NAMES[params:get("rc_composer_voicing")]
  local result = advance_stage_override(VOICING_NAMES, VOICING_INDEX, lane.composer_voicing_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

function Composer.cycle_stage_chord_len(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_chord_len_overrides = lane.composer_chord_len_overrides or {}
  local base = CHORD_LEN_NAMES[params:get("rc_composer_chord_len")]
  local result = advance_stage_override(CHORD_LEN_NAMES, CHORD_LEN_INDEX, lane.composer_chord_len_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

function Composer.cycle_stage_loops(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_loops_overrides = lane.composer_loops_overrides or {}
  local base = params:get("rc_composer_loops")
  local current = lane.composer_loops_overrides[stage_index] or base
  local next_val
  if direction then
    next_val = util.clamp(current + direction, 1, 8)
  else
    next_val = (current % 8) + 1
  end
  lane.composer_loops_overrides[stage_index] = next_val
  Composer.rebuild()
  return next_val
end

-- direction: +1/-1 for arc nudge, nil to increment by 1 (button press)
function Composer.cycle_stage_vel_min(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_vel_min_overrides = lane.composer_vel_min_overrides or {}
  local base = params:get("rc_composer_vel_min")
  local current = lane.composer_vel_min_overrides[stage_index] or base
  local next_val
  if direction then
    next_val = util.clamp(current + direction, 1, 127)
  else
    next_val = util.clamp(current + 1, 1, 127)
  end
  lane.composer_vel_min_overrides[stage_index] = next_val
  Composer.rebuild()
  return next_val
end

function Composer.cycle_stage_vel_max(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_vel_max_overrides = lane.composer_vel_max_overrides or {}
  local base = params:get("rc_composer_vel_max")
  local current = lane.composer_vel_max_overrides[stage_index] or base
  local next_val
  if direction then
    next_val = util.clamp(current + direction, 1, 127)
  else
    next_val = util.clamp(current + 1, 1, 127)
  end
  lane.composer_vel_max_overrides[stage_index] = next_val
  Composer.rebuild()
  return next_val
end

function Composer.cycle_stage_vel_stage(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_vel_stage_overrides = lane.composer_vel_stage_overrides or {}
  local base = VEL_STAGE_NAMES[params:get("rc_composer_vel_stage")]
  local result = advance_stage_override(VEL_STAGE_NAMES, VEL_STAGE_INDEX, lane.composer_vel_stage_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

function Composer.cycle_stage_vel_tone(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.composer_vel_tone_overrides = lane.composer_vel_tone_overrides or {}
  local base = VEL_TONE_NAMES[params:get("rc_composer_vel_tone")]
  local result = advance_stage_override(VEL_TONE_NAMES, VEL_TONE_INDEX, lane.composer_vel_tone_overrides, stage_index, base, direction)
  Composer.rebuild()
  return result
end

---------------------------------------------------------------
-- Save/load param snapshots per lane
---------------------------------------------------------------
function Composer.save_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  local snapshot = {}
  for _, p in ipairs(COMPOSER_PARAMS) do
    snapshot[p.id] = params:get(p.id)
  end
  snapshot.strum_overrides = lane.composer_strum_overrides or {}
  snapshot.voicing_overrides = lane.composer_voicing_overrides or {}
  snapshot.chord_len_overrides = lane.composer_chord_len_overrides or {}
  snapshot.degree_overrides = lane.composer_degree_overrides or {}
  snapshot.rotation_overrides = lane.composer_rotation_overrides or {}
  snapshot.loops_overrides = lane.composer_loops_overrides or {}
  snapshot.vel_min_overrides = lane.composer_vel_min_overrides or {}
  snapshot.vel_max_overrides = lane.composer_vel_max_overrides or {}
  snapshot.vel_stage_overrides = lane.composer_vel_stage_overrides or {}
  snapshot.vel_tone_overrides = lane.composer_vel_tone_overrides or {}
  lane.composer_param_snapshot = snapshot
end

function Composer.load_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  snapshot_loading = true
  if lane.composer_param_snapshot then
    for _, p in ipairs(COMPOSER_PARAMS) do
      params:set(p.id, lane.composer_param_snapshot[p.id] or p.default)
    end
    lane.composer_strum_overrides = lane.composer_param_snapshot.strum_overrides or {}
    lane.composer_voicing_overrides = lane.composer_param_snapshot.voicing_overrides or {}
    lane.composer_chord_len_overrides = lane.composer_param_snapshot.chord_len_overrides or {}
    lane.composer_degree_overrides = lane.composer_param_snapshot.degree_overrides or {}
    lane.composer_rotation_overrides = lane.composer_param_snapshot.rotation_overrides or {}
    lane.composer_loops_overrides = lane.composer_param_snapshot.loops_overrides or {}
    lane.composer_vel_min_overrides = lane.composer_param_snapshot.vel_min_overrides or {}
    lane.composer_vel_max_overrides = lane.composer_param_snapshot.vel_max_overrides or {}
    lane.composer_vel_stage_overrides = lane.composer_param_snapshot.vel_stage_overrides or {}
    lane.composer_vel_tone_overrides = lane.composer_param_snapshot.vel_tone_overrides or {}
  else
    for _, p in ipairs(COMPOSER_PARAMS) do
      params:set(p.id, p.default)
    end
    lane.composer_strum_overrides = {}
    lane.composer_voicing_overrides = {}
    lane.composer_chord_len_overrides = {}
    lane.composer_degree_overrides = {}
    lane.composer_rotation_overrides = {}
    lane.composer_loops_overrides = {}
    lane.composer_vel_min_overrides = {}
    lane.composer_vel_max_overrides = {}
    lane.composer_vel_stage_overrides = {}
    lane.composer_vel_tone_overrides = {}
  end
  snapshot_loading = false
end

-- Lane change callback: save outgoing, load incoming, rebuild
function Composer.on_lane_change(old_lane_id, new_lane_id)
  Composer.save_params(old_lane_id)
  Composer.load_params(new_lane_id)
  Composer.rebuild()
end

---------------------------------------------------------------
-- Randomize all params and start playback
---------------------------------------------------------------
-- Randomization styles: constrained param ranges that produce a coherent character.
-- "journey": implied melody via Out>In convergence, negative rotation, wide voicings.
--   Extended drift degree pool (I, ii, iii, IV, vi) — no dominant pull, no diminished tension.
--   Fixed chord length per roll — consistent strum density across all stages.
local RANDOM_STYLES = {
  journey = {
    stages = {2, 3},
    beats = {4, 5, 6, 8},
    chord_len = {5, 7},          -- 6-8 notes: enough to phrase, few enough to sing
    voicing = {2, 5},           -- Open, Spread
    rotation = {3, 5},          -- -3 to -1
    spread = {50, 60, 70, 80},
    strum_order = {3, 3},       -- Out>In (fixed)
    gate = {2, 3},              -- Normal, Legato
    movement = {5, 6, 8, 9},   -- 3rds Dn, Steps Dn, Steps Up, 3rds Up
    vel_tone = {4, 4},          -- Pluck (fixed)
    vel_range = {70, 110},
    degree_pool = {1, 2, 3, 4, 6},  -- I, ii, iii, IV, vi (extended drift)
  },
}

local function pick(t)
  return t[math.random(1, #t)]
end

local function rand_range(lo, hi)
  return math.random(lo, hi)
end

function Composer.randomize(style)
  local s = RANDOM_STYLES[style]

  snapshot_loading = true
  params:set("rc_composer_start", math.random(1, #DEGREE_NAMES))
  if s then
    params:set("rc_composer_movement", pick(s.movement))
    params:set("rc_composer_stages", rand_range(s.stages[1], s.stages[2]))
    params:set("rc_composer_beats", pick(s.beats))
    params:set("rc_composer_chord_len", rand_range(s.chord_len[1], s.chord_len[2]))
    params:set("rc_composer_voicing", pick(s.voicing))
    params:set("rc_composer_rotation", rand_range(s.rotation[1], s.rotation[2]))
    params:set("rc_composer_spread", pick(s.spread))
    params:set("rc_composer_strum_order", rand_range(s.strum_order[1], s.strum_order[2]))
    params:set("rc_composer_gate", rand_range(s.gate[1], s.gate[2]))
    params:set("rc_composer_vel_tone", rand_range(s.vel_tone[1], s.vel_tone[2]))
    local va, vb = rand_range(s.vel_range[1], s.vel_range[2]), rand_range(s.vel_range[1], s.vel_range[2])
    params:set("rc_composer_vel_min", math.min(va, vb))
    params:set("rc_composer_vel_max", math.max(va, vb))
  else
    -- No style: full uniform random (original behavior)
    params:set("rc_composer_movement", math.random(1, #MOVEMENT_NAMES))
    params:set("rc_composer_stages", math.random(2, 5))
    local beat_options = {2, 3, 4, 5, 6, 8, 10, 12}
    params:set("rc_composer_beats", beat_options[math.random(1, #beat_options)])
    params:set("rc_composer_chord_len", math.random(1, #CHORD_LEN_NAMES))
    params:set("rc_composer_voicing", math.random(1, #VOICING_NAMES))
    params:set("rc_composer_rotation", math.random(1, #ROTATION_NAMES))
    local spread_options = {0, 10, 20, 30, 50, 70, 100}
    params:set("rc_composer_spread", spread_options[math.random(1, #spread_options)])
    params:set("rc_composer_strum_order", math.random(1, #STRUM_ORDER_NAMES))
    params:set("rc_composer_gate", math.random(1, #GATE_NAMES))
    params:set("rc_composer_vel_tone", math.random(1, #VEL_TONE_NAMES))
    local vel_a, vel_b = math.random(50, 127), math.random(50, 127)
    params:set("rc_composer_vel_min", math.min(vel_a, vel_b))
    params:set("rc_composer_vel_max", math.max(vel_a, vel_b))
  end
  params:set("rc_composer_loops", math.random(1, 4))
  params:set("rc_composer_vel_stage", math.random(1, #VEL_STAGE_NAMES))
  snapshot_loading = false

  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local num_stages = params:get("rc_composer_stages")
  local degree_pool = s and s.degree_pool
  lane.composer_degree_overrides = {}
  for i = 1, num_stages do
    if degree_pool then
      lane.composer_degree_overrides[i] = pick(degree_pool)
    else
      lane.composer_degree_overrides[i] = math.random(1, 7)
    end
  end
  lane.composer_voicing_overrides = {}
  lane.composer_chord_len_overrides = {}
  lane.composer_strum_overrides = {}
  lane.composer_rotation_overrides = {}
  lane.composer_loops_overrides = {}
  lane.composer_vel_min_overrides = {}
  lane.composer_vel_max_overrides = {}
  lane.composer_vel_stage_overrides = {}
  lane.composer_vel_tone_overrides = {}
  for i = 1, num_stages do
    lane.composer_loops_overrides[i] = math.random(1, 4)
  end

  if lane.playing then
    lane:stop()
  end

  Composer.rebuild()
  lane:play({quantize = true})
end

---------------------------------------------------------------
-- Get stage count for a lane (live params if focused, snapshot otherwise)
---------------------------------------------------------------
local function get_lane_stages(lane_id)
  if lane_id == _seeker.ui_state.get_focused_lane() then
    return params:get("rc_composer_stages")
  end
  local lane = _seeker.lanes[lane_id]
  if lane.composer_param_snapshot then
    return lane.composer_param_snapshot.rc_composer_stages or 1
  end
  return 1
end

---------------------------------------------------------------
-- Meta-progression: automated rotation cycling on a clock
---------------------------------------------------------------

-- Cycle through rotation values on a lane, rebuilding at each step.
-- rotations: array of ROTATION_NAMES indices (e.g. {3,4,5,4} = -3,-2,-1,-2)
-- cycle_beats: clock.sync interval between rotation changes
function Composer.meta_rotation(lane_id, rotations, cycle_beats)
  if Composer._meta_clocks and Composer._meta_clocks[lane_id] then
    clock.cancel(Composer._meta_clocks[lane_id])
  end
  Composer._meta_clocks = Composer._meta_clocks or {}
  local idx = 0
  Composer._meta_clocks[lane_id] = clock.run(function()
    while true do
      clock.sync(cycle_beats)
      idx = (idx % #rotations) + 1
      local lane = _seeker.lanes[lane_id]
      lane.composer_rotation_overrides = lane.composer_rotation_overrides or {}
      local rot_name = ROTATION_NAMES[rotations[idx]]
      local num_stages = get_lane_stages(lane_id)
      for s = 1, num_stages do
        lane.composer_rotation_overrides[s] = rot_name
      end
      Composer.rebuild(lane_id)
    end
  end)
end

function Composer.stop_meta(lane_id)
  if Composer._meta_clocks and Composer._meta_clocks[lane_id] then
    clock.cancel(Composer._meta_clocks[lane_id])
    Composer._meta_clocks[lane_id] = nil
  end
end

---------------------------------------------------------------
-- Create params
---------------------------------------------------------------
function Composer.create_params()
  params:add_group("rc_composer_group", "COMPOSER", 15)

  params:add_option("rc_composer_start", "Start Degree", DEGREE_NAMES, 1)
  params:set_action("rc_composer_start", function() Composer.rebuild() end)

  params:add_option("rc_composer_movement", "Movement", MOVEMENT_NAMES, 10)
  params:set_action("rc_composer_movement", function() Composer.rebuild() end)

  params:add_option("rc_composer_chord_len", "Chord Len", CHORD_LEN_NAMES, 3)
  params:set_action("rc_composer_chord_len", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_chord_len_overrides = {}
    Composer.rebuild()
  end)

  params:add_option("rc_composer_voicing", "Voicing", VOICING_NAMES, 1)
  params:set_action("rc_composer_voicing", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_voicing_overrides = {}
    Composer.rebuild()
  end)

  params:add_option("rc_composer_strum_order", "Strum Order", STRUM_ORDER_NAMES, 1)
  params:set_action("rc_composer_strum_order", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_strum_overrides = {}
    Composer.rebuild()
  end)

  params:add_option("rc_composer_rotation", "Rotation", ROTATION_NAMES, 6)
  params:set_action("rc_composer_rotation", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_rotation_overrides = {}
    Composer.rebuild()
  end)

  params:add_control("rc_composer_spread", "Spread",
    controlspec.new(0, 100, "lin", 1, 10, "%"))
  params:set_action("rc_composer_spread", function() Composer.rebuild() end)

  params:add_number("rc_composer_stages", "Stages", 1, 8, 1)
  params:set_action("rc_composer_stages", function() Composer.rebuild() end)

  params:add_number("rc_composer_loops", "Loops", 1, 8, 2)
  params:set_action("rc_composer_loops", function() Composer.rebuild() end)

  params:add_number("rc_composer_beats", "Beats", 1, 16, 4)
  params:set_action("rc_composer_beats", function() Composer.rebuild() end)

  params:add_option("rc_composer_gate", "Gate", GATE_NAMES, 2)
  params:set_action("rc_composer_gate", function() Composer.rebuild() end)

  params:add_number("rc_composer_vel_min", "Dyn Soft", 1, 127, 70)
  params:set_action("rc_composer_vel_min", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_vel_min_overrides = {}
    Composer.rebuild()
  end)

  params:add_number("rc_composer_vel_max", "Dyn Loud", 1, 127, 110)
  params:set_action("rc_composer_vel_max", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_vel_max_overrides = {}
    Composer.rebuild()
  end)

  params:add_option("rc_composer_vel_stage", "Dyn Shape", VEL_STAGE_NAMES, 1)
  params:set_action("rc_composer_vel_stage", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_vel_stage_overrides = {}
    Composer.rebuild()
  end)

  params:add_option("rc_composer_vel_tone", "Dyn Touch", VEL_TONE_NAMES, 1)
  params:set_action("rc_composer_vel_tone", function()
    local lane_id = _seeker.ui_state.get_focused_lane()
    _seeker.lanes[lane_id].composer_vel_tone_overrides = {}
    Composer.rebuild()
  end)

  params_initialized = true
end

return Composer

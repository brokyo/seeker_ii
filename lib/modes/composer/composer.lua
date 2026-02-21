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

-- Name-to-index lookup tables (avoid linear search in hot paths)
local VOICING_INDEX = {}
for i, name in ipairs(VOICING_NAMES) do VOICING_INDEX[name] = i end
local STRUM_INDEX = {}
for i, name in ipairs(STRUM_ORDER_NAMES) do STRUM_INDEX[name] = i end
local ROTATION_INDEX = {}
for i, name in ipairs(ROTATION_NAMES) do ROTATION_INDEX[name] = i end
local CHORD_LEN_INDEX = {}
for i, name in ipairs(CHORD_LEN_NAMES) do CHORD_LEN_INDEX[name] = i end

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

-- Option index to actual value conversions
local function movement_value(idx) return idx - 7 end   -- index 7 = Pedal (0)
local function rotation_value(idx) return idx - 6 end   -- index 6 = Root (0)
local function chord_len_value(idx) return idx + 1 end   -- index 1 = Dyad (2)

Composer.movement_value = movement_value
Composer.rotation_value = rotation_value
Composer.chord_len_value = chord_len_value

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
-- Build chord progression from params and apply via RC
---------------------------------------------------------------
function Composer.rebuild()
  if not params_initialized then return end
  if snapshot_loading then return end
  if not _seeker or not _seeker.rc then return end

  local start = params:get("rc_composer_start")
  local movement = movement_value(params:get("rc_composer_movement"))
  local chord_len = chord_len_value(params:get("rc_composer_chord_len"))
  local voicing = VOICING_NAMES[params:get("rc_composer_voicing")]
  local rotation = rotation_value(params:get("rc_composer_rotation"))
  local spread = params:get("rc_composer_spread")
  local base_strum_order = STRUM_ORDER_NAMES[params:get("rc_composer_strum_order")]
  local num_stages = params:get("rc_composer_stages")
  local loops = params:get("rc_composer_loops")
  local beats = params:get("rc_composer_beats")

  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local strum_overrides = lane.composer_strum_overrides or {}
  local voicing_overrides = lane.composer_voicing_overrides or {}
  local chord_len_overrides = lane.composer_chord_len_overrides or {}
  local rotation_overrides = lane.composer_rotation_overrides or {}
  local loops_overrides = lane.composer_loops_overrides or {}

  local stages = {}
  for i = 1, num_stages do
    local degree_overrides = lane.composer_degree_overrides or {}
    local degree = degree_overrides[i] or ((start - 1 + movement * (i - 1)) % 7) + 1
    local stage_strum_order = strum_overrides[i] or base_strum_order
    local stage_voicing = voicing_overrides[i] or voicing

    -- Per-chord rotation: override is a name string, convert to value
    local stage_rotation = rotation
    if rotation_overrides[i] then
      local idx = ROTATION_INDEX[rotation_overrides[i]]
      if idx then stage_rotation = rotation_value(idx) end
    end

    -- Per-chord chord_len: override is a name string, convert to value
    local stage_chord_len = chord_len
    if chord_len_overrides[i] then
      local idx = CHORD_LEN_INDEX[chord_len_overrides[i]]
      if idx then stage_chord_len = chord_len_value(idx) end
    end

    local strum_delay = (spread / 100) * beats / stage_chord_len
    local stage_gate = 0.8 * (1 - spread / 100 * (1 - 1 / stage_chord_len))

    table.insert(stages, {
      chords = {{
        degree = degree,
        type = "Diatonic",
        dur = beats,
        gate = stage_gate,
        chord_len = stage_chord_len,
        voicing = stage_voicing,
        rotation = stage_rotation,
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

  Composer.save_params(lane_id)

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
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
function Composer.randomize()
  snapshot_loading = true
  params:set("rc_composer_start", math.random(1, #DEGREE_NAMES))
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
  params:set("rc_composer_loops", math.random(1, 4))
  snapshot_loading = false

  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local num_stages = params:get("rc_composer_stages")
  lane.composer_degree_overrides = {}
  for i = 1, num_stages do
    lane.composer_degree_overrides[i] = math.random(1, 7)
  end
  lane.composer_voicing_overrides = {}
  lane.composer_chord_len_overrides = {}
  lane.composer_strum_overrides = {}
  lane.composer_rotation_overrides = {}
  lane.composer_loops_overrides = {}
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
-- Create params
---------------------------------------------------------------
function Composer.create_params()
  params:add_group("rc_composer_group", "COMPOSER", 10)

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

  params_initialized = true
end

return Composer

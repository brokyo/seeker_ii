-- cycling.lua
-- Cycling chord progression generator
-- Computes degree sequences from start/movement/stages params,
-- builds RC.form() stages, and regenerates at loop boundaries.
-- Part of lib/modes/motif/types/composer/

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")

local Cycling = {}
Cycling.__index = Cycling

local COMPOSER_MODE = 2

-- Guard against set_action firing during param creation
local initialized = false
-- Suppress rebuild while loading a lane's cycling param snapshot
local loading = false

-- Named option tables for musically meaningful labels
local DEGREE_NAMES = {"I", "ii", "iii", "IV", "V", "vi", "vii"}
local MOVEMENT_NAMES = {
  "7ths Dn", "6ths Dn", "5ths Dn", "4ths Dn", "3rds Dn", "Steps Dn",
  "Pedal",
  "Steps Up", "3rds Up", "4ths Up", "5ths Up", "6ths Up", "7ths Up"
}
local CHORD_LEN_NAMES = {
  "Dyad", "Triad", "Tetrad", "Pentad", "Hexad",
  "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"
}
local ROTATION_NAMES = {
  "-5", "-4", "-3", "-2", "-1",
  "Root", "1st Inv", "2nd Inv", "3rd Inv", "4th Inv", "5th Inv"
}
local QUALITY_NAMES = {"Diatonic", "Major", "Minor", "Sus4", "Min7", "Maj7", "Dom7"}
local VOICING_NAMES = {"Close", "Open", "Drop 2", "Drop 3", "Spread"}
local STRUM_ORDER_NAMES = {"Up", "Down", "Out>In", "In>Out", "Random"}

-- Option index to actual value conversions
local function movement_value(idx) return idx - 7 end   -- index 7 = Unison (0)
local function rotation_value(idx) return idx - 6 end   -- index 6 = Root (0)
local function chord_len_value(idx) return idx + 1 end   -- index 1 = Dyad (2)

-- Cycling param definitions for per-lane save/load
local CYCLING_PARAMS = {
  {id = "rc_cycling_flavor", default = 1},
  {id = "rc_cycling_start", default = 1},
  {id = "rc_cycling_movement", default = 10},   -- 4th Up
  {id = "rc_cycling_quality", default = 1},
  {id = "rc_cycling_chord_len", default = 3},    -- Tetrad
  {id = "rc_cycling_voicing", default = 1},
  {id = "rc_cycling_strum_order", default = 1},
  {id = "rc_cycling_rotation", default = 6},     -- Root
  {id = "rc_cycling_octave", default = 3},
  {id = "rc_cycling_spread", default = 10},
  {id = "rc_cycling_stages", default = 1},
  {id = "rc_cycling_loops", default = 2},
  {id = "rc_cycling_beats", default = 4},
}

-- Flavor presets: named recipes combining movement, voicing, chord length, rotation.
-- Each entry sets all four params to produce a known-good cycling sound.
local FLAVOR_NAMES = {"Folk", "Jazz", "Ambient", "Minimal", "Orchestral"}
local FLAVOR_RECIPES = {
  {movement = 10, voicing = 1, chord_len = 2, rotation = 6},  -- 4ths, Close, Triad, Root
  {movement = 10, voicing = 3, chord_len = 3, rotation = 6},  -- 4ths, Drop 2, Tetrad, Root
  {movement = 9,  voicing = 2, chord_len = 2, rotation = 7},  -- 3rds Up, Open, Triad, 1st Inv
  {movement = 8,  voicing = 1, chord_len = 1, rotation = 6},  -- Steps Up, Close, Dyad, Root
  {movement = 11, voicing = 5, chord_len = 4, rotation = 6},  -- 5ths Up, Spread, Pentad, Root
}

-- Build chord progression from cycling params and apply via RC.form()
local function rebuild()
  if not initialized then return end
  if loading then return end
  if not _seeker or not _seeker.rc then return end

  local start = params:get("rc_cycling_start")
  local movement = movement_value(params:get("rc_cycling_movement"))
  local quality = QUALITY_NAMES[params:get("rc_cycling_quality")]
  local chord_len = chord_len_value(params:get("rc_cycling_chord_len"))
  local voicing = VOICING_NAMES[params:get("rc_cycling_voicing")]
  local rotation = rotation_value(params:get("rc_cycling_rotation"))
  local spread = params:get("rc_cycling_spread")
  local base_strum_order = STRUM_ORDER_NAMES[params:get("rc_cycling_strum_order")]
  local octave = params:get("rc_cycling_octave")
  local num_stages = params:get("rc_cycling_stages")
  local loops = params:get("rc_cycling_loops")
  local beats = params:get("rc_cycling_beats")

  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local strum_overrides = lane.cycling_strum_overrides or {}
  local voicing_overrides = lane.cycling_voicing_overrides or {}
  local chord_len_overrides = lane.cycling_chord_len_overrides or {}

  -- Build stages array for RC.form()
  local stages = {}
  for i = 1, num_stages do
    -- Per-chord degree: override replaces the computed degree
    local degree_overrides = lane.cycling_degree_overrides or {}
    local degree = degree_overrides[i] or ((start - 1 + movement * (i - 1)) % 7) + 1
    local stage_strum_order = strum_overrides[i] or base_strum_order
    local stage_voicing = voicing_overrides[i] or voicing

    -- Per-chord chord_len: override is a name string, convert to value
    local stage_chord_len = chord_len
    if chord_len_overrides[i] then
      for ci, name in ipairs(CHORD_LEN_NAMES) do
        if name == chord_len_overrides[i] then
          stage_chord_len = chord_len_value(ci)
          break
        end
      end
    end

    -- Recalculate strum/gate per stage (chord_len affects timing)
    local stage_strum = (spread / 100) * beats / stage_chord_len
    local stage_gate = 0.8 * (1 - spread / 100 * (1 - 1 / stage_chord_len))

    table.insert(stages, {
      chords = {{
        degree = degree,
        type = quality,
        dur = beats,
        gate = stage_gate,
        chord_len = stage_chord_len,
        voicing = stage_voicing,
        rotation = rotation,
      }},
      octave = octave,
      strum = stage_strum,
      strum_order = stage_strum_order,
      loops = loops,
    })
  end

  if lane.playing then
    -- Lane is mid-cycle: update stage data without resetting playback position.
    -- RC.stage() stores events, regen() picks them up at next loop boundary.
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
    -- First build: full form setup + start playback
    _seeker.rc.form(lane_id, stages)
    lane:play()
  end

  -- Clamp edit stage to valid range
  if _seeker.screen_saver and _seeker.screen_saver.state.cycling_edit_stage then
    if _seeker.screen_saver.state.cycling_edit_stage > num_stages then
      _seeker.screen_saver.state.cycling_edit_stage = num_stages
    end
  end

  -- Save current cycling param values to the focused lane's snapshot
  Cycling.save_cycling_params(lane_id)

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

local function create_params()
  params:add_group("rc_cycling_group", "CYCLING CHORDS", 13)

  -- Cycle shape
  params:add_option("rc_cycling_flavor", "Flavor", FLAVOR_NAMES, 1)
  params:set_action("rc_cycling_flavor", function(value)
    if not initialized then return end
    local recipe = FLAVOR_RECIPES[value]
    if not recipe then return end
    -- Apply full recipe: movement, voicing, chord length, rotation
    loading = true
    params:set("rc_cycling_movement", recipe.movement)
    params:set("rc_cycling_voicing", recipe.voicing)
    params:set("rc_cycling_chord_len", recipe.chord_len)
    params:set("rc_cycling_rotation", recipe.rotation)
    loading = false
    -- Clear per-stage overrides (new recipe = fresh start)
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    lane.cycling_voicing_overrides = {}
    lane.cycling_chord_len_overrides = {}
    lane.cycling_strum_overrides = {}
    lane.cycling_degree_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_start", "Start Degree", DEGREE_NAMES, 1)
  params:set_action("rc_cycling_start", function() rebuild() end)

  params:add_option("rc_cycling_movement", "Movement", MOVEMENT_NAMES, 10)
  params:set_action("rc_cycling_movement", function() rebuild() end)

  params:add_option("rc_cycling_quality", "Quality", QUALITY_NAMES, 1)
  params:set_action("rc_cycling_quality", function() rebuild() end)

  -- Texture
  params:add_option("rc_cycling_chord_len", "Chord Len", CHORD_LEN_NAMES, 3)
  params:set_action("rc_cycling_chord_len", function()
    -- Changing base chord length clears per-stage overrides
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    lane.cycling_chord_len_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_voicing", "Voicing", VOICING_NAMES, 1)
  params:set_action("rc_cycling_voicing", function()
    -- Changing base voicing clears per-stage overrides
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    lane.cycling_voicing_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_strum_order", "Strum Order", STRUM_ORDER_NAMES, 1)
  params:set_action("rc_cycling_strum_order", function()
    -- Changing base strum order clears per-stage overrides
    local lane_id = _seeker.ui_state.get_focused_lane()
    local lane = _seeker.lanes[lane_id]
    lane.cycling_strum_overrides = {}
    rebuild()
  end)

  params:add_option("rc_cycling_rotation", "Rotation", ROTATION_NAMES, 6)
  params:set_action("rc_cycling_rotation", function() rebuild() end)

  params:add_number("rc_cycling_octave", "Octave", 1, 7, 3)
  params:set_action("rc_cycling_octave", function() rebuild() end)

  params:add_control("rc_cycling_spread", "Spread",
    controlspec.new(0, 100, "lin", 1, 10, "%"))
  params:set_action("rc_cycling_spread", function() rebuild() end)

  -- Structure
  params:add_number("rc_cycling_stages", "Stages", 1, 8, 1)
  params:set_action("rc_cycling_stages", function() rebuild() end)

  params:add_number("rc_cycling_loops", "Loops", 1, 8, 2)
  params:set_action("rc_cycling_loops", function() rebuild() end)

  params:add_number("rc_cycling_beats", "Beats", 1, 16, 4)
  params:set_action("rc_cycling_beats", function() rebuild() end)

  initialized = true
end

local function create_screen_ui()
  local norns_ui = NornsUI.new({
    id = "COMPOSER_CYCLING",
    name = "Cycling",
    description = Descriptions.COMPOSER_CYCLING,
    params = {}
  })

  norns_ui.rebuild_params = function(self)
    self.params = {
      { separator = true, title = "Cycle Shape" },
      { id = "rc_cycling_flavor" },
      { id = "rc_cycling_start" },
      { id = "rc_cycling_movement" },
      { id = "rc_cycling_quality" },
      { separator = true, title = "Texture" },
      { id = "rc_cycling_chord_len" },
      { id = "rc_cycling_voicing" },
      { id = "rc_cycling_rotation" },
      { id = "rc_cycling_octave" },
      { id = "rc_cycling_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_cycling_strum_order" },
      { separator = true, title = "Structure" },
      { id = "rc_cycling_stages" },
      { id = "rc_cycling_loops" },
      { id = "rc_cycling_beats" },
    }
  end

  local original_enter = norns_ui.enter
  norns_ui.enter = function(self)
    self:rebuild_params()
    original_enter(self)
  end

  return norns_ui
end

-- Stage count brightness: maps 1-8 stages to LED levels
local STAGE_BRIGHTNESS = {3, 4, 6, 7, 9, 10, 12, 13}

-- Generate a random progression: flavor, stages, degrees, beats.
-- Preserves spread, octave, loops (user's tuning).
function Cycling.randomize()
  -- Random flavor triggers full recipe (movement, voicing, chord_len, rotation)
  params:set("rc_cycling_flavor", math.random(1, #FLAVOR_NAMES))

  -- Random structure under loading flag to batch rebuilds
  loading = true
  params:set("rc_cycling_stages", math.random(2, 5))
  local beat_options = {4, 6, 8}
  params:set("rc_cycling_beats", beat_options[math.random(1, #beat_options)])
  loading = false

  -- Random degrees per stage, clear per-stage overrides
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  local num_stages = params:get("rc_cycling_stages")
  lane.cycling_degree_overrides = {}
  for i = 1, num_stages do
    lane.cycling_degree_overrides[i] = math.random(1, 7)
  end
  lane.cycling_voicing_overrides = {}
  lane.cycling_chord_len_overrides = {}
  lane.cycling_strum_overrides = {}

  rebuild()
end

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_CYCLING",
    layout = {
      x = 1,
      y = 7,
      width = 4,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

    if motif_type ~= COMPOSER_MODE then return end

    -- Col 1: control mode toggle (chord / progression)
    local ss = _seeker.screen_saver
    local in_progression = ss and ss.state.cycling_control_mode == "progression"
    layers.ui[1][7] = in_progression
      and GridConstants.BRIGHTNESS.UI.FOCUSED
      or GridConstants.BRIGHTNESS.UI.NORMAL

    local num_stages = params:get("rc_cycling_stages")

    -- Col 2: add chord
    layers.ui[2][7] = num_stages < 8
      and (STAGE_BRIGHTNESS[num_stages + 1] or 4)
      or 2

    -- Col 3: remove chord
    layers.ui[3][7] = num_stages > 1
      and (STAGE_BRIGHTNESS[num_stages - 1] or 4)
      or 2

    -- Col 4: randomize
    layers.ui[4][7] = GridConstants.BRIGHTNESS.UI.NORMAL
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z ~= 1 then return end

    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")
    if motif_type ~= COMPOSER_MODE then return end

    -- Activate cycling live view on any button press
    if _seeker.ui_state.get_current_section() ~= "COMPOSER_CYCLING" then
      _seeker.ui_state.set_current_section("COMPOSER_CYCLING")
    elseif _seeker.screen_saver and not _seeker.screen_saver.state.is_active then
      _seeker.screen_saver.state.is_active = true
      _seeker.screen_saver._sync_arc_override()
    end

    if x == 1 and y == 7 then
      -- Toggle arc control mode: chord (per-stage) vs progression (global)
      local ss = _seeker.screen_saver
      if ss then
        local mode = ss.state.cycling_control_mode or "chord"
        ss.state.cycling_control_mode = mode == "chord" and "progression" or "chord"
        ss.state.arc_overlay = {
          name = "Mode",
          value = ss.state.cycling_control_mode == "chord" and "Chord" or "Progression",
          time = util.time(),
          duration = 0.4,
        }
        ss._update_cycling_arc()
      end
      _seeker.screen_ui.set_needs_redraw()

    elseif x == 2 and y == 7 then
      -- Add chord: increment stages (max 8)
      local current = params:get("rc_cycling_stages")
      if current < 8 then
        params:set("rc_cycling_stages", current + 1)

        if _seeker.screen_saver and _seeker.screen_saver.state.is_active then
          _seeker.screen_saver.state.arc_overlay = {
            name = "Stages",
            value = tostring(current + 1),
            time = util.time()
          }
        end
        _seeker.screen_ui.set_needs_redraw()
      end

    elseif x == 3 and y == 7 then
      -- Remove chord: decrement stages (min 1)
      local current = params:get("rc_cycling_stages")
      if current > 1 then
        params:set("rc_cycling_stages", current - 1)

        if _seeker.screen_saver and _seeker.screen_saver.state.is_active then
          _seeker.screen_saver.state.arc_overlay = {
            name = "Stages",
            value = tostring(current - 1),
            time = util.time()
          }
        end
        _seeker.screen_ui.set_needs_redraw()
      end

    elseif x == 4 and y == 7 then
      -- Randomize: new flavor, degrees, beats, stages
      Cycling.randomize()
      if _seeker.screen_saver and _seeker.screen_saver.state.is_active then
        _seeker.screen_saver.state.arc_overlay = {
          name = "Randomize",
          value = params:string("rc_cycling_flavor"),
          time = util.time()
        }
        _seeker.screen_saver._update_cycling_arc()
      end
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return grid_ui
end

-- Save current cycling param values and per-stage overrides to a lane's snapshot
function Cycling.save_cycling_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  local snapshot = {}
  for _, p in ipairs(CYCLING_PARAMS) do
    snapshot[p.id] = params:get(p.id)
  end
  snapshot.strum_overrides = lane.cycling_strum_overrides or {}
  snapshot.voicing_overrides = lane.cycling_voicing_overrides or {}
  snapshot.chord_len_overrides = lane.cycling_chord_len_overrides or {}
  snapshot.degree_overrides = lane.cycling_degree_overrides or {}
  lane.cycling_param_snapshot = snapshot
end

-- Load a lane's cycling param snapshot into the global params
function Cycling.load_cycling_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  loading = true
  if lane.cycling_param_snapshot then
    for _, p in ipairs(CYCLING_PARAMS) do
      params:set(p.id, lane.cycling_param_snapshot[p.id] or p.default)
    end
    lane.cycling_strum_overrides = lane.cycling_param_snapshot.strum_overrides or {}
    lane.cycling_voicing_overrides = lane.cycling_param_snapshot.voicing_overrides or {}
    lane.cycling_chord_len_overrides = lane.cycling_param_snapshot.chord_len_overrides or {}
    lane.cycling_degree_overrides = lane.cycling_param_snapshot.degree_overrides or {}
  else
    for _, p in ipairs(CYCLING_PARAMS) do
      params:set(p.id, p.default)
    end
    lane.cycling_strum_overrides = {}
    lane.cycling_voicing_overrides = {}
    lane.cycling_chord_len_overrides = {}
    lane.cycling_degree_overrides = {}
  end
  loading = false
end

-- Advance a per-stage override within a named option list.
-- direction nil = wrap (button press), +1/-1 = clamp at edges (arc).
-- Returns the new name for overlay display.
local function advance_stage_override(names, overrides, stage_index, base_name, direction)
  local current = overrides[stage_index] or base_name
  local current_idx = 1
  for i, name in ipairs(names) do
    if name == current then current_idx = i; break end
  end

  local next_idx
  if direction then
    next_idx = util.clamp(current_idx + direction, 1, #names)
  else
    next_idx = (current_idx % #names) + 1
  end
  overrides[stage_index] = names[next_idx]
  return names[next_idx]
end

-- Cycle degree for a specific stage. direction: nil=wrap, +1/-1=clamp.
-- Degree overrides store numbers (1-7) directly, unlike other overrides which use name strings.
function Cycling.cycle_stage_degree(stage_index, direction)
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  lane.cycling_degree_overrides = lane.cycling_degree_overrides or {}

  local start = params:get("rc_cycling_start")
  local movement = movement_value(params:get("rc_cycling_movement"))
  local default_degree = ((start - 1 + movement * (stage_index - 1)) % 7) + 1
  local current = lane.cycling_degree_overrides[stage_index] or default_degree

  local next_degree
  if direction then
    next_degree = util.clamp(current + direction, 1, 7)
  else
    next_degree = (current % 7) + 1
  end
  lane.cycling_degree_overrides[stage_index] = next_degree
  rebuild()
  return DEGREE_NAMES[next_degree]
end

-- Cycle strum order for a specific stage. direction: nil=wrap, +1/-1=clamp.
function Cycling.cycle_stage_strum(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_strum_overrides = lane.cycling_strum_overrides or {}
  local base = STRUM_ORDER_NAMES[params:get("rc_cycling_strum_order")]
  local result = advance_stage_override(STRUM_ORDER_NAMES, lane.cycling_strum_overrides, stage_index, base, direction)
  rebuild()
  return result
end

-- Cycle voicing for a specific stage. direction: nil=wrap, +1/-1=clamp.
function Cycling.cycle_stage_voicing(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_voicing_overrides = lane.cycling_voicing_overrides or {}
  local base = VOICING_NAMES[params:get("rc_cycling_voicing")]
  local result = advance_stage_override(VOICING_NAMES, lane.cycling_voicing_overrides, stage_index, base, direction)
  rebuild()
  return result
end

-- Cycle chord length for a specific stage. direction: nil=wrap, +1/-1=clamp.
function Cycling.cycle_stage_chord_len(stage_index, direction)
  local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
  lane.cycling_chord_len_overrides = lane.cycling_chord_len_overrides or {}
  local base = CHORD_LEN_NAMES[params:get("rc_cycling_chord_len")]
  local result = advance_stage_override(CHORD_LEN_NAMES, lane.cycling_chord_len_overrides, stage_index, base, direction)
  rebuild()
  return result
end

-- Trigger a rebuild from outside (e.g. on section enter to ensure motifs exist)
function Cycling.rebuild()
  rebuild()
end

-- Expose param registry for RC save/restore
Cycling.CYCLING_PARAMS = CYCLING_PARAMS

function Cycling.init()
  local component = {
    screen = create_screen_ui(),
    grid = create_grid_ui()
  }
  create_params()

  return component
end

return Cycling

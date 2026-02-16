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

-- Cycling param definitions for per-lane save/load
local CYCLING_PARAMS = {
  {id = "rc_cycling_flavor", default = 3},
  {id = "rc_cycling_start", default = 1},
  {id = "rc_cycling_movement", default = 3},
  {id = "rc_cycling_quality", default = 1},
  {id = "rc_cycling_chord_len", default = 4},
  {id = "rc_cycling_voicing", default = 1},
  {id = "rc_cycling_strum_order", default = 1},
  {id = "rc_cycling_rotation", default = 0},
  {id = "rc_cycling_octave", default = 3},
  {id = "rc_cycling_spread", default = 10},
  {id = "rc_cycling_stages", default = 4},
  {id = "rc_cycling_loops", default = 2},
  {id = "rc_cycling_beats", default = 4},
}

-- Flavor presets: each sets movement to a musically useful interval
local FLAVOR_NAMES = {"Thirds Up", "Thirds Down", "Fourths", "Fifths", "Seconds"}
local FLAVOR_MOVEMENTS = {2, -2, 3, 4, 1}

local QUALITY_NAMES = {"Diatonic", "Major", "Minor", "Sus4", "Min7", "Maj7", "Dom7"}
local VOICING_NAMES = {"Close", "Open", "Drop 2", "Drop 3", "Spread"}
local STRUM_ORDER_NAMES = {"Up", "Down", "Out>In", "In>Out", "Random"}

-- Build chord progression from cycling params and apply via RC.form()
local function rebuild()
  if not initialized then return end
  if loading then return end
  if not _seeker or not _seeker.rc then return end

  local start = params:get("rc_cycling_start")
  local movement = params:get("rc_cycling_movement")
  local quality = QUALITY_NAMES[params:get("rc_cycling_quality")]
  local chord_len = params:get("rc_cycling_chord_len")
  local voicing = VOICING_NAMES[params:get("rc_cycling_voicing")]
  local rotation = params:get("rc_cycling_rotation")
  local spread = params:get("rc_cycling_spread")
  local strum_order = STRUM_ORDER_NAMES[params:get("rc_cycling_strum_order")]
  local octave = params:get("rc_cycling_octave")
  local num_stages = params:get("rc_cycling_stages")
  local loops = params:get("rc_cycling_loops")
  local beats = params:get("rc_cycling_beats")

  local lane_id = _seeker.ui_state.get_focused_lane()

  -- Spread derives both spacing and duration from one percentage.
  -- 0% = block chord (all notes together, full sustain)
  -- 100% = full arpeggio (each note owns an equal time slot)
  local strum = (spread / 100) * beats / chord_len
  local chord_gate = 0.8 * (1 - spread / 100 * (1 - 1 / chord_len))

  -- Build stages array for RC.form()
  local stages = {}
  for i = 1, num_stages do
    local degree = ((start - 1 + movement * (i - 1)) % 7) + 1
    table.insert(stages, {
      chords = {{
        degree = degree,
        type = quality,
        dur = beats,
        gate = chord_gate,
        chord_len = chord_len,
        voicing = voicing,
        rotation = rotation,
      }},
      octave = octave,
      strum = strum,
      strum_order = strum_order,
      loops = loops,
    })
  end

  local lane = _seeker.lanes[lane_id]

  if lane.playing then
    -- Lane is mid-cycle: update stage data without resetting playback position.
    -- RC.stage() stores events, regen() picks them up at next loop boundary.
    for i, entry in ipairs(stages) do
      _seeker.rc.stage(lane_id, i, entry)
      params:set("lane_" .. lane_id .. "_stage_" .. i .. "_loops", entry.loops or 2)
    end
    for i = num_stages + 1, 4 do
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

  -- Save current cycling param values to the focused lane's snapshot
  Cycling.save_cycling_params(lane_id)

  if _seeker.screen_ui then
    _seeker.screen_ui.set_needs_redraw()
  end
end

local function create_params()
  params:add_group("rc_cycling_group", "CYCLING CHORDS", 13)

  -- Cycle shape
  params:add_option("rc_cycling_flavor", "Flavor", FLAVOR_NAMES, 3)
  params:set_action("rc_cycling_flavor", function(value)
    if not initialized then return end
    params:set("rc_cycling_movement", FLAVOR_MOVEMENTS[value])
  end)

  params:add_number("rc_cycling_start", "Start Degree", 1, 7, 1)
  params:set_action("rc_cycling_start", function() rebuild() end)

  params:add_number("rc_cycling_movement", "Movement", -6, 6, 3)
  params:set_action("rc_cycling_movement", function() rebuild() end)

  params:add_option("rc_cycling_quality", "Quality", QUALITY_NAMES, 1)
  params:set_action("rc_cycling_quality", function() rebuild() end)

  -- Texture
  params:add_number("rc_cycling_chord_len", "Chord Len", 2, 16, 4)
  params:set_action("rc_cycling_chord_len", function() rebuild() end)

  params:add_option("rc_cycling_voicing", "Voicing", VOICING_NAMES, 1)
  params:set_action("rc_cycling_voicing", function() rebuild() end)

  params:add_option("rc_cycling_strum_order", "Strum Order", STRUM_ORDER_NAMES, 1)
  params:set_action("rc_cycling_strum_order", function() rebuild() end)

  params:add_number("rc_cycling_rotation", "Rotation", -5, 5, 0)
  params:set_action("rc_cycling_rotation", function() rebuild() end)

  params:add_number("rc_cycling_octave", "Octave", 1, 7, 3)
  params:set_action("rc_cycling_octave", function() rebuild() end)

  params:add_control("rc_cycling_spread", "Spread",
    controlspec.new(0, 100, "lin", 1, 10, "%"))
  params:set_action("rc_cycling_spread", function() rebuild() end)

  -- Structure
  params:add_number("rc_cycling_stages", "Stages", 2, 4, 4)
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

local function create_grid_ui()
  local grid_ui = GridUI.new({
    id = "COMPOSER_CYCLING",
    layout = {
      x = 1,
      y = 1,
      width = 1,
      height = 1
    }
  })

  grid_ui.draw = function(self, layers)
    local focused_lane_id = _seeker.ui_state.get_focused_lane()
    local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

    if motif_type ~= COMPOSER_MODE then return end

    local is_cycling_section = (_seeker.ui_state.get_current_section() == "COMPOSER_CYCLING")
    local brightness = is_cycling_section
      and GridConstants.BRIGHTNESS.UI.FOCUSED
      or GridConstants.BRIGHTNESS.UI.NORMAL

    layers.ui[self.layout.x][self.layout.y] = brightness
  end

  grid_ui.handle_key = function(self, x, y, z)
    if z == 1 then
      local focused_lane_id = _seeker.ui_state.get_focused_lane()
      local motif_type = params:get("lane_" .. focused_lane_id .. "_motif_type")

      if motif_type ~= COMPOSER_MODE then return end

      _seeker.ui_state.set_current_section("COMPOSER_CYCLING")
    end
  end

  return grid_ui
end

-- Save current cycling param values to a lane's snapshot
function Cycling.save_cycling_params(lane_id)
  local lane = _seeker.lanes[lane_id]
  local snapshot = {}
  for _, p in ipairs(CYCLING_PARAMS) do
    snapshot[p.id] = params:get(p.id)
  end
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
  else
    for _, p in ipairs(CYCLING_PARAMS) do
      params:set(p.id, p.default)
    end
  end
  loading = false
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

-- live_view.lua
-- Composer live view: voice leading graph, grid lane/stage buttons, and paged arc parameter display.
-- Arc button and K3 cycle pages. Grid stage: first tap selects, second tap on same stage cycles arc page.

local NornsUI = include("lib/ui/base/norns_ui")
local GridUI = include("lib/ui/base/grid_ui")
local GridConstants = include("lib/grid/constants")
local Descriptions = include("lib/ui/component_descriptions")
local PageState = include("lib/ui/components/page_state")

local LiveView = {}

-- Module-level state shared between screen and grid
local edit_stage = nil        -- nil = follow playback, 1-8 = explicit
local page_state = nil              -- PageState for live stage view (harmony, articulation, dynamics pages)
local progression_page_state = nil  -- PageState for global progression view (structure/spread/dynamics pages)
local last_lane_section = "COMPOSER_VOICE"  -- remembers last section navigated via lane button

-- Forward declaration
local update_live_arc
local update_progression_arc

---------------------------------------------------------------
-- PageState page definitions (built with closures over Composer)
---------------------------------------------------------------
local function build_live_pages(Composer)
  return {
    {
      name = "harmony",
      slots = {
        {
          label = "Deg",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_degree(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local degree_overrides = lane.composer_degree_overrides or {}
            local start = params:get("rc_composer_start")
            local movement = Composer.movement_value(params:get("rc_composer_movement"))
            local default_degree = ((start - 1 + movement * (stage_idx - 1)) % 7) + 1
            return Composer.DEGREE_NAMES[degree_overrides[stage_idx] or default_degree]
          end,
        },
        {
          label = "Len",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_chord_len(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_chord_len_overrides or {}
            return overrides[stage_idx] or params:string("rc_composer_chord_len")
          end,
        },
        {
          label = "Voice",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_voicing(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_voicing_overrides or {}
            return overrides[stage_idx] or params:string("rc_composer_voicing")
          end,
        },
        {
          label = "Rot",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_rotation(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_rotation_overrides or {}
            local rot_idx = params:get("rc_composer_rotation")
            if overrides[stage_idx] then
              rot_idx = Composer.ROTATION_INDEX[overrides[stage_idx]] or rot_idx
            end
            return tostring(rot_idx - 6)
          end,
        },
      },
    },
    {
      name = "articulation",
      slots = {
        { label = "Sprd", param_id = "rc_composer_spread", threshold = PageState.THRESH_RANGE },
        false,  -- ring 2 dark
        {
          label = "Strum",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_strum(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_strum_overrides or {}
            return overrides[stage_idx] or params:string("rc_composer_strum_order")
          end,
        },
        {
          label = "Loops",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_loops(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_loops_overrides or {}
            return tostring(overrides[stage_idx] or params:get("rc_composer_loops"))
          end,
        },
      },
    },
    {
      name = "dynamics",
      slots = {
        {
          label = "Soft",
          threshold = PageState.THRESH_RANGE,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_vel_min(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_min_overrides or {}
            return tostring(overrides[stage_idx] or params:get("rc_composer_vel_min"))
          end,
        },
        {
          label = "Loud",
          threshold = PageState.THRESH_RANGE,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_vel_max(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_max_overrides or {}
            return tostring(overrides[stage_idx] or params:get("rc_composer_vel_max"))
          end,
        },
        {
          label = "Shape",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_vel_stage(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_stage_overrides or {}
            return overrides[stage_idx] or params:string("rc_composer_vel_stage")
          end,
        },
        {
          label = "Touch",
          threshold = 56,
          on_delta = function(dir)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            Composer.cycle_stage_vel_tone(stage_idx, dir)
          end,
          get_value = function()
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_tone_overrides or {}
            return overrides[stage_idx] or params:string("rc_composer_vel_tone")
          end,
        },
      },
    },
  }
end

---------------------------------------------------------------
-- Arc display helpers
---------------------------------------------------------------
local function draw_arc_option_segments(dev, ring, current_idx, num_options, is_overridden)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local segment = math.floor(64 / num_options)
  local start = (current_idx - 1) * segment + 1
  local brightness = is_overridden and 14 or 10
  for i = start, math.min(64, start + segment - 1) do
    dev:led(ring, i, brightness)
  end
end

local function draw_arc_position(dev, ring, value, min_val, max_val)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - min_val) / (max_val - min_val)
  local pos = math.floor(norm * 63) + 1
  dev:led(ring, pos, 12)
  if pos > 1 then dev:led(ring, pos - 1, 6) end
  if pos < 64 then dev:led(ring, pos + 1, 6) end
end

local function draw_arc_fill(dev, ring, value, spec)
  for i = 1, 64 do dev:led(ring, i, 2) end
  local norm = (value - spec.minval) / (spec.maxval - spec.minval)
  local fill_end = math.floor(norm * 64)
  for i = 1, fill_end do dev:led(ring, i, 10) end
end

---------------------------------------------------------------
-- Arc display: update LED rings based on page
---------------------------------------------------------------
update_live_arc = function(Composer)
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_composer_start"] then return end

  if page_state.page == 1 then
    -- Harmony page: per-stage overrides with segment displays
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local degree_overrides = lane.composer_degree_overrides or {}
    local voicing_overrides = lane.composer_voicing_overrides or {}
    local rotation_overrides = lane.composer_rotation_overrides or {}
    local chord_len_overrides = lane.composer_chord_len_overrides or {}

    -- Ring 1: degree
    local start = params:get("rc_composer_start")
    local movement = params:get("rc_composer_movement") - 7
    local default_degree = ((start - 1 + movement * (stage_idx - 1)) % 7) + 1
    local current_degree = degree_overrides[stage_idx] or default_degree
    draw_arc_option_segments(dev, 1, current_degree, #Composer.DEGREE_NAMES, degree_overrides[stage_idx])

    -- Ring 2: chord length
    local chord_len_idx = params:get("rc_composer_chord_len")
    if chord_len_overrides[stage_idx] then
      chord_len_idx = Composer.CHORD_LEN_INDEX[chord_len_overrides[stage_idx]] or chord_len_idx
    end
    draw_arc_option_segments(dev, 2, chord_len_idx, #Composer.CHORD_LEN_NAMES, chord_len_overrides[stage_idx])

    -- Ring 3: voicing
    local voicing_idx = params:get("rc_composer_voicing")
    if voicing_overrides[stage_idx] then
      voicing_idx = Composer.VOICING_INDEX[voicing_overrides[stage_idx]] or voicing_idx
    end
    draw_arc_option_segments(dev, 3, voicing_idx, #Composer.VOICING_NAMES, voicing_overrides[stage_idx])

    -- Ring 4: rotation
    local rot_idx = params:get("rc_composer_rotation")
    if rotation_overrides[stage_idx] then
      rot_idx = Composer.ROTATION_INDEX[rotation_overrides[stage_idx]] or rot_idx
    end
    draw_arc_option_segments(dev, 4, rot_idx, #Composer.ROTATION_NAMES, rotation_overrides[stage_idx])

  elseif page_state.page == 2 then
    -- Articulation page: spread (ring 1), ring 2 dark, strum per-stage, loops
    local spread_spec = params:lookup_param("rc_composer_spread").controlspec
    draw_arc_fill(dev, 1, params:get("rc_composer_spread"), spread_spec)
    for i = 1, 64 do dev:led(2, i, 0) end

    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local strum_overrides = lane.composer_strum_overrides or {}
    local strum_idx = params:get("rc_composer_strum_order")
    if strum_overrides[stage_idx] then
      strum_idx = Composer.STRUM_INDEX[strum_overrides[stage_idx]] or strum_idx
    end
    draw_arc_option_segments(dev, 3, strum_idx, #Composer.STRUM_ORDER_NAMES, strum_overrides[stage_idx])

    local loops_overrides = lane.composer_loops_overrides or {}
    local stage_loops = loops_overrides[stage_idx] or params:get("rc_composer_loops")
    local loops_obj = params:lookup_param("rc_composer_loops")
    draw_arc_position(dev, 4, stage_loops, loops_obj.min, loops_obj.max)

  elseif page_state.page == 3 then
    -- Dynamics page: per-stage velocity overrides
    local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
    local stage_idx = edit_stage or lane.current_stage_index or 1
    local vel_min_overrides = lane.composer_vel_min_overrides or {}
    local vel_max_overrides = lane.composer_vel_max_overrides or {}
    local vel_stage_overrides = lane.composer_vel_stage_overrides or {}
    local vel_tone_overrides = lane.composer_vel_tone_overrides or {}

    -- Ring 1: vel_min (numeric position)
    local stage_vel_min = vel_min_overrides[stage_idx] or params:get("rc_composer_vel_min")
    draw_arc_position(dev, 1, stage_vel_min, 1, 127)

    -- Ring 2: vel_max (numeric position)
    local stage_vel_max = vel_max_overrides[stage_idx] or params:get("rc_composer_vel_max")
    draw_arc_position(dev, 2, stage_vel_max, 1, 127)

    -- Ring 3: vel_stage (option segments)
    local vel_stage_idx = params:get("rc_composer_vel_stage")
    if vel_stage_overrides[stage_idx] then
      vel_stage_idx = Composer.VEL_STAGE_INDEX[vel_stage_overrides[stage_idx]] or vel_stage_idx
    end
    draw_arc_option_segments(dev, 3, vel_stage_idx, #Composer.VEL_STAGE_NAMES, vel_stage_overrides[stage_idx])

    -- Ring 4: vel_tone (option segments)
    local vel_tone_idx = params:get("rc_composer_vel_tone")
    if vel_tone_overrides[stage_idx] then
      vel_tone_idx = Composer.VEL_TONE_INDEX[vel_tone_overrides[stage_idx]] or vel_tone_idx
    end
    draw_arc_option_segments(dev, 4, vel_tone_idx, #Composer.VEL_TONE_NAMES, vel_tone_overrides[stage_idx])
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Progression page definition (single page, global controls)
---------------------------------------------------------------
local function build_progression_pages()
  return {
    {
      name = "structure",
      slots = {
        { label = "Beats", param_id = "rc_composer_beats", threshold = 56 },
        { label = "Loops", param_id = "rc_composer_loops", threshold = 56 },
        { label = "CLen",  param_id = "rc_composer_chord_len", threshold = 56 },
        { label = "Gate",  param_id = "rc_composer_gate", threshold = 56 },
      },
    },
    {
      name = "spread",
      slots = {
        { label = "Sprd",  param_id = "rc_composer_spread", threshold = 30, step = 5 },
        { label = "Sprd~", param_id = "rc_composer_spread", threshold = 80, step = 1 },
        { label = "Strum", param_id = "rc_composer_strum_order", threshold = 56 },
      },
    },
    {
      name = "dynamics",
      slots = {
        { label = "Shape", param_id = "rc_composer_vel_stage", threshold = 56 },
        { label = "Touch", param_id = "rc_composer_vel_tone", threshold = 56 },
        { label = "Soft",  param_id = "rc_composer_vel_min", threshold = 56 },
        { label = "Loud",  param_id = "rc_composer_vel_max", threshold = 56 },
      },
    },
  }
end

---------------------------------------------------------------
-- Arc display for COMPOSER_PROGRESSION: structure (beats/loops/chord_len/gate), spread (spread/strum), dynamics (shape/touch/range)
---------------------------------------------------------------
update_progression_arc = function(Composer)
  local dev = _seeker.arc
  if not dev then return end
  if not params.lookup["rc_composer_beats"] then return end

  if progression_page_state.page == 1 then
    -- Structure: beats, loops, chord length, gate
    local beats_obj = params:lookup_param("rc_composer_beats")
    draw_arc_position(dev, 1, params:get("rc_composer_beats"), beats_obj.min, beats_obj.max)

    local loops_obj = params:lookup_param("rc_composer_loops")
    draw_arc_position(dev, 2, params:get("rc_composer_loops"), loops_obj.min, loops_obj.max)

    draw_arc_option_segments(dev, 3, params:get("rc_composer_chord_len"), #Composer.CHORD_LEN_NAMES, false)
    draw_arc_option_segments(dev, 4, params:get("rc_composer_gate"), #Composer.GATE_NAMES, false)

  elseif progression_page_state.page == 2 then
    -- Spread: spread coarse, spread fine, strum, ring 4 dark
    local spread_spec = params:lookup_param("rc_composer_spread").controlspec
    draw_arc_fill(dev, 1, params:get("rc_composer_spread"), spread_spec)
    draw_arc_fill(dev, 2, params:get("rc_composer_spread"), spread_spec)
    draw_arc_option_segments(dev, 3, params:get("rc_composer_strum_order"), #Composer.STRUM_ORDER_NAMES, false)
    for i = 1, 64 do dev:led(4, i, 0) end

  elseif progression_page_state.page == 3 then
    -- Dynamics: shape, touch, soft, loud
    draw_arc_option_segments(dev, 1, params:get("rc_composer_vel_stage"), #Composer.VEL_STAGE_NAMES, false)
    draw_arc_option_segments(dev, 2, params:get("rc_composer_vel_tone"), #Composer.VEL_TONE_NAMES, false)
    draw_arc_position(dev, 3, params:get("rc_composer_vel_min"), 1, 127)
    draw_arc_position(dev, 4, params:get("rc_composer_vel_max"), 1, 127)
  end

  dev:refresh()
end

---------------------------------------------------------------
-- Voice leading graph drawing (live view)
---------------------------------------------------------------
local function draw_live(norns_ui, Composer)
  if not params.lookup["rc_composer_start"] then return end

  local start_degree = params:get("rc_composer_start")
  local movement = params:get("rc_composer_movement") - 7
  local num_stages = params:get("rc_composer_stages")
  local lane_id = _seeker.ui_state.get_focused_lane()
  local lane = _seeker.lanes[lane_id]
  local current_stage = math.min(lane.current_stage_index or 1, num_stages)

  local degree_overrides = lane.composer_degree_overrides or {}
  local degrees = {}
  for i = 1, num_stages do
    degrees[i] = degree_overrides[i] or ((start_degree - 1 + movement * (i - 1)) % 7) + 1
  end

  -- Extract unique MIDI notes per stage from rc_stage_motifs
  local stage_notes = {}
  local has_notes = false
  local global_min = 127
  local global_max = 0

  for i = 1, num_stages do
    local stage_motif = lane.rc_stage_motifs[i]
    if stage_motif and stage_motif.events then
      local seen = {}
      local notes = {}
      for _, event in ipairs(stage_motif.events) do
        if event.type == "note_on" and not seen[event.note] then
          seen[event.note] = true
          table.insert(notes, event.note)
        end
      end
      table.sort(notes)
      stage_notes[i] = notes
      if #notes > 0 then
        has_notes = true
        if notes[1] < global_min then global_min = notes[1] end
        if notes[#notes] > global_max then global_max = notes[#notes] end
      end
    else
      stage_notes[i] = {}
    end
  end

  if not has_notes then
    screen.level(3)
    screen.move(64, 32)
    screen.text_center(num_stages .. " stages")
    return
  end

  -- Vertical pitch area with margins for labels
  local Y_TOP = 10
  local Y_BOTTOM = 45
  local MIN_RANGE = 24
  local raw_range = global_max - global_min + 4
  local padding = math.max(2, math.floor((MIN_RANGE - raw_range) / 2))
  local pitch_min = global_min - padding
  local pitch_max = global_max + padding
  local pitch_range = pitch_max - pitch_min

  local col_x = {}
  local col_spacing = 128 / (num_stages + 1)
  for i = 1, num_stages do
    col_x[i] = math.floor(col_spacing * i)
  end

  local function note_to_y(note)
    return Y_BOTTOM - ((note - pitch_min) / pitch_range) * (Y_BOTTOM - Y_TOP)
  end

  local active_notes = lane.active_notes or {}
  local strum_overrides = lane.composer_strum_overrides or {}
  local base_strum = params:string("rc_composer_strum_order")

  -- Strum voice lines: connect notes by strum position between adjacent chords
  local strum_ordered = {}
  for i = 1, num_stages do
    local strum = strum_overrides[i] or base_strum
    strum_ordered[i] = Composer.order_notes(stage_notes[i], strum)
  end

  for i = 1, num_stages - 1 do
    local from = strum_ordered[i]
    local to = strum_ordered[i + 1]
    local n = math.min(#from, #to)
    local leads_to_current_stage = (i + 1 == current_stage)
    for j = 1, n do
      local voice_dim = 1 - ((j - 1) / math.max(n, 2))
      local base = leads_to_current_stage and 12 or 6
      screen.level(math.floor(base * voice_dim) + 1)
      screen.move(col_x[i], note_to_y(from[j]))
      screen.line(col_x[i + 1], note_to_y(to[j]))
      screen.stroke()
    end
  end

  -- Chord tone dots
  for i = 1, num_stages do
    local is_current = (i == current_stage)
    for _, note in ipairs(stage_notes[i]) do
      local is_playing = is_current and active_notes[note] ~= nil
      local dot_level = is_playing and 15 or (is_current and 8 or 4)
      local dot_radius = is_playing and 3 or (is_current and 1.5 or 1)
      screen.level(dot_level)
      screen.circle(col_x[i], note_to_y(note), dot_radius)
      screen.fill()
    end
  end

  -- COMPOSER_LIVE and COMPOSER_PROGRESSION share this draw function; pick the matching PageState
  local active_page_state = (_seeker.ui_state.get_current_section() == "COMPOSER_PROGRESSION") and progression_page_state or page_state

  -- Page indicator: vertical lines top-right, thick for active page
  local num_pages = #active_page_state.pages
  if num_pages > 1 then
    for p = 1, num_pages do
      local px = 125 - (num_pages - p) * 4
      screen.level(p == active_page_state.page and 12 or 4)
      screen.rect(px, 2, p == active_page_state.page and 2 or 1, 4)
      screen.fill()
    end
  end

  -- Page name flash: centered over score on page change, black backing for readability
  if active_page_state.page_flash then
    local flash = active_page_state.page_flash
    local elapsed = util.time() - flash.time
    if elapsed < flash.duration then
      local fade = math.max(0, 1 - elapsed / flash.duration)
      local text_w = screen.text_extents(flash.name)
      screen.level(0)
      screen.rect(64 - text_w / 2 - 3, 22, text_w + 6, 12)
      screen.fill()
      screen.level(math.floor(12 * fade))
      screen.move(64, 31)
      screen.text_center(flash.name)
    else
      active_page_state.page_flash = nil
    end
  end

  -- Degree labels above each column
  for i = 1, num_stages do
    local is_playing = (i == current_stage)
    local is_editing = (edit_stage and i == edit_stage)
    screen.level(is_playing and 12 or (is_editing and 10 or 4))
    screen.move(col_x[i], 8)
    screen.text_center(Composer.DEGREE_NAMES[degrees[i]])
    if is_editing then
      screen.level(8)
      screen.move(col_x[i] - 4, 9)
      screen.line(col_x[i] + 4, 9)
      screen.stroke()
    end
  end

  -- Footer: PageState handles overlay and 4-column labels
  active_page_state:draw_footer()
end

---------------------------------------------------------------
-- NornsUI: dual-mode screen (live view default, K2 toggles params)
---------------------------------------------------------------
local function create_screen_ui(Composer)
  local norns_ui = NornsUI.new({
    id = "COMPOSER_LIVE",
    name = "Composer",
    description = Descriptions.COMPOSER_LIVE,
    params = {}
  })

  norns_ui.live_view_enabled = true
  norns_ui.needs_playback_refresh = true

  norns_ui.rebuild_params = function(self)
    self.params = {
      { separator = true, title = "Harmony" },
      { id = "rc_composer_chord_len" },
      { id = "rc_composer_voicing" },
      { id = "rc_composer_rotation" },
      { separator = true, title = "Articulation" },
      { id = "rc_composer_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_composer_strum_order" },
      { id = "rc_composer_gate" },
      { separator = true, title = "Structure" },
      { id = "rc_composer_start" },
      { id = "rc_composer_movement" },
      { id = "rc_composer_stages" },
      { id = "rc_composer_loops" },
      { id = "rc_composer_beats" },
      { separator = true, title = "Dynamics" },
      { id = "rc_composer_vel_stage" },
      { id = "rc_composer_vel_tone" },
      { id = "rc_composer_vel_min" },
      { id = "rc_composer_vel_max" },
    }
  end

  norns_ui.draw_live = function(self) draw_live(self, Composer) end
  norns_ui.update_arc = function(self) update_live_arc(Composer) end
  norns_ui.handle_arc_delta = function(self, n, delta)
    page_state:handle_arc_delta(n, delta)
    update_live_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end
  norns_ui.handle_arc_key = function(self, n, z)
    page_state:handle_arc_key(n, z)
    update_live_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end

  -- E2/E3 in live view: page_state handles cursor + param adjustment
  norns_ui.handle_live_enc = function(self, n, d)
    page_state:handle_enc(n, d)
    update_live_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end

  -- K3 in live view: cycle page
  norns_ui.handle_live_key = function(self, n, z)
    if n == 3 and z == 1 then
      page_state:next_page()
      update_live_arc(Composer)
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return norns_ui
end

---------------------------------------------------------------
-- NornsUI: COMPOSER_PROGRESSION (global structural controls, single arc page)
---------------------------------------------------------------
local function create_progression_screen_ui(Composer)
  local norns_ui = NornsUI.new({
    id = "COMPOSER_PROGRESSION",
    name = "Progression",
    description = Descriptions.COMPOSER_PROGRESSION,
    params = {}
  })

  norns_ui.live_view_enabled = true
  norns_ui.needs_playback_refresh = true

  norns_ui.rebuild_params = function(self)
    self.params = {
      { id = "rc_composer_beats" },
      { id = "rc_composer_loops" },
      { id = "rc_composer_chord_len" },
      { id = "rc_composer_gate" },
      { id = "rc_composer_spread", arc_multi_float = {5, 2, 0.5} },
      { id = "rc_composer_strum_order" },
      { separator = true, title = "Dynamics" },
      { id = "rc_composer_vel_stage" },
      { id = "rc_composer_vel_tone" },
      { id = "rc_composer_vel_min" },
      { id = "rc_composer_vel_max" },
    }
  end

  norns_ui.draw_live = function(self) draw_live(self, Composer) end
  norns_ui.update_arc = function(self) update_progression_arc(Composer) end
  norns_ui.handle_arc_delta = function(self, n, delta)
    progression_page_state:handle_arc_delta(n, delta)
    update_progression_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end
  norns_ui.handle_arc_key = function(self, n, z)
    progression_page_state:handle_arc_key(n, z)
    update_progression_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end

  -- E2/E3 in live view: progression_page_state handles cursor + param adjustment
  norns_ui.handle_live_enc = function(self, n, d)
    progression_page_state:handle_enc(n, d)
    update_progression_arc(Composer)
    _seeker.screen_ui.set_needs_redraw()
  end

  norns_ui.handle_live_key = function(self, n, z)
    if n == 3 and z == 1 then
      progression_page_state:next_page()
      update_progression_arc(Composer)
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  return norns_ui
end

---------------------------------------------------------------
-- Grid UI: 4 lane rows (rows 4-7), col 1 = lane button, cols 2-9 = stages
---------------------------------------------------------------
local NUM_COMPOSER_LANES = 4
local FIRST_ROW = 4
local HOLD_THRESHOLD_STAGE = 1.0
local HOLD_THRESHOLD_RANDOMIZE = 1.5

-- Get stage count for a lane (global params if focused, snapshot otherwise)
local function get_lane_stages(lane_idx)
  if lane_idx == _seeker.ui_state.get_focused_lane() then
    return params:get("rc_composer_stages")
  end
  local lane = _seeker.lanes[lane_idx]
  if lane.composer_param_snapshot then
    return lane.composer_param_snapshot.rc_composer_stages or 1
  end
  return 1
end

local function create_grid_ui(Composer)
  local grid_ui = GridUI.new({
    id = "COMPOSER_GRID",
    layout = {
      x = 1,
      y = FIRST_ROW,
      width = 9,
      height = NUM_COMPOSER_LANES
    }
  })

  grid_ui.contains = function(self, x, y)
    if y < FIRST_ROW or y > FIRST_ROW + NUM_COMPOSER_LANES - 1 then return false end
    if x >= 1 and x <= 9 then return true end
    return false
  end

  grid_ui.draw = function(self, layers)
    local focused_lane = _seeker.ui_state.get_focused_lane()
    local DIM = GridConstants.BRIGHTNESS.DIM
    local HIGH = GridConstants.BRIGHTNESS.HIGH

    for i = 1, NUM_COMPOSER_LANES do
      local row = FIRST_ROW + i - 1
      local lane = _seeker.lanes[i]
      local is_focused = i == focused_lane
      local num_stages = get_lane_stages(i)
      local current_stage = lane.current_stage_index or 1

      -- Col 1: lane button
      local lane_brightness
      if is_focused then
        lane_brightness = GridConstants.BRIGHTNESS.FULL
      elseif lane.playing then
        lane_brightness = math.floor(math.sin(clock.get_beats() * 4) * 3 + GridConstants.BRIGHTNESS.FULL - 3)
      else
        lane_brightness = GridConstants.BRIGHTNESS.LOW
      end
      layers.ui[1][row] = lane_brightness

      -- Detect active hold gesture for charge-up animation
      local charge_progress = nil
      local charge_end_stage = 8

      -- Lane button hold (randomize): sweep across all 8 stages
      local lane_key = string.format("1,%d", row)
      local lane_press = self.press_state.pressed_keys[lane_key]
      if lane_press then
        local elapsed = util.time() - lane_press.start_time
        if elapsed > 0.3 then
          local progress = math.min((elapsed - 0.3) / (HOLD_THRESHOLD_RANDOMIZE - 0.3), 1)
          charge_progress = progress * 8
          charge_end_stage = 8
          lane_brightness = math.floor(GridConstants.BRIGHTNESS.LOW + progress * (GridConstants.BRIGHTNESS.FULL - GridConstants.BRIGHTNESS.LOW))
          layers.ui[1][row] = lane_brightness
        end
      end

      -- Stage button hold (set count): sweep toward target stage
      if not charge_progress then
        for stage = 1, 8 do
          local stage_key = string.format("%d,%d", stage + 1, row)
          local stage_press = self.press_state.pressed_keys[stage_key]
          if stage_press then
            local elapsed = util.time() - stage_press.start_time
            if elapsed > 0.3 then
              local progress = math.min((elapsed - 0.3) / (HOLD_THRESHOLD_STAGE - 0.3), 1)
              charge_progress = progress * stage
              charge_end_stage = stage
              break
            end
          end
        end
      end

      -- Cols 2-9: stage buttons with per-LED charge-up interpolation
      for stage = 1, 8 do
        local col = stage + 1
        local brightness

        if charge_progress and stage <= charge_end_stage then
          local stage_progress = util.clamp(charge_progress - (stage - 1), 0, 1)
          brightness = DIM + math.floor(stage_progress * (HIGH - DIM))
        elseif stage > num_stages then
          brightness = DIM
        elseif lane.playing and stage == current_stage then
          brightness = HIGH
        elseif is_focused and edit_stage and stage == edit_stage then
          brightness = GridConstants.BRIGHTNESS.MEDIUM
        else
          brightness = GridConstants.BRIGHTNESS.LOW
        end
        layers.ui[col][row] = brightness
      end
    end
  end

  local LANE_SECTION_CYCLE = {"COMPOSER_VOICE", "COMPOSER_PLAYBACK", "COMPOSER_PROGRESSION"}

  grid_ui.handle_key = function(self, x, y, z)
    local lane_idx = y - FIRST_ROW + 1
    if lane_idx < 1 or lane_idx > NUM_COMPOSER_LANES then return end

    local old_lane = _seeker.ui_state.get_focused_lane()
    local switched_lane = false

    if z == 1 then
      if lane_idx ~= old_lane then
        _seeker.ui_state.set_focused_lane(lane_idx)
        switched_lane = true
      end
    end

    -- Col 1: lane button (tap = cycle sections, hold = randomize)
    if x == 1 then
      local key_id = string.format("1,%d", y)
      if z == 1 then
        self:key_down(key_id)

        if not switched_lane then
          local current = _seeker.ui_state.get_current_section()
          local next_section = LANE_SECTION_CYCLE[1]
          for i, section in ipairs(LANE_SECTION_CYCLE) do
            if current == section then
              next_section = LANE_SECTION_CYCLE[(i % #LANE_SECTION_CYCLE) + 1]
              break
            end
          end
          last_lane_section = next_section
          _seeker.ui_state.set_current_section(next_section)
        else
          -- First tap on a new lane: show the same section as the previous lane.
          -- If already on that section, rebuild manually (set_current_section no-ops).
          local current = _seeker.ui_state.get_current_section()
          if current == last_lane_section then
            local section = _seeker.screen_ui.sections[current]
            if section and section.rebuild_params then
              section:rebuild_params()
            end
          else
            _seeker.ui_state.set_current_section(last_lane_section)
          end
        end

        _seeker.hold_confirm.start({
          text = "randomizing...",
          threshold = HOLD_THRESHOLD_RANDOMIZE,
          on_confirm = function()
            Composer.randomize()
            update_live_arc(Composer)
          end
        })

        _seeker.screen_ui.set_needs_redraw()
      else
        _seeker.hold_confirm.cancel()
        self:key_release(key_id)
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end

    -- Cols 2-9: stage buttons
    if x >= 2 and x <= 9 then
      local stage = x - 1
      local key_id = string.format("%d,%d", x, y)

      if z == 1 then
        self:key_down(key_id)

        local current = _seeker.ui_state.get_current_section()
        if current ~= "COMPOSER_LIVE" or edit_stage ~= stage then
          -- First click: select stage, snap to live view
          _seeker.ui_state.set_current_section("COMPOSER_LIVE")
          edit_stage = stage
          page_state.page_flash = {
            name = page_state.pages[page_state.page].name,
            time = util.time(),
            duration = 0.8,
          }
        else
          -- Second click (same stage, already on COMPOSER_LIVE): toggle page
          page_state:next_page()
        end

        -- Hold: set stage count and start playback if stopped
        _seeker.hold_confirm.start({
          text = "stages: " .. stage,
          threshold = HOLD_THRESHOLD_STAGE,
          on_confirm = function()
            params:set("rc_composer_stages", stage)
            local lane = _seeker.lanes[lane_idx]
            if not lane.playing then
              lane:play({quantize = true})
            end
            update_live_arc(Composer)
          end
        })

        update_live_arc(Composer)
        _seeker.screen_ui.set_needs_redraw()

      else
        _seeker.hold_confirm.cancel()
        self:key_release(key_id)
        update_live_arc(Composer)
        _seeker.screen_ui.set_needs_redraw()
      end
      return
    end
  end

  return grid_ui
end

---------------------------------------------------------------
-- LiveView init: creates PageState, screen, and grid
---------------------------------------------------------------
function LiveView.init(Composer)
  page_state = PageState.new({ pages = build_live_pages(Composer) })
  progression_page_state = PageState.new({ pages = build_progression_pages() })

  LiveView.screen = create_screen_ui(Composer)
  LiveView.progression_screen = create_progression_screen_ui(Composer)
  LiveView.grid = create_grid_ui(Composer)
  LiveView.page_state = page_state
  LiveView.progression_page_state = progression_page_state
  LiveView.edit_stage = function() return edit_stage end
  LiveView.set_edit_stage = function(val) edit_stage = val end
  LiveView.update_live_arc = function() update_live_arc(Composer) end

  -- Refresh arc whenever rebuild fires (including automated meta-progression)
  Composer.on_rebuild = function() update_live_arc(Composer) end

  return LiveView
end

return LiveView

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
local edit_stage = 1          -- 1-8; grid taps override. Defaults to 1 for encoder-only use.
local page_state = nil              -- PageState for live stage view (harmony, articulation, dynamics pages)
local progression_page_state = nil  -- PageState for global progression view (structure/spread/dynamics pages)
local last_lane_section = "COMPOSER_VOICE"  -- remembers last section navigated via lane button

-- Forward declarations
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_degree_overrides or {}
            local start = params:get("rc_composer_start")
            local movement = Composer.movement_value(params:get("rc_composer_movement"))
            local default_degree = ((start - 1 + movement * (stage_idx - 1)) % 7) + 1
            local current = overrides[stage_idx] or default_degree
            PageState.draw_arc_segments(dev, ring, current, #Composer.DEGREE_NAMES, overrides[stage_idx] and 14 or 10)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_chord_len_overrides or {}
            local idx = params:get("rc_composer_chord_len")
            if overrides[stage_idx] then
              idx = Composer.CHORD_LEN_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.CHORD_LEN_NAMES, overrides[stage_idx] and 14 or 10)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_voicing_overrides or {}
            local idx = params:get("rc_composer_voicing")
            if overrides[stage_idx] then
              idx = Composer.VOICING_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.VOICING_NAMES, overrides[stage_idx] and 14 or 10)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_rotation_overrides or {}
            local idx = params:get("rc_composer_rotation")
            if overrides[stage_idx] then
              idx = Composer.ROTATION_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.ROTATION_NAMES, overrides[stage_idx] and 14 or 10)
          end,
        },
      },
    },
    {
      name = "articulation",
      slots = {
        {
          label = "Sprd",
          param_id = "rc_composer_spread",
          threshold = PageState.THRESH_RANGE,
          arc_draw = function(dev, ring)
            local spec = params:lookup_param("rc_composer_spread").controlspec
            PageState.draw_arc_fill(dev, ring, params:get("rc_composer_spread"), spec)
          end,
        },
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_strum_overrides or {}
            local idx = params:get("rc_composer_strum_order")
            if overrides[stage_idx] then
              idx = Composer.STRUM_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.STRUM_ORDER_NAMES, overrides[stage_idx] and 14 or 10)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_loops_overrides or {}
            local stage_loops = overrides[stage_idx] or params:get("rc_composer_loops")
            local loops_obj = params:lookup_param("rc_composer_loops")
            PageState.draw_arc_position(dev, ring, stage_loops, loops_obj.min, loops_obj.max)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_min_overrides or {}
            local val = overrides[stage_idx] or params:get("rc_composer_vel_min")
            PageState.draw_arc_position(dev, ring, val, 1, 127)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_max_overrides or {}
            local val = overrides[stage_idx] or params:get("rc_composer_vel_max")
            PageState.draw_arc_position(dev, ring, val, 1, 127)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_stage_overrides or {}
            local idx = params:get("rc_composer_vel_stage")
            if overrides[stage_idx] then
              idx = Composer.VEL_STAGE_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.VEL_STAGE_NAMES, overrides[stage_idx] and 14 or 10)
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
          arc_draw = function(dev, ring)
            local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
            local stage_idx = edit_stage or lane.current_stage_index or 1
            local overrides = lane.composer_vel_tone_overrides or {}
            local idx = params:get("rc_composer_vel_tone")
            if overrides[stage_idx] then
              idx = Composer.VEL_TONE_INDEX[overrides[stage_idx]] or idx
            end
            PageState.draw_arc_segments(dev, ring, idx, #Composer.VEL_TONE_NAMES, overrides[stage_idx] and 14 or 10)
          end,
        },
      },
    },
  }
end

---------------------------------------------------------------
-- Arc display
---------------------------------------------------------------
update_live_arc = function(Composer)
  local dev = _seeker.arc
  if not dev or not params.lookup["rc_composer_start"] then return end
  page_state:update_arc(dev)
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
        {
          label = "Sprd",
          param_id = "rc_composer_spread",
          threshold = 30,
          step = 5,
          arc_draw = function(dev, ring)
            local spec = params:lookup_param("rc_composer_spread").controlspec
            PageState.draw_arc_fill(dev, ring, params:get("rc_composer_spread"), spec)
          end,
        },
        {
          label = "Sprd~",
          param_id = "rc_composer_spread",
          threshold = 80,
          step = 1,
          arc_draw = function(dev, ring)
            local spec = params:lookup_param("rc_composer_spread").controlspec
            PageState.draw_arc_fill(dev, ring, params:get("rc_composer_spread"), spec)
          end,
        },
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
-- Arc display for COMPOSER_PROGRESSION
---------------------------------------------------------------
update_progression_arc = function(Composer)
  local dev = _seeker.arc
  if not dev or not params.lookup["rc_composer_beats"] then return end
  progression_page_state:update_arc(dev)
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

  active_page_state:draw_page_indicators()
  active_page_state:draw_page_flash()

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

  -- Wire arc/enc/key routing via PageState with Composer-specific arc refresh
  page_state:wire(norns_ui, {
    refresh = function()
      update_live_arc(Composer)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end,
  })

  -- Encoder-only live view: E1 selects stage (or adjusts stage count with K2 held),
  -- E2/E3 pass through to PageState for slot cursor and value adjustment.
  local k2_held = false
  local k2_e1_used = false
  local k2_press_time = 0
  local k3_randomized = false

  local wired_handle_live_enc = norns_ui.handle_live_enc
  norns_ui.handle_live_enc = function(self, n, d)
    if n == 1 then
      local num_stages = params:get("rc_composer_stages")
      if k2_held then
        -- K2 held + E1: adjust stage count
        params:delta("rc_composer_stages", d > 0 and 1 or -1)
        k2_e1_used = true
      else
        -- E1: select edit stage, wrapping
        local dir = d > 0 and 1 or -1
        edit_stage = ((edit_stage - 1 + dir) % num_stages) + 1
      end
      update_live_arc(Composer)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    else
      -- E2/E3: delegate to PageState wired handler
      wired_handle_live_enc(self, n, d)
    end
  end

  -- K2/K3 overrides for live view. NornsUI:handle_key intercepts K2 before
  -- handle_live_key runs, so we override handle_key itself.
  local base_handle_key = NornsUI.handle_key
  norns_ui.handle_key = function(self, n, z)
    -- Track held state for K2+K3 combo detection
    if n == 2 then self._k2_held = (z == 1)
    elseif n == 3 then self._k3_held = (z == 1) end

    -- K2+K3 combo: ensure live view is active (already on COMPOSER_LIVE)
    if z == 1 and ((n == 2 and self._k3_held) or (n == 3 and self._k2_held)) then
      self._combo_used = true
      if not self.state.live_view then
        self.state.live_view = true
        if _seeker.arc and self.update_arc then
          _seeker.arc.set_display(function() self:update_arc() end)
        end
      end
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      return
    end
    if z == 0 and self._combo_used then
      if not self._k2_held and not self._k3_held then
        self._combo_used = false
      end
      return
    end

    -- Only intercept in live view
    if not (self.live_view_enabled and self.state.live_view) then
      return base_handle_key(self, n, z)
    end

    if n == 2 then
      if z == 1 then
        k2_held = true
        k2_e1_used = false
        k2_press_time = util.time()
      else
        k2_held = false
        if k2_e1_used then
          -- Stage count was adjusted via K2+E1; suppress other actions
        elseif (util.time() - k2_press_time) > 0.5 then
          -- Long press: play/stop toggle on focused lane
          local lane = _seeker.lanes[_seeker.ui_state.get_focused_lane()]
          if lane.playing then
            lane:stop()
          else
            lane:play({quantize = true})
          end
        else
          -- Short tap: toggle back to param view
          self:toggle_live_view()
        end
        if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      end
      return
    end

    if n == 3 then
      if z == 1 then
        -- K3 hold: randomize (journey style) via hold_confirm
        k3_randomized = false
        _seeker.hold_confirm.start({
          text = "randomize",
          threshold = 1.2,
          on_confirm = function()
            k3_randomized = true
            Composer.randomize("journey")
            update_live_arc(Composer)
            if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
          end
        })
      else
        -- K3 release: if hold_confirm didn't fire, cycle page
        if not k3_randomized then
          page_state:next_page()
        end
        _seeker.hold_confirm.cancel()
        update_live_arc(Composer)
        if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
      end
      return
    end

    -- Other keys: fall through to base
    base_handle_key(self, n, z)
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

  -- Wire arc/enc/key routing via PageState with Composer-specific arc refresh
  progression_page_state:wire(norns_ui, {
    refresh = function()
      update_progression_arc(Composer)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end,
  })

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

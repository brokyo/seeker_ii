-- init.lua
-- Drums type module entry point.
-- Wires step state, mutation, grid, home, and perform modules.

local Drums = {}

local DrumsType = include("lib/modes/motif/types/drums/type")
local lane_handlers = include("lib/modes/motif/sequencing/lane_handlers")
local LaneMap = include("lib/lanes/lane_map")
local theory = include("lib/modes/motif/core/theory")
local musicutil = require('musicutil')

local StepState = include("lib/modes/motif/types/drums/step_state")
local Mutation = include("lib/modes/motif/types/drums/mutation")
local DrumsGrid = include("lib/modes/motif/types/drums/grid")
local DrumsHome = include("lib/modes/motif/types/drums/home")
local DrumsPerform = include("lib/modes/motif/types/drums/perform")

-- Tracks which loop we're on within the call/response cycle per lane
local cr_loop_count = {}

function Drums.init()
  local instance = {
    sections = {},
    type = DrumsType,
  }

  DrumsGrid.set_step_state_ref(StepState)
  DrumsHome.set_step_state_ref(StepState)

  StepState.init()
  create_params()

  instance.grid = DrumsGrid.init()
  instance.home = DrumsHome.init()
  instance.perform = DrumsPerform.init()
  instance.step_state = StepState

  if instance.home.sections then
    for section_id, screen in pairs(instance.home.sections) do
      instance.sections[section_id] = screen
    end
  end

  instance.apply_motif = function(lane_id)
    StepState.apply_motif(lane_id)
  end

  local function lane_start_row(lane_id)
    local local_index = lane_id - LaneMap.OFFSETS.drums
    return (local_index - 1) * 2 + 1
  end

  lane_handlers.register(2, {
    prepare_stage = function(lane, stage)
      local lane_id = lane.id
      local length = StepState.get_length(lane_id)
      local local_index = lane_id - LaneMap.OFFSETS.drums
      local row_start = (local_index - 1) * 2 + 1

      -- Call/response alternation
      local use_response = false
      if StepState.is_cr_enabled(lane_id) then
        if not cr_loop_count[lane_id] then cr_loop_count[lane_id] = 0 end
        local call_loops = params:get("lane_" .. lane_id .. "_drum_cr_call_loops")
        local resp_loops = params:get("lane_" .. lane_id .. "_drum_cr_resp_loops")
        local cycle_length = call_loops + resp_loops
        local pos = cr_loop_count[lane_id] % cycle_length
        use_response = pos >= call_loops
        cr_loop_count[lane_id] = cr_loop_count[lane_id] + 1
      end

      StepState.set_playing_response(lane_id, use_response)

      -- Select source pattern
      local source_genesis
      local source_steps
      if use_response then
        source_genesis = StepState.get_response_genesis(lane_id)
        source_steps = StepState.get_response_steps(lane_id)
      else
        source_genesis = StepState.get_genesis(lane_id)
        source_steps = StepState.get_steps(lane_id)
      end

      -- Apply mutation if configured
      local half_cycle = params:get("lane_" .. lane_id .. "_drum_reseed")
      local steps

      if half_cycle > 0 then
        local displace = params:get("lane_" .. lane_id .. "_drum_mutate_displace")
        local pitch = params:get("lane_" .. lane_id .. "_drum_mutate_pitch")
        local density = params:get("lane_" .. lane_id .. "_drum_mutate_density")

        local loop_count = StepState.get_mutation_loop_count(lane_id)
        local depth = Mutation.triangle_depth(loop_count, half_cycle)
        StepState.increment_mutation_loop(lane_id)

        if depth > 0 and (displace > 0 or pitch > 0 or density > 0) then
          local scale = theory.get_scale()
          steps = Mutation.mutate_steps(source_genesis, depth, {
            displace = displace, pitch = pitch, density = density,
          }, lane_id, StepState.get_cycle_counter(lane_id), scale, length, StepState.deep_copy_steps)
        else
          steps = source_steps
        end
      else
        steps = source_steps
      end

      local events, duration = StepState.build_motif(steps, {
        length       = length,
        division     = StepState.get_division(lane_id),
        gate_pct     = StepState.get_gate_pct(lane_id),
        swing        = params:get("lane_" .. lane_id .. "_drum_swing") / 100,
        probability  = params:get("lane_" .. lane_id .. "_drum_probability"),
        default_note = StepState.get_voice_note(lane_id),
        row_start    = row_start,
      })

      lane.motif.events = events
      lane.motif.duration = duration
    end,

    is_muted = function(lane_id)
      return DrumsPerform.is_muted(lane_id)
    end,

    get_velocity_multiplier = function(lane_id)
      return DrumsPerform.get_velocity_multiplier(lane_id)
    end,

    note_positions = function(lane, note, event)
      if event.step and event.x and event.y then
        return {{x = event.x, y = event.y}}
      end
      local row = lane_start_row(lane.id)
      return {{x = 1, y = row}}
    end,

    get_active_positions = function(lane)
      return {}
    end,

    trail_mode = "immediate",
  })

  return instance
end

------------------------------------------------------------------------
-- Params
------------------------------------------------------------------------

local DIVISION_OPTIONS = StepState.DIVISION_OPTIONS

function create_params()
  for _, lane_id in ipairs(LaneMap.lanes_for_mode("drums")) do
    params:add_group("lane_" .. lane_id .. "_drum_step", "LANE " .. lane_id .. " DRUM STEPS", 12)

    params:add_number("lane_" .. lane_id .. "_drum_length", "Length", 1, 16, 8)
    params:set_action("lane_" .. lane_id .. "_drum_length", function()
      StepState.snapshot_genesis(lane_id)
      StepState.apply_motif(lane_id)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_option("lane_" .. lane_id .. "_drum_division", "Division", DIVISION_OPTIONS, 5)
    params:set_action("lane_" .. lane_id .. "_drum_division", function()
      StepState.apply_motif(lane_id)
      if _seeker.screen_ui then _seeker.screen_ui.set_needs_redraw() end
    end)

    params:add_number("lane_" .. lane_id .. "_drum_voice_note", "Voice Note", 1, 128, 36,
      function(param)
        local s = theory.get_scale()
        local midi = s[math.max(1, math.min(param:get(), #s))]
        return midi and musicutil.note_num_to_name(midi, true) or "?"
      end)
    params:set_action("lane_" .. lane_id .. "_drum_voice_note", function()
      StepState.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_gate_length", "Gate Length", 1, 100, 50,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_gate_length", function()
      StepState.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_swing", "Swing", 0, 100, 0,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_swing", function()
      StepState.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_probability", "Probability", 0, 100, 100,
      function(param) return param:get() .. "%" end)
    params:set_action("lane_" .. lane_id .. "_drum_probability", function()
      StepState.apply_motif(lane_id)
    end)

    params:add_number("lane_" .. lane_id .. "_drum_cr_call_loops", "C/R: Call Loops", 1, 16, 1)
    params:add_number("lane_" .. lane_id .. "_drum_cr_resp_loops", "C/R: Resp Loops", 1, 16, 1)

    params:add_number("lane_" .. lane_id .. "_drum_reseed", "Mutate Cycle", 0, 32, 0,
      function(param)
        local v = param:get()
        return v == 0 and "off" or (v .. " loops")
      end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_displace", "Mut: Displace", 0, 100, 0,
      function(param) return param:get() .. "%" end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_pitch", "Mut: Pitch", 0, 100, 0,
      function(param) return param:get() .. "%" end)

    params:add_number("lane_" .. lane_id .. "_drum_mutate_density", "Mut: Density", 0, 100, 0,
      function(param) return param:get() .. "%" end)
  end
end

return Drums

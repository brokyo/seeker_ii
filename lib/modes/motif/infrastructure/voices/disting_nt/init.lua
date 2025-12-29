-- disting_nt/init.lua
-- Main module for Disting NT voice control
--
-- Provides:
--   - Lane param creation
--   - Note on/off handling
--   - UI helpers for lane_config
--   - Chain preset management

local i2c = include("lib/modes/motif/infrastructure/voices/disting_nt/i2c")
local algorithms = include("lib/modes/motif/infrastructure/voices/disting_nt/algorithms")
local params_module = include("lib/modes/motif/infrastructure/voices/disting_nt/params")
local chains = include("lib/modes/motif/infrastructure/voices/disting_nt/chains")
local ui = include("lib/modes/motif/infrastructure/voices/disting_nt/ui")

local disting_nt = {}

disting_nt.name = "Disting NT"

------------------------------------------------------------
-- i2c Channel Allocation
------------------------------------------------------------

-- Global tracker for next available i2c channel (1-32)
-- Increments each time an algorithm is added
disting_nt.next_channel = 1

-- Maximum supported algorithms in a chain
local MAX_CHAIN_ALGOS = 4

------------------------------------------------------------
-- Re-export for external access
------------------------------------------------------------

disting_nt.algorithms = algorithms
disting_nt.chains = chains
disting_nt.i2c = i2c

-- Legacy compatibility: algorithm names list
disting_nt.ALGORITHMS = algorithms.VOICE_ALGORITHM_NAMES

------------------------------------------------------------
-- Chain Routing
------------------------------------------------------------

-- Get the i2c channel for an algorithm position in a lane's chain
function disting_nt.get_algo_channel(lane_idx, algo_position)
  local param_id = "lane_" .. lane_idx .. "_dnt_algo_" .. algo_position .. "_channel"
  if params.lookup[param_id] then
    return params:get(param_id)
  end
  return nil
end

-- Apply default routing for a chain (called when chain is activated)
function disting_nt.apply_default_routing(lane_idx)
  local chain_index = params:get("lane_" .. lane_idx .. "_dnt_chain")
  local chain_def = chains.get_by_index(chain_index)

  if not chain_def or not chain_def.default_routing then
    return
  end

  local prefix = "lane_" .. lane_idx .. "_dnt_"

  for _, route in ipairs(chain_def.default_routing) do
    local algo_id = chain_def.algorithms[route.algo_index]
    local algo_def = algorithms.get_by_id(algo_id)

    if algo_def then
      -- Build the param id and set the Norns param (for UI state)
      local param_id = prefix .. algo_def.param_prefix .. "_" .. route.param_id
      if params.lookup[param_id] then
        params:set(param_id, route.value)
      end

      -- Get the i2c channel for this algorithm position
      local channel = disting_nt.get_algo_channel(lane_idx, route.algo_index)
      if channel then
        for _, param_def in ipairs(algo_def.params) do
          if param_def.id == route.param_id then
            -- For option params, value is already 1-indexed but NT expects 0-indexed
            local nt_value = route.value
            if param_def.type == "option" then
              nt_value = route.value - 1
            end
            i2c.set_param_at_channel(channel, param_def.param_num, nt_value)
            break
          end
        end
      end
    end
  end
end

------------------------------------------------------------
-- Lane Param Creation
------------------------------------------------------------

function disting_nt.create_params(lane_idx)
  local prefix = "lane_" .. lane_idx .. "_"

  -- Chain selector (all algorithms + multi-algo chains in one dropdown)
  params:add_option(prefix .. "dnt_chain", "Algorithm", chains.CHAIN_NAMES, 1)
  params:set_action(prefix .. "dnt_chain", function(value)
    -- Reset chain position when changing chains
    params:set(prefix .. "dnt_chain_position", 1)
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  -- Internal active state (not directly editable)
  params:add_binary(prefix .. "disting_nt_active", "Active", "toggle", 0)
  params:hide(prefix .. "disting_nt_active")
  params:set_action(prefix .. "disting_nt_active", function(value)
    _seeker.lanes[lane_idx].disting_nt_active = (value == 1)
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  -- Per-algorithm i2c channel params (set automatically on Add, editable for override)
  for i = 1, MAX_CHAIN_ALGOS do
    local algo_idx = i  -- capture for closure
    params:add_number(prefix .. "dnt_algo_" .. i .. "_channel", "Algo " .. i .. " i2c Ch", 0, 32, 0)
    params:set_action(prefix .. "dnt_algo_" .. i .. "_channel", function(channel)
      if channel > 0 then
        -- When channel changes, update the NT algorithm's i2c_channel param
        local chain_index = params:get(prefix .. "dnt_chain")
        local chain_def = chains.get_by_index(chain_index)
        if chain_def and chain_def.algorithms[algo_idx] then
          local algo_id = chain_def.algorithms[algo_idx]
          local algo_def = algorithms.get_by_id(algo_id)
          if algo_def then
            for _, param_def in ipairs(algo_def.params) do
              if param_def.id == "i2c_channel" then
                i2c.set_param_at_channel(channel, param_def.param_num, channel)
                break
              end
            end
          end
        end
      end
    end)
  end

  -- Add action: allocates i2c channels and activates
  params:add_binary(prefix .. "dnt_add", "Add", "trigger", 0)
  params:set_action(prefix .. "dnt_add", function(value)
    if value == 1 and params:get(prefix .. "disting_nt_active") == 0 then
      local chain_index = params:get(prefix .. "dnt_chain")
      local chain_def = chains.get_by_index(chain_index)
      local algo_count = chain_def and #chain_def.algorithms or 1

      -- Allocate i2c channels for each algorithm in chain
      for i = 1, algo_count do
        local channel = disting_nt.next_channel
        params:set(prefix .. "dnt_algo_" .. i .. "_channel", channel)

        -- Tell NT algorithm to listen on this channel
        local algo_id = chain_def.algorithms[i]
        local algo_def = algorithms.get_by_id(algo_id)
        if algo_def then
          -- Find i2c_channel param_num for this algorithm
          for _, param_def in ipairs(algo_def.params) do
            if param_def.id == "i2c_channel" then
              i2c.set_param_at_channel(channel, param_def.param_num, channel)
              break
            end
          end
        end

        disting_nt.next_channel = disting_nt.next_channel + 1
      end

      local first_channel = params:get(prefix .. "dnt_algo_1_channel")
      if _seeker.modal then
        _seeker.modal.show_toast({ body = "NT Ch " .. first_channel .. " +" .. algo_count })
      end

      params:set(prefix .. "disting_nt_active", 1)
      disting_nt.apply_default_routing(lane_idx)
    end
  end)

  -- Remove action: clears channels and deactivates
  params:add_binary(prefix .. "dnt_remove", "Remove", "trigger", 0)
  params:set_action(prefix .. "dnt_remove", function(value)
    if value == 1 and params:get(prefix .. "disting_nt_active") == 1 then
      -- Clear allocated channels
      for i = 1, MAX_CHAIN_ALGOS do
        params:set(prefix .. "dnt_algo_" .. i .. "_channel", 0)
      end
      if _seeker.modal then
        _seeker.modal.show_toast({ body = "NT: Removed" })
      end
      params:set(prefix .. "disting_nt_active", 0)
    end
  end)

  -- Lane volume
  params:add_control(prefix .. "disting_nt_volume", "Volume",
    controlspec.new(0, 1, 'lin', 0.01, 1, ""))
  params:set_action(prefix .. "disting_nt_volume", function(value)
    _seeker.lanes[lane_idx].disting_nt_volume = value
  end)

  -- Chain position selector (which algorithm in chain to edit, for multi-algo chains)
  params:add_number(prefix .. "dnt_chain_position", "Edit Position", 1, 8, 1)
  params:set_action(prefix .. "dnt_chain_position", function(value)
    _seeker.lane_config.screen:rebuild_params()
    _seeker.screen_ui.set_needs_redraw()
  end)

  -- Create params for all algorithms (they'll be shown/hidden based on selection)
  params_module.create_all_voice_params(lane_idx)
end

------------------------------------------------------------
-- Voice Interface (called by lane.lua)
------------------------------------------------------------

function disting_nt.is_active(lane_idx)
  return params:get("lane_" .. lane_idx .. "_disting_nt_active") == 1
end

-- Get the first algorithm definition for a lane's current chain
local function get_lane_algorithm(lane_idx)
  local chain_index = params:get("lane_" .. lane_idx .. "_dnt_chain")
  local chain_def = chains.get_by_index(chain_index)
  if not chain_def or not chain_def.algorithms then return nil end

  local first_algo_id = chain_def.algorithms[1]
  return algorithms.get_by_id(first_algo_id)
end

function disting_nt.handle_note_on(lane_idx, note, event_velocity)
  local channel = disting_nt.get_algo_channel(lane_idx, 1)
  if not channel or channel == 0 then return end

  local algo_def = get_lane_algorithm(lane_idx)

  -- Strum-type algorithms: trigger via param, pitch ignored
  if algo_def and algo_def.note_input_type == "strum" then
    i2c.set_param_at_channel(channel, algo_def.strum_param_num, 1)
    return
  end

  -- Pitch-type algorithms: set transpose param, VCO drones continuously
  if algo_def and algo_def.note_input_type == "pitch" then
    local transpose = note - 60  -- Semitones from middle C
    i2c.set_param_at_channel(channel, algo_def.transpose_param_num, transpose)
    return
  end

  -- Standard polyphonic note handling
  local voice_volume = params:get("lane_" .. lane_idx .. "_disting_nt_volume")
  local lane_volume = params:get("lane_" .. lane_idx .. "_volume")

  local nt_pitch = i2c.midi_to_pitch(note)
  local nt_velocity = i2c.scale_velocity(event_velocity, voice_volume * lane_volume)

  i2c.note_pitch(channel, note, nt_pitch)
  i2c.note_on(channel, note, nt_velocity)
end

function disting_nt.handle_note_off(lane_idx, note)
  local channel = disting_nt.get_algo_channel(lane_idx, 1)
  if not channel or channel == 0 then return end

  local algo_def = get_lane_algorithm(lane_idx)

  -- Strum-type: reset strum param for next trigger
  if algo_def and algo_def.note_input_type == "strum" then
    i2c.set_param_at_channel(channel, algo_def.strum_param_num, 0)
    return
  end

  -- Pitch-type: do nothing, VCO keeps droning at last pitch
  if algo_def and algo_def.note_input_type == "pitch" then
    return
  end

  -- Standard polyphonic note handling
  i2c.note_off(channel, note)
end

------------------------------------------------------------
-- Public Note API (for direct access)
------------------------------------------------------------

function disting_nt.note_pitch(channel, note_id, pitch)
  i2c.note_pitch(channel, note_id, pitch)
end

function disting_nt.note_on(channel, note_id, velocity)
  i2c.note_on(channel, note_id, velocity)
end

function disting_nt.note_off(channel, note_id)
  i2c.note_off(channel, note_id)
end

function disting_nt.all_notes_off()
  i2c.all_notes_off()
end

function disting_nt.midi_to_pitch(midi_note)
  return i2c.midi_to_pitch(midi_note)
end

function disting_nt.scale_velocity(velocity_0_127, volume_multiplier)
  return i2c.scale_velocity(velocity_0_127, volume_multiplier)
end

------------------------------------------------------------
-- UI Helper (called by lane_config)
------------------------------------------------------------

-- Returns algorithm-specific params (delegated to ui module)
function disting_nt.get_params_for_ui(lane_idx)
  return ui.get_params_for_ui(lane_idx)
end

-- Returns full voice UI structure for lane_config registry
function disting_nt.get_ui_params(lane_idx)
  local ui_params = {}

  -- Chain/algorithm selector first
  table.insert(ui_params, { id = "lane_" .. lane_idx .. "_dnt_chain" })
  table.insert(ui_params, { id = "lane_" .. lane_idx .. "_disting_nt_active" })

  if params:get("lane_" .. lane_idx .. "_disting_nt_active") == 1 then
    table.insert(ui_params, { separator = true, title = "Voice Settings" })
    table.insert(ui_params, { id = "lane_" .. lane_idx .. "_disting_nt_volume", arc_multi_float = {0.1, 0.05, 0.01} })

    -- Append algorithm-specific params
    local algorithm_params = ui.get_params_for_ui(lane_idx)
    for _, entry in ipairs(algorithm_params) do
      table.insert(ui_params, entry)
    end
  end

  return ui_params
end

------------------------------------------------------------
-- Diagnostic tool
------------------------------------------------------------

function disting_nt.probe_param(channel, param_num, value)
  print("disting_nt: probing ch=" .. channel .. " param=" .. param_num .. " val=" .. value)
  i2c.select_algorithm(channel)
  i2c.set_param(param_num, value)
end

return disting_nt

-- disting_nt/params.lua
-- Generic param creation from algorithm definitions

local i2c = include("lib/modes/motif/infrastructure/voices/disting_nt/i2c")
local algorithms = include("lib/modes/motif/infrastructure/voices/disting_nt/algorithms")
local chains = include("lib/modes/motif/infrastructure/voices/disting_nt/chains")
-- Optional user-generated DX7 patch name lookup (not distributed, see .gitignore)
local ok, patch_names = pcall(include, "lib/modes/motif/infrastructure/voices/disting_nt/patch_names")
if not ok then patch_names = {} end

local params_module = {}

-- Sysex module reference (set by init.lua to ensure same instance)
local sysex = nil

function params_module.set_sysex(sysex_module)
  sysex = sysex_module
end

------------------------------------------------------------
-- Get i2c channel for an algorithm in a lane's chain
------------------------------------------------------------

-- Get algorithm position and channel for an algo in a lane's chain
local function get_algo_position_and_channel(lane_idx, algo_id)
  local chain_index = params:get("lane_" .. lane_idx .. "_dnt_chain")
  local chain_def = chains.get_by_index(chain_index)
  if not chain_def or not chain_def.algorithms then return nil, nil end

  for position, id in ipairs(chain_def.algorithms) do
    if id == algo_id then
      local channel = params:get("lane_" .. lane_idx .. "_dnt_algo_" .. position .. "_channel")
      return position, (channel and channel > 0) and channel or nil
    end
  end
  return nil, nil
end

-- Get stored algorithm index for a position in a lane
local function get_algo_index_for_position(lane_idx, position)
  local algo_data = sysex.get_lane_algorithms(lane_idx)
  if algo_data and algo_data.indices and algo_data.indices[position] then
    return algo_data.indices[position]
  end
  return nil
end

------------------------------------------------------------
-- Send param value to NT via i2c
------------------------------------------------------------

local function send_param_to_channel(channel, param_num, value, algo_index)
  if channel == nil or param_num == nil then return end
  i2c.select_algorithm(channel)
  i2c.set_param(param_num, value)
  -- Show this param on NT hardware display
  if algo_index then
    sysex.set_focus(algo_index, param_num)
  end
end

------------------------------------------------------------
-- Create a single param from definition
------------------------------------------------------------

local function create_param(lane_idx, algo_def, param_def)
  local prefix = "lane_" .. lane_idx .. "_dnt_" .. algo_def.param_prefix .. "_"
  local param_id = prefix .. param_def.id
  local algo_id = algo_def.id

  -- Resolve options if it's a reference string
  local options = param_def.options and algorithms.resolve_options(param_def.options)

  -- Optional rebuild trigger for params that affect UI visibility
  local function maybe_rebuild()
    if param_def.triggers_rebuild then
      _seeker.lane_config.screen:rebuild_params()
      _seeker.screen_ui.set_needs_redraw()
    end
  end

  if param_def.type == "option" then
    params:add_option(param_id, param_def.name, options, param_def.default)
    params:set_action(param_id, function(value)
      local position, channel = get_algo_position_and_channel(lane_idx, algo_id)
      local algo_index = get_algo_index_for_position(lane_idx, position)
      send_param_to_channel(channel, param_def.param_num, value - 1, algo_index)
      maybe_rebuild()
    end)

  elseif param_def.type == "number" then
    local formatter = nil
    if param_def.formatter == "midi_note" then
      formatter = function(p) return algorithms.midi_to_note_name(p:get()) end
    elseif param_def.formatter == "patch_name" then
      -- Show DX7 patch name from bank+voice lookup
      local bank_param_id = prefix .. "bank"
      formatter = function(p)
        local voice = p:get()
        local bank = params:get(bank_param_id)
        local bank_patches = patch_names[bank]
        if bank_patches and bank_patches[voice] then
          return bank_patches[voice]
        end
        return tostring(voice)
      end
    end
    params:add_number(param_id, param_def.name, param_def.min, param_def.max, param_def.default, formatter)
    params:set_action(param_id, function(value)
      local position, channel = get_algo_position_and_channel(lane_idx, algo_id)
      local algo_index = get_algo_index_for_position(lane_idx, position)
      send_param_to_channel(channel, param_def.param_num, value, algo_index)
    end)

  elseif param_def.type == "control" then
    local step = param_def.step or 1
    local unit = param_def.unit or ""
    local cs = controlspec.new(param_def.min, param_def.max, 'lin', step, param_def.default, unit)
    params:add_control(param_id, param_def.name, cs)
    params:set_action(param_id, function(value)
      local scaled = value
      if param_def.scale then
        scaled = math.floor(value * param_def.scale)
      else
        scaled = math.floor(value)
      end
      local position, channel = get_algo_position_and_channel(lane_idx, algo_id)
      local algo_index = get_algo_index_for_position(lane_idx, position)
      send_param_to_channel(channel, param_def.param_num, scaled, algo_index)
    end)
  end

  -- Hide param if marked hidden
  if param_def.hidden then
    params:hide(param_id)
  end
end

------------------------------------------------------------
-- Create all params for an algorithm
------------------------------------------------------------

function params_module.create_algorithm_params(lane_idx, algo_id)
  local algo_def = algorithms.get_by_id(algo_id)
  if not algo_def then
    print("disting_nt: unknown algorithm: " .. tostring(algo_id))
    return
  end

  for _, param_def in ipairs(algo_def.params) do
    create_param(lane_idx, algo_def, param_def)
  end
end

------------------------------------------------------------
-- Create all voice algorithm params for a lane
------------------------------------------------------------

function params_module.create_all_voice_params(lane_idx)
  for _, algo_id in ipairs(algorithms.VOICE_ALGORITHMS) do
    params_module.create_algorithm_params(lane_idx, algo_id)
  end

  -- Also create effect algorithm params (for chains)
  for _, algo_id in ipairs(algorithms.EFFECT_ALGORITHMS) do
    params_module.create_algorithm_params(lane_idx, algo_id)
  end
end

return params_module

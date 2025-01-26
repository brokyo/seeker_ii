-- params_manager_ii.lua
-- A clean start for params management, focused on core functionality

local params_manager_ii = {}

-- Get sorted list of available instruments
function params_manager_ii.get_instrument_list()
  local instruments = {}
  for k,v in pairs(_seeker.skeys.instrument) do
    table.insert(instruments, k)
  end
  table.sort(instruments)
  return instruments
end

-- Initialize just the essential parameters we need
function params_manager_ii.init_params()
  -- Initialize instrument parameters for lanes 1-4
  local instruments = params_manager_ii.get_instrument_list()
  for i = 1,4 do
    params:add_option("lane_" .. i .. "_instrument", "Instrument", instruments, 1)
  end
end

return params_manager_ii 
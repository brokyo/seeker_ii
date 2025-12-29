-- disting_nt/ui.lua
-- UI helpers for lane_config integration

local algorithms = include("lib/modes/motif/infrastructure/voices/disting_nt/algorithms")
local chains = include("lib/modes/motif/infrastructure/voices/disting_nt/chains")

local ui = {}

------------------------------------------------------------
-- Arc sensitivity fallback for params without explicit values
------------------------------------------------------------

local DEFAULT_ARC_MULTI_FLOAT = {10, 5, 1}

------------------------------------------------------------
-- Generate UI entries for a single algorithm
------------------------------------------------------------

local function get_algorithm_ui_entries(lane_idx, algo_def)
  local entries = {}
  local prefix = "lane_" .. lane_idx .. "_dnt_" .. algo_def.param_prefix .. "_"

  for _, section in ipairs(algo_def.ui_sections) do
    -- Track if we added any params in this section
    local section_entries = {}

    -- Add params in this section
    for _, param_id in ipairs(section.params) do
      -- Find param definition
      local param_def = nil
      for _, p in ipairs(algo_def.params) do
        if p.id == param_id then
          param_def = p
          break
        end
      end

      if param_def and not param_def.hidden then
        -- Check visibility condition
        local visible = true
        if param_def.visible_when then
          local check_param_id = prefix .. param_def.visible_when.param
          local current_value = params:get(check_param_id)
          visible = (current_value == param_def.visible_when.value)
        end

        if visible then
          local entry = { id = prefix .. param_id }

          -- Add arc sensitivity: use param-specific value or fall back to default
          if param_def.arc_multi_float then
            entry.arc_multi_float = param_def.arc_multi_float
          elseif param_def.type == "control" or
                 (param_def.type == "number" and (param_def.max - param_def.min) > 20) then
            entry.arc_multi_float = DEFAULT_ARC_MULTI_FLOAT
          end

          table.insert(section_entries, entry)
        end
      end
    end

    -- Only add section separator if we have params to show
    if #section_entries > 0 then
      table.insert(entries, { separator = true, title = section.title })
      for _, entry in ipairs(section_entries) do
        table.insert(entries, entry)
      end
    end
  end

  return entries
end

------------------------------------------------------------
-- Get params UI for current algorithm selection
------------------------------------------------------------

function ui.get_params_for_ui(lane_idx)
  local chain_index = params:get("lane_" .. lane_idx .. "_dnt_chain")
  local chain_def = chains.get_by_index(chain_index)

  if not chain_def or not chain_def.algorithms then
    return {}
  end

  local entries = {}

  if chain_def.is_single then
    -- Single algorithm: show its params directly
    local algo_id = chain_def.algorithms[1]
    local algo_def = algorithms.get_by_id(algo_id)

    if algo_def then
      local algo_entries = get_algorithm_ui_entries(lane_idx, algo_def)
      for _, entry in ipairs(algo_entries) do
        table.insert(entries, entry)
      end
    end
  else
    -- Multi-algo chain: show position selector to pick which algo to edit
    table.insert(entries, { id = "lane_" .. lane_idx .. "_dnt_chain_position" })

    local chain_position = params:get("lane_" .. lane_idx .. "_dnt_chain_position")
    -- Clamp position to valid range
    chain_position = math.min(chain_position, #chain_def.algorithms)

    local algo_id = chain_def.algorithms[chain_position]
    local algo_def = algorithms.get_by_id(algo_id)

    if algo_def then
      -- Show which part of chain we're editing
      table.insert(entries, { separator = true, title = "Editing: " .. algo_def.name })

      local algo_entries = get_algorithm_ui_entries(lane_idx, algo_def)
      for _, entry in ipairs(algo_entries) do
        table.insert(entries, entry)
      end
    end
  end

  -- Show allocated channels at bottom
  local algo_count = #chain_def.algorithms
  if algo_count > 0 then
    table.insert(entries, { separator = true, title = "i2c Channels" })
    for i = 1, algo_count do
      table.insert(entries, { id = "lane_" .. lane_idx .. "_dnt_algo_" .. i .. "_channel" })
    end
  end

  return entries
end

------------------------------------------------------------
-- Get chain position names for UI dropdown
------------------------------------------------------------

function ui.get_chain_position_names(lane_idx)
  local chain_index = params:get("lane_" .. lane_idx .. "_dnt_chain")
  local chain_def = chains.get_by_index(chain_index)

  if not chain_def or chain_def.is_single then
    return {"N/A"}
  end

  local names = {}
  for i, algo_id in ipairs(chain_def.algorithms) do
    local algo_def = algorithms.get_by_id(algo_id)
    if algo_def then
      table.insert(names, i .. ". " .. algo_def.name)
    end
  end

  return names
end

return ui

-- type_registry.lua
-- Registry for motif types (Tape, Composer, Sampler)
-- Provides unified access to current type's draw/handle functions

local type_registry = {}

-- Lazy-load type modules to avoid circular dependencies
local types = {}

local function get_type(motif_type)
  if not types[motif_type] then
    local type_paths = {
      [1] = nil,  -- TAPE: not yet extracted
      [2] = "lib/modes/motif/composer/type",  -- COMPOSER
      [3] = "lib/modes/motif/sampler/type"    -- SAMPLER
    }

    if type_paths[motif_type] then
      types[motif_type] = include(type_paths[motif_type])
    end
  end

  return types[motif_type]
end

function type_registry.get_current()
  local focused_lane = _seeker.ui_state.get_focused_lane()
  local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")
  return get_type(motif_type)
end

function type_registry.get(motif_type)
  return get_type(motif_type)
end

return type_registry

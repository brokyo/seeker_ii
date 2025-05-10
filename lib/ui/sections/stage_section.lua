-- stage_section.lua
local Section = include('lib/ui/section')
local transforms = include('lib/transforms')
local StageSection = setmetatable({}, { __index = Section })
StageSection.__index = StageSection

function StageSection.new()
  local section = Section.new({
    id = "STAGE",
    name = "Stage 1",
    icon = "⌸",
    description = "Change stages pattern playback. ",
    params = {}
  })
  
  
  -- HOTFIX: Skip Arc integration for this section to prevent crashes
  -- TODO: Properly implement Arc integration for this custom UI section
  section.skip_arc = true

  setmetatable(section, StageSection)

  -- Get sorted list of transform names once
  local transform_names = {}
  for _, name in ipairs(transforms.transform_order) do
    table.insert(transform_names, name)
  end
  section.transform_names = transform_names
  
  -- Store dynamic parameter specs separated from the original definitions
  section.dynamic_param_specs = {}
  
  -- Helper function to get the dynamic param spec (with context-specific values)
  function section:get_dynamic_param_spec(transform_name, param_name)
    -- Create a key to store the dynamic parameter specs
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local key = string.format("lane_%d_stage_%d_%s_%s", lane_idx, stage_idx, transform_name, param_name)
    
    -- Get the original parameter specification
    local orig_spec = transforms.available[transform_name].params[param_name]
    if not orig_spec then return nil end
    
    -- If we don't have a dynamic spec for this parameter yet, create one
    if not section.dynamic_param_specs[key] then
      -- Create a copy of the original spec
      local dynamic_spec = {}
      for k, v in pairs(orig_spec) do
        dynamic_spec[k] = v
      end
      
      -- Store the dynamic spec
      section.dynamic_param_specs[key] = dynamic_spec
    end
    
    return section.dynamic_param_specs[key]
  end

  function section:get_param_value(param)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]
    
    -- Handle transform params
    if param.id:match("^transform_") then
      if not stage.transforms[1] then return "" end
      local transform = stage.transforms[1]
      
      if param.id:match("_type$") then
        return transform.name
      else
        local param_name = param.id:match("transform_(.+)$")
        local value = transform.config[param_name]
        
        -- Get the dynamic parameter spec
        local param_spec = self:get_dynamic_param_spec(transform.name, param_name)
        
        -- Handle option type parameters first (most specific handling)
        if param_spec and param_spec.type == "option" and param_spec.options then
          if type(value) == "number" then
            return param_spec.options[value] or tostring(value)
          else
            return tostring(value)
          end
        end
        
        -- Use formatter if available (for special cases)
        if param_spec and param_spec.formatter then
          return param_spec.formatter(value)
        end
        
        -- Default formatting for numeric values
        if type(value) == "number" then
          if param_spec and param_spec.type == "integer" then
            return tostring(math.floor(value + 0.5))
          else
            return string.format("%.2f", value)
          end
        end
        
        -- Fallback for any other value types
        return tostring(value or "")
      end
    end

    -- Handle other stage params
    return params:get(param.id)
  end

  function section:modify_param(param, delta)
    if param.id:match("^transform_") then
      self:set_transform_param_value(param.id, delta)
    else
      params:delta(param.id, delta)
    end
  end

  function section:set_transform_param_value(param_id, delta)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage_idx = _seeker.ui_state.get_focused_stage()
    local stage = _seeker.lanes[lane_idx].stages[stage_idx]
    
    if not stage.transforms[1] then return end
    local transform = stage.transforms[1]

    if param_id:match("_type$") then
      -- Change transform type
      local current_idx = tab.key(self.transform_names, transform.name)
      local new_idx = util.clamp(current_idx + delta, 1, #self.transform_names)
      local new_name = self.transform_names[new_idx]
      
      _seeker.lanes[lane_idx]:change_stage_transform(lane_idx, stage_idx, 1, new_name)
      -- Clear dynamic parameter specs when changing transform type
      self.dynamic_param_specs = {}
      -- After changing transform type, update the section to show new params
      self:update_focused_stage(stage_idx)
    else
      -- Modify transform parameter
      local param_name = param_id:match("transform_(.+)$")
      
      -- Get the dynamic parameter spec
      local param_spec = self:get_dynamic_param_spec(transform.name, param_name)
      if not param_spec then return end
      
      local current = transform.config[param_name]
      
      -- Handle different parameter types
      if param_spec.type == "option" then
        -- Handle option type parameters
        local options = param_spec.options
        local current_idx = current
        if type(current) ~= "number" then
          -- Find the current option index if it's not a number
          for i, opt in ipairs(options) do
            if opt == current then
              current_idx = i
              break
            end
          end
        end
        
        -- Calculate new index with wrap-around
        local new_idx = ((current_idx - 1 + delta) % #options) + 1
        transform.config[param_name] = new_idx
      else
        -- Handle numeric parameters (integer and number types)
        local step = param_spec.step or (param_spec.type == "integer" and 1 or (param_spec.max - param_spec.min) / 20)
        
        local new_value = util.clamp(
          current + (delta * step),
          param_spec.min,
          param_spec.max
        )

        transform.config[param_name] = new_value
        if param_spec.type == "integer" then
          transform.config[param_name] = math.floor(transform.config[param_name] + 0.5)
        end
      end
    end
  end

  function section:update_focused_stage(new_stage_idx)
    local lane_idx = _seeker.ui_state.get_focused_lane()
    local stage = _seeker.lanes[lane_idx].stages[new_stage_idx]
    
    -- Clear dynamic parameter cache when updating focused stage
    self.dynamic_param_specs = {}
    
    -- Build param list starting with transform controls
    self.params = {
      { separator = true, name = "Transform Config" }
    }

    -- Add transform params if stage has transforms
    if stage and stage.transforms and stage.transforms[1] then
      local transform = stage.transforms[1]
      local transform_def = transforms.available[transform.name]
      
      -- Add transform type selector with header
      table.insert(self.params, {
        id = "transform_type",
        name = "Transform Config",
        value = transform.name,
        values = self.transform_names,
        is_header = true
      })

      -- Add transform-specific params
      if transform_def and transform_def.params then
        -- Collect and sort params by order
        local ordered_params = {}
        for param_name, param_spec in pairs(transform_def.params) do
          -- Get dynamic spec for this parameter
          local dynamic_spec = self:get_dynamic_param_spec(transform.name, param_name)
          table.insert(ordered_params, {name = param_name, spec = dynamic_spec})
        end
        table.sort(ordered_params, function(a, b) 
          return (a.spec.order or 100) < (b.spec.order or 100)
        end)
        
        -- Add params in order
        for _, param in ipairs(ordered_params) do
          table.insert(self.params, {
            id = "transform_" .. param.name,
            name = "  " .. param.name,
            value = transform.config[param.name],
            spec = param.spec
          })
        end
      end
    end

    -- Add stage controls after transforms
    table.insert(self.params, { separator = true, name = "Stage Config" })
    table.insert(self.params, { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_mute", name = "Mute" })
    table.insert(self.params, { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_reset_motif", name = "Reset Motif" })
    table.insert(self.params, { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loops", name = "Loops" })
    table.insert(self.params, { id = "lane_" .. lane_idx .. "_stage_" .. new_stage_idx .. "_loop_trigger", name = "Loop Trigger" })

    self.name = string.format("Stage %d", new_stage_idx)
    _seeker.ui_state.dirty = true -- Mark UI for refresh
  end

  -- Add enter method to ensure section is initialized with current stage
  function section:enter()
    Section.enter(self)  -- Call parent enter method
    self:update_focused_stage(_seeker.ui_state.get_focused_stage())
  end

  return section
end

return StageSection


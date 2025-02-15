-- generate_section.lua
local Section = include('lib/ui/section')
local MotifGenerator = include('lib/motif_generator')
local GenerateSection = setmetatable({}, { __index = Section })
GenerateSection.__index = GenerateSection

function GenerateSection.new()
  local section = Section.new({
    id = "GENERATE",
    name = "Generate",
    params = {}
  })
  setmetatable(section, GenerateSection)
  
  -- Section state
  section.state = {
    selected_index = 1,  -- Initialize to first parameter
    scroll_offset = 0,
    is_active = false,
    current_generator = "starlight",
    param_values = MotifGenerator.get_default_params("starlight")
  }

  -- Get param value for display
  function section:get_param_value(param)
    if param.id == "generator_type" then
      local gen = MotifGenerator.get_generator_spec(self.state.current_generator)
      return gen.name
    else
      local gen = MotifGenerator.get_generator_spec(self.state.current_generator)
      local spec = gen.params[param.id]
      return MotifGenerator.format_param_value(self.state.param_values[param.id], spec)
    end
  end

  -- Handle parameter modification
  function section:modify_param(param, delta)
    if param.id == "generator_type" then
      -- Get ordered list of generators
      local generators = MotifGenerator.get_generators()
      
      -- Find current index
      local current_idx = 1
      for i, gen in ipairs(generators) do
        if gen.id == self.state.current_generator then
          current_idx = i
          break
        end
      end
      
      -- Calculate new index
      local new_idx = util.clamp(current_idx + delta, 1, #generators)
      local new_generator = generators[new_idx].id
      
      if new_generator ~= self.state.current_generator then
        -- Switch generator and initialize params
        self.state.current_generator = new_generator
        self.state.param_values = MotifGenerator.get_default_params(new_generator)
        self:update_param_list()
      end
    else
      -- Get generator spec
      local gen = MotifGenerator.get_generator_spec(self.state.current_generator)
      local spec = gen.params[param.id]
      
      -- Update parameter value using delta
      self.state.param_values[param.id] = MotifGenerator.process_param_update(
        param.id,
        delta,
        spec,
        true,  -- Always delta-based in our UI
        self.state.param_values[param.id]
      )
    end
  end

  -- Generate a motif with current parameters
  function section:generate_motif()
    return MotifGenerator.generate(
      self.state.current_generator,
      self.state.param_values
    )
  end

  -- Update parameter list based on current generator
  function section:update_param_list()
    -- Start with generator type selector
    self.params = {
      {
        id = "generator_type",
        name = "Generator Type",
        spec = { 
          type = "option", 
          values = MotifGenerator.get_generators()
        }
      }
    }
    
    -- Get current generator's parameters
    local gen = MotifGenerator.get_generator_spec(self.state.current_generator)
    
    -- Add separator with generator description
    if gen.description then
      table.insert(self.params, { 
        separator = true, 
        name = gen.description 
      })
    end
    
    -- Add generator-specific parameters
    for param_id, spec in pairs(gen.params) do
      table.insert(self.params, {
        id = param_id,
        name = "  " .. (spec.name or param_id),  -- Indent params
        spec = spec
      })
    end
  end

  -- Initialize param list
  section:update_param_list()

  return section
end

return GenerateSection 
-- arc.lua

local Arc = {}

function Arc.init()
  local device = arc.connect()
  
  if device then 
    print("☯ Arc Connected")
    --  Append some useful UI stuff to the device so we can use it from the rest of the app

    -- Parameters for state tracking
    device.index = {0, 0, 0, 0}
    device.current_section_param_count = 0
    -- HOTFIX: Flag to ignore certain sections (like Tuning) that don't follow the standard params pattern
    -- TODO: Implement proper integration for special sections instead of skipping them
    device.skip_current_section = false

    -- Triggers on section navigation (comes from 'section:enter()' in section.lua)
    device.new_section = function(params)
      -- HOTFIX: Check if we should ignore this section
      -- TODO: Refactor to properly handle sections with custom parameter systems
      local current_section_id = _seeker.ui_state.get_current_section()
      local current_section = _seeker.screen_ui.sections[current_section_id]
      
      -- Skip sections that have the skip_arc
      if current_section and current_section.skip_arc then
        device.skip_current_section = true
        -- Clear all LEDs
        for n = 1, 4 do
          for i = 1, 64 do
            device:led(n, i, 0)
          end
        end
        device:refresh()
        return
      end
      
      device.skip_current_section = false
      
      -- Update the number of params
      device.current_section_param_count = #params

      -- Drawn a dimmed LED ring
      for i = 1, 64 do
        device:led(1, i, 3)
      end

      -- Calculate the number of LEDs to illuminate based on the number of params
      local num_leds = math.floor(64 / device.current_section_param_count)

      -- And set illuminate the first parameter cluster
      for i = 1, num_leds do
        device:led(1, i, 10)
      end      

       device:refresh()
    end

    device.update_display = function(n)
      -- HOTFIX: Skip Arc updates for special sections
      if device.skip_current_section then return end
      
      device:refresh()
    end

    -- Set up delta handler slows down the Arc's response by only triggering every 8th movement.
    device.delta = function(n, delta)
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end
      
      -- Register activity to wake screen/restart sleep timer

      _seeker.ui_state.register_activity()
      -- offset counter on rotation (modulo 64 to stay aligned with the LED ring)
      device.index[n] = device.index[n] + delta % 64

      -- Only trigger every 8th consecutive movement (improves UX)
      if device.index[n] % 8 == 0 then       
        -- Determine movement direction based on last delta direction
        local direction
        if delta > 0 then
          direction = 1
        else
          direction = -1
        end
        
        -- Map Arc encoder 1 to Norns encoder 2. Use custom param key illumination logic.
        if n == 1 then
          _seeker.ui_state.enc(2, direction)
          device.update_param_key_display()

          -- Update the param ring to keep in sync
          device.update_param_value_display()

        -- Map Arc encoder 2 to Norns encoder 3. Use custom param value illumination logic.
        elseif n == 2 then
          _seeker.ui_state.enc(3, direction)
          device.update_param_value_display()
        end        
      end
    end

    device.key = function(n, d)
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end
      
      if d == 1 then
        -- Get current section and selected parameter
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local selected_param = current_section.params[current_section.state.selected_index]
        
        -- If selected parameter is an action, trigger it
        if selected_param and selected_param.action then
          current_section:modify_param(selected_param, 1)

          -- Flash the action LED
          for i = 1, 64 do
            device:led(2, i, 10)
          end

          device:refresh()
        end
      end
    end


    -- Update the param key display
    device.update_param_key_display = function()
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end
      -- Set base illumination
      for i = 1, 64 do
        device:led(1, i, 3)
      end

      -- Get selected index from current section
      local current_section_id = _seeker.ui_state.get_current_section()
      local current_section = _seeker.screen_ui.sections[current_section_id]
      local param_key_index = current_section.state.selected_index

      -- Translate param key to LED index
      local led_starting_point = math.floor((param_key_index * 64) / device.current_section_param_count)

      -- Calculate the number of LEDs to illuminate
      local num_leds = math.floor(64 / device.current_section_param_count)

      -- Illuminate the relevant LED cluster
      for i = 1, num_leds do
        device:led(1, i + led_starting_point, 10)
      end

      device:refresh()
    end

    -- Helper function for displaying a value's position within a range on the LED ring
    local function update_option_ring(current_pos, total_positions)
      -- Translate position to LED index
      local led_starting_point = math.floor((current_pos * 64) / total_positions)

      -- Calculate the number of LEDs to illuminate
      local num_leds = math.floor(64 / total_positions)
      
      -- Illuminate the relevant LED cluster
      for i = 1, num_leds do
        device:led(2, i + led_starting_point, 10)
      end
    end

    local function update_number_ring(current_pos, min, max)
      -- Translate position to LED index
      local led_starting_point = math.floor((current_pos * 64) / (max - min))

      -- Calculate the number of LEDs to illuminate
      local num_leds = math.ceil(64 / (max - min))

      -- Illuminate the relevant LED cluster
      for i = 0, num_leds do
        device:led(2, i + led_starting_point, 10)
      end
    end

    local function update_stepped_number_ring(current_pos, min, max, step)
      -- Calculate total number of steps
      local num_steps = math.floor((max - min) / step)
      
      -- Calculate current step position (0-based)
      local current_step = math.floor((current_pos - min) / step)
      
      -- Translate step position to LED index (64 LEDs total)
      local led_starting_point = math.floor((current_step * 64) / num_steps)
      
      -- Calculate the number of LEDs per step
      local leds_per_step = math.ceil(64 / num_steps)
      
      -- Set base illumination
      for i = 1, 64 do
        device:led(2, i, 3)
      end
      
      -- Illuminate the relevant LED cluster
      for i = 0, leds_per_step - 1 do
        local led_pos = 1 + ((led_starting_point + i) % 64)
        device:led(2, led_pos, 10)
      end
    end

    local function update_binary_ring(value)
      for i = 1, 64 do
        device:led(2, i, 3)
      end

      if value == 1 then
        for i = 32, 64 do
          device:led(2, i, 10)
        end
      elseif value == 0 then
        for i = 1, 32 do
          device:led(2, i, 10)
        end
      end
    end

    device.update_param_value_display = function()
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end
      
      -- Get current param info
      local current_section_id = _seeker.ui_state.get_current_section()
      local current_section = _seeker.screen_ui.sections[current_section_id]
      local param = current_section.params[current_section.state.selected_index]

      -- Set base illumination
      for i = 1, 64 do
        device:led(2, i, 3)
      end
      
      if param then
        -- Handle custom param types
        if param.spec then

          -- Handle custom option types
          if param.spec.type == "option" then
            -- Find current index in options
            local current_idx = 1
            local current_value = current_section.state.values[param.id]

            for i, value in ipairs(param.spec.values) do
              if value == current_value then
                current_idx = i
                break
              end
            end
            
            update_option_ring(current_idx, #param.spec.values)

          -- Handle custom number types
          elseif param.spec.type == "integer" or param.spec.type == "number" then
            local value_pos = current_section.state.values[param.id]
            
            update_number_ring(value_pos, param.spec.min, param.spec.max)

          -- Handle custom action types
          elseif param.spec.type == "action" then
            device:led(2, 1, 10)
            device:led(2, 17, 10)
            device:led(2, 33, 10)
            device:led(2, 50, 10)
          end

        -- Handle norns param types
        elseif param.id then
          local param_info = params:lookup_param(param.id)
            local param_type = param_info.t  -- Norns param type
            
            -- Handle numb types
            if param_type == params.tNUMBER or param_type == params.tTAPER then

              local value = params:get(param.id)
              local min = param_info.min
              local max = param_info.max
              
              update_number_ring(value, min, max)

            -- Handle control types
            elseif param_type == params.tCONTROL then

              local value = params:get(param.id)
              local min = param_info.controlspec.minval
              local max = param_info.controlspec.maxval
              local step = param_info.controlspec.step

              update_stepped_number_ring(value, min, max, step)

            -- Handle option types  
            elseif param_type == params.tOPTION then

              update_option_ring(params:get(param.id), #param_info.options)

            -- Handle binary types
            elseif param_type == params.tBINARY then

              update_binary_ring(params:get(param.id))
            else
              print("Unhandled Param Type")
              print("type: other (" .. param_type .. ")")
              print("value: " .. params:get(param.id))
            end
        end
      end
      
      device:refresh()
    end

  else
    print("No Arc device found")
  end
  
  return device
end

return Arc 
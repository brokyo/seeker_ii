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
      
      -- Check for knob recording mode and intercept encoder turns
      if _seeker.ui_state.state.knob_recording_active and n == 2 then
        _seeker.eurorack_output.handle_encoder_input(delta)
        return 
      end
      
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
        
        -- Get current section and selected parameter
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local selected_param = current_section.params[current_section.state.selected_index]
        
        -- Map Arc encoder 1 to Norns encoder 2. Use custom param key illumination logic.
        if n == 1 then
          _seeker.ui_state.enc(2, direction)
          device.update_param_key_display()

          -- Update the param ring to keep in sync
          device.update_param_value_display()

        -- Map Arc encoder 2 to Norns encoder 3. Use custom param value illumination logic.
        -- Only send encoder events for non-action params. Action params handled by key press.
        elseif n == 2 and not selected_param.is_action then
          _seeker.ui_state.enc(3, direction)
          device.update_param_value_display()
        end        
      end
    end

    -- Add a trigger animation function
    device.animate_trigger = function(param_id)
      -- Skip if section should be skipped
      if device.skip_current_section then return end
      
      -- Start a multi-step animation
      clock.run(function()
        -- Animation step 1: Bright flash on ring 2
        for i = 1, 64 do
          device:led(2, i, 15) -- Brightest level
        end
        device:refresh()
        clock.sleep(0.05)
        
        -- Animation step 2: Medium brightness
        for i = 1, 64 do
          device:led(2, i, 10)
        end
        device:refresh()
        clock.sleep(0.1)
        
        -- Animation step 3: Lower brightness
        for i = 1, 64 do
          device:led(2, i, 6)
        end
        device:refresh()
        clock.sleep(0.15)
        
        -- Animation step 4: Fade out
        for i = 1, 64 do
          device:led(2, i, 3)
        end
        device:refresh()
        clock.sleep(0.2)
        
        -- Final step: Clear the ring
        for i = 1, 64 do
          device:led(2, i, 0)
        end
        device:refresh()
      end)
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
        if selected_param and selected_param.is_action then
          current_section:modify_param(selected_param, 1)
          
          -- Use the animate_trigger function instead of a simple flash
          if selected_param.id then
            device.animate_trigger(selected_param.id)
          else
            -- Fallback to simple flash for params without IDs
            for i = 1, 64 do
              device:led(2, i, 10)
            end
            device:refresh()
          end
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
      -- Ensure all values are numbers
      current_pos = tonumber(current_pos)
      min = tonumber(min)
      max = tonumber(max)

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
      -- Ensure all values are numbers
      current_pos = tonumber(current_pos)
      min = tonumber(min)
      max = tonumber(max)
      step = tonumber(step)

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

    -- Add pulse animation for action parameters
    device.pulse_action_param = nil -- Store the current pulsing parameter ID
    device.pulse_brightness = 0 -- Current brightness level for pulsing
    device.pulse_direction = 1 -- 1 = getting brighter, -1 = getting dimmer
    
    -- Start a pulse animation for action parameters
    device.start_action_pulse = function(param_id)
      -- Cancel existing pulse if any
      if device.pulse_action_param then
        device.stop_action_pulse()
      end
      
      -- Store the parameter we're pulsing for
      device.pulse_action_param = param_id
      
      -- Start the pulse animation
      device.action_pulse_clock = clock.run(function()
        while device.pulse_action_param do
          -- Adjust brightness based on direction
          device.pulse_brightness = device.pulse_brightness + (device.pulse_direction * 0.5)
          
          -- Reverse direction at limits
          if device.pulse_brightness >= 8 then
            device.pulse_brightness = 8
            device.pulse_direction = -1
          elseif device.pulse_brightness <= 3 then
            device.pulse_brightness = 3
            device.pulse_direction = 1
          end
          
          -- Update the LEDs with current brightness
          for i = 1, 64 do
            device:led(2, i, 0) -- Clear
          end
          
          -- Draw pulsing dots at cardinal positions
          local brightness = math.floor(device.pulse_brightness)
          device:led(2, 1, brightness)
          device:led(2, 17, brightness)
          device:led(2, 33, brightness)
          device:led(2, 49, brightness)
          
          device:refresh()
          clock.sleep(0.1) -- Update 10 times per second
        end
      end)
    end
    
    -- Stop the pulse animation
    device.stop_action_pulse = function()
      if device.action_pulse_clock then
        clock.cancel(device.action_pulse_clock)
        device.action_pulse_clock = nil
      end
      device.pulse_action_param = nil
      
      -- Clear the LEDs
      for i = 1, 64 do
        device:led(2, i, 0)
      end
      device:refresh()
    end
    
    device.update_param_value_display = function()
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end
      
      -- Get current param info
      local current_section_id = _seeker.ui_state.get_current_section()
      local current_section = _seeker.screen_ui.sections[current_section_id]
      local param = current_section.params[current_section.state.selected_index]
      
      -- For action parameters, start or update the pulse animation
      if param and param.is_action then
        if not device.pulse_action_param or device.pulse_action_param ~= param.id then
          device.start_action_pulse(param.id)
        end
        return -- Don't continue with normal display
      else
        -- For non-action params, stop any active pulse
        if device.pulse_action_param then
          device.stop_action_pulse()
        end
      end

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
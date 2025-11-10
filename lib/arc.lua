-- arc.lua

local Arc = {}

function Arc.init()
  local device = arc.connect()
  
  if device then 
    print("☯ Arc Connected")
    
    -- Add remove handler for proper disconnection management
    device.remove = function()
      print("◈ Arc Disconnected")
    end
    
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

    -- Helper function to get step sizes for a parameter
    local function get_param_step_sizes(param)
        if param.step_sizes then
            return param.step_sizes
        end
        -- Default step sizes if not specified
        return {
            integer = 1.0,
            tenth = 0.1,
            hundredth = 0.01
        }
    end

    -- Helper function to modify parameter value based on encoder step sizes
    device.modify_float_component = function(param, component_idx, direction)
        if not param.arc_multi_float then
            error("arc_multi_float must be defined with step sizes per encoder")
        end
        
        local current_value = params:get(param.id)
        local param_obj = params:lookup_param(param.id)
        -- Array indices 1,2,3 correspond to encoders 2,3,4
        local delta = direction * param.arc_multi_float[component_idx - 1]
        local new_value = current_value + delta
        
        -- Handle parameter range limits
        if param_obj.controlspec then
            new_value = math.max(param_obj.controlspec.minval, math.min(param_obj.controlspec.maxval, new_value))
        elseif param_obj.min and param_obj.max then
            new_value = math.max(param_obj.min, math.min(param_obj.max, new_value))
        end
        
        params:set(param.id, new_value)
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

        -- Check if dual keyboard is active and handle velocity encoders
        local dual_keyboard_active = _seeker.keyboards and _seeker.keyboards.dual_tape and _seeker.keyboards.dual_tape.is_active
        if dual_keyboard_active and (n == 3 or n == 4) then
          -- Encoder 3: Left keyboard velocity
          -- Encoder 4: Right keyboard velocity
          local velocity_delta = direction * 3

          if n == 3 then
            _seeker.keyboards.dual_tape.left_velocity = util.clamp(_seeker.keyboards.dual_tape.left_velocity + velocity_delta, 0, 127)
          elseif n == 4 then
            _seeker.keyboards.dual_tape.right_velocity = util.clamp(_seeker.keyboards.dual_tape.right_velocity + velocity_delta, 0, 127)
          end

          device.update_dual_keyboard_velocity_display()
          return
        end

        -- Check if single tape keyboard should handle velocity on encoder 4
        local focused_lane = _seeker.ui_state.get_focused_lane()
        local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")
        if motif_type == 1 and n == 4 and _seeker.keyboards and _seeker.keyboards[1] then
          -- Encoder 4: Single keyboard velocity
          local velocity_delta = direction * 3
          _seeker.keyboards[1].velocity = util.clamp(_seeker.keyboards[1].velocity + velocity_delta, 0, 127)

          device.update_single_keyboard_velocity_display()
          return
        end

        -- Get current section and selected parameter
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local selected_param = current_section.params[current_section.state.selected_index]

        -- Check if this parameter uses multi-encoder float editing
        local is_multi_float = selected_param and selected_param.arc_multi_float

        -- Map Arc encoder 1 to Norns encoder 2. Use custom param key illumination logic.
        if n == 1 then
          _seeker.ui_state.enc(2, direction)
          device.update_param_key_display()

          -- Update the param ring to keep in sync
          device.update_param_value_display()

        -- Handle multi-encoder float editing
        elseif is_multi_float and selected_param.id then
          if n == 2 then
            -- Encoder 2: Integer component
            device.modify_float_component(selected_param, 2, direction)
          elseif n == 3 then
            -- Encoder 3: Tenth component
            device.modify_float_component(selected_param, 3, direction)
          elseif n == 4 then
            -- Encoder 4: Hundredth component
            device.modify_float_component(selected_param, 4, direction)
          end

          -- Update display and UI once for any multi-encoder change
          device.update_param_value_display()
          _seeker.screen_ui.set_needs_redraw()

        -- Standard single encoder behavior for non-multi-float params
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

    -- Helper function to display a value's position within a range on the LED ring
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
    
    -- Helper function for displaying multi-encoder float values
    local function update_multi_float_rings(param_id)
        local current_value = params:get(param_id)
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local param = current_section.params[current_section.state.selected_index]
        local step_sizes = get_param_step_sizes(param)
        
        -- Clear all rings first
        for ring = 2, 4 do
            for i = 1, 64 do
                device:led(ring, i, 1) -- Dim base illumination
            end
        end
        
        -- Calculate display values based on step sizes
        local value = math.abs(current_value)
        local thousands = math.floor(value / 1000)
        local hundreds = math.floor((value % 1000) / 100)
        local tens = math.floor((value % 100) / 10)
        
        -- Ring 2: Thousands (0-20 for frequency)
        local thousand_leds = math.floor(64 / 20)
        local thousand_start = (thousands % 20) * thousand_leds + 1
        for i = 0, thousand_leds - 1 do
            device:led(2, thousand_start + i, 10)
        end
        
        -- Ring 3: Hundreds (0-9)
        local hundred_leds = math.floor(64 / 10)
        local hundred_start = hundreds * hundred_leds + 1
        for i = 0, hundred_leds - 1 do
            device:led(3, hundred_start + i, 10)
        end
        
        -- Ring 4: Tens (0-9)
        local ten_leds = math.floor(64 / 10)
        local ten_start = tens * ten_leds + 1
        for i = 0, ten_leds - 1 do
            device:led(4, ten_start + i, 10)
        end
        
        -- Add sign indicator on ring 2 if negative
        if current_value < 0 then
            device:led(2, 32, 15) -- Bright LED at bottom to indicate negative
        end
    end

    device.update_param_value_display = function()
      -- HOTFIX: Skip Arc handling for special sections
      if device.skip_current_section then return end

      -- Check if dual keyboard is active - if so, use dual keyboard velocity display
      local dual_keyboard_active = _seeker.keyboards and _seeker.keyboards.dual_tape and _seeker.keyboards.dual_tape.is_active
      if dual_keyboard_active then
        device.update_dual_keyboard_velocity_display()
        return
      end

      -- Check if single tape keyboard should show velocity display
      local focused_lane = _seeker.ui_state.get_focused_lane()
      local motif_type = params:get("lane_" .. focused_lane .. "_motif_type")
      if motif_type == 1 and _seeker.keyboards and _seeker.keyboards[1] then
        device.update_single_keyboard_velocity_display()
        return
      end

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

      -- Check if this parameter uses multi-encoder float editing
      if param and param.arc_multi_float and param.id then
        update_multi_float_rings(param.id)
        device:refresh()
        return
      end

      -- Set base illumination for standard single-ring display
      for i = 1, 64 do
        device:led(2, i, 3)
      end

      -- Clear rings 3 and 4 for non-multi-float params
      for ring = 3, 4 do
        for i = 1, 64 do
          device:led(ring, i, 0)
        end
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

    -- Update Arc display for dual keyboard velocity control
    device.update_dual_keyboard_velocity_display = function()
      if not _seeker.keyboards or not _seeker.keyboards.dual_tape or not _seeker.keyboards.dual_tape.is_active then
        return
      end

      -- Clear rings 3 and 4
      for ring = 3, 4 do
        for i = 1, 64 do
          device:led(ring, i, 1) -- Dim base
        end
      end

      -- Ring 3: Left keyboard velocity (0-127)
      local left_vel = _seeker.keyboards.dual_tape.left_velocity
      local left_leds = math.floor((left_vel / 127) * 64)
      for i = 1, left_leds do
        device:led(3, i, 10)
      end

      -- Ring 4: Right keyboard velocity (0-127)
      local right_vel = _seeker.keyboards.dual_tape.right_velocity
      local right_leds = math.floor((right_vel / 127) * 64)
      for i = 1, right_leds do
        device:led(4, i, 10)
      end

      device:refresh()
    end

    -- Update Arc display for single keyboard velocity control
    device.update_single_keyboard_velocity_display = function()
      if not _seeker.keyboards or not _seeker.keyboards[1] then
        return
      end

      -- Clear ring 3
      for i = 1, 64 do
        device:led(3, i, 0)
      end

      -- Clear ring 4
      for i = 1, 64 do
        device:led(4, i, 1) -- Dim base
      end

      -- Ring 4: Single keyboard velocity (0-127)
      local vel = _seeker.keyboards[1].velocity
      local leds = math.floor((vel / 127) * 64)
      for i = 1, leds do
        device:led(4, i, 10)
      end

      device:refresh()
    end

  else
    print("No Arc device found")
  end
  
  return device
end

return Arc 
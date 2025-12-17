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
    device.movement_count = {0, 0, 0, 0}  -- Track movements since last trigger for consistent sensitivity
    device.current_section_param_count = 0

    -- Custom display function - components provide their own arc rendering when active
    device.display_override = nil

    -- Triggers on section navigation (comes from 'section:enter()' in section.lua)
    device.new_section = function(params)
      -- Use custom display if a component has registered one
      if device.display_override then
        device.display_override()
        return
      end

      -- Update the number of params
      device.current_section_param_count = #params

      -- Skip LED display for sections with no params
      if device.current_section_param_count == 0 then
        for n = 1, 4 do
          for i = 1, 64 do
            device:led(n, i, 0)
          end
        end
        device:refresh()
        return
      end

      -- Draw dimmed LED ring as base layer
      for i = 1, 64 do
        device:led(1, i, 3)
      end

      -- Calculate the number of LEDs to illuminate based on the number of params
      local num_leds = math.floor(64 / device.current_section_param_count)

      -- Illuminate first parameter cluster
      for i = 1, num_leds do
        device:led(1, i, 10)
      end

       device:refresh()
    end

    device.update_display = function(n)
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

    -- Apply delta change to a multi-encoder float parameter
    device.modify_float_component = function(param, encoder_num, direction)
        if not param.arc_multi_float then
            error("arc_multi_float must be defined as array of delta values")
        end

        -- Convert encoder number (2,3,4) to array index (1,2,3)
        local array_idx = encoder_num - 1
        if not param.arc_multi_float[array_idx] then
            return -- This encoder is not active for this parameter
        end

        local current_value = params:get(param.id)
        local param_obj = params:lookup_param(param.id)
        local delta = direction * param.arc_multi_float[array_idx]
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
      -- Block Arc input during fileselect and show hint overlay
      if _seeker.sampler and _seeker.sampler.file_select_active then
        if _seeker.modal then
          _seeker.modal.draw_status_immediate({ body = "FILE SELECT", hint = "use norns e2/e3/k3" })
          screen.update()
        end
        return
      end

      -- Modal handles Arc encoder input first when active
      if _seeker.modal and _seeker.modal.handle_enc(n, delta, "arc") then
        return
      end

      -- Register activity to wake screen/restart sleep timer
      _seeker.ui_state.register_activity()

      -- offset counter on rotation (modulo 64 to stay aligned with the LED ring)
      device.index[n] = device.index[n] + delta % 64

      -- Determine movement direction based on last delta direction
      local direction
      if delta > 0 then
        direction = 1
      else
        direction = -1
      end

      -- Handle encoder 1 (list scrolling) with consistent movement counter
      if n == 1 then
        device.movement_count[1] = device.movement_count[1] + 1

        if device.movement_count[1] >= 12 then
          device.movement_count[1] = 0  -- Reset for next trigger cycle

          _seeker.ui_state.enc(2, direction)
          device.update_param_key_display()
          device.update_param_value_display()
        end
        return
      end

      -- Handle encoders 2, 3, 4 with existing modulo approach
      if device.index[n] % 8 == 0 then
        -- Get current section and selected parameter
        local current_section_id = _seeker.ui_state.get_current_section()

        -- Check if dual keyboard is active and handle velocity encoders
        -- Dual keyboard takes over encoders 3/4 for velocity regardless of section
        local dual_state = _seeker.dual_keyboard_state
        local dual_keyboard_active = dual_state and dual_state.is_active
        if dual_keyboard_active and (n == 3 or n == 4) then
          -- Encoder 3: Left keyboard velocity
          -- Encoder 4: Right keyboard velocity
          local velocity_delta = direction * 3

          if n == 3 then
            dual_state.left_velocity = util.clamp(dual_state.left_velocity + velocity_delta, 0, 127)
          elseif n == 4 then
            dual_state.right_velocity = util.clamp(dual_state.right_velocity + velocity_delta, 0, 127)
          end

          device.update_dual_keyboard_velocity_display()
          return
        end

        local current_section = _seeker.screen_ui.sections[current_section_id]
        local selected_param = current_section.active_params[current_section.state.selected_index]

        -- Action-only components (e.g., wtape) have no params
        if not selected_param then return end

        -- Check if this parameter uses multi-encoder float editing
        local is_multi_float = selected_param and selected_param.arc_multi_float

        -- Handle multi-encoder float editing
        if is_multi_float and selected_param.id then
          local num_encoders = #selected_param.arc_multi_float
          if n == 2 then
            -- Encoder 2: Coarse adjustment
            device.modify_float_component(selected_param, 2, direction)
          elseif n == 3 and num_encoders >= 2 then
            -- Encoder 3: Medium adjustment
            device.modify_float_component(selected_param, 3, direction)
          elseif n == 4 and num_encoders >= 3 then
            -- Encoder 4: Fine adjustment
            device.modify_float_component(selected_param, 4, direction)
          end

          -- Update display and UI once for any multi-encoder change
          device.update_param_value_display()
          _seeker.screen_ui.set_needs_redraw()

        -- Standard single encoder behavior for non-multi-float params
        elseif n == 2 and not selected_param.is_action then
          -- Check if this is a binary toggle param - direction sets value (clockwise=on, counter=off)
          if selected_param.id then
            local param_base = params:lookup_param(selected_param.id)
            if param_base and param_base.behavior == "toggle" then
              if direction > 0 then
                params:set(selected_param.id, 1)
              else
                params:set(selected_param.id, 0)
              end
              device.update_param_value_display()
              _seeker.screen_ui.set_needs_redraw()
              return
            end
          end

          -- Non-binary params go through normal enc path
          _seeker.ui_state.enc(3, direction)
          device.update_param_value_display()
        end
      end
    end

    -- Add a trigger animation function
    device.animate_trigger = function(param_id)
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
        
        -- Restore normal param value display after animation
        device.update_param_value_display()
      end)
    end

    device.key = function(n, d)
      if d == 1 then
        -- Block Arc input during fileselect and show hint overlay
        if _seeker.sampler and _seeker.sampler.file_select_active then
          if _seeker.modal then
            _seeker.modal.draw_status_immediate({ body = "FILE SELECT", hint = "use norns e2/e3/k3" })
            screen.update()
          end
          return
        end

        -- Modal handles Arc button press first (as K3)
        if _seeker.modal and _seeker.modal.handle_key(3, 1) then
          _seeker.screen_ui.set_needs_redraw()
          return
        end

        -- Get current section and selected parameter
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local selected_param = current_section:get_selected_param()

        -- If selected parameter is an action, execute it
        if selected_param and selected_param.is_action then
          params:set(selected_param.id, 1)
          device.animate_trigger(selected_param.id)

        -- If selected parameter is a binary toggle, toggle it
        elseif selected_param and selected_param.id then
          local param_base = params:lookup_param(selected_param.id)
          if param_base and param_base.behavior == "toggle" then
            local current = params:get(selected_param.id)
            params:set(selected_param.id, current == 0 and 1 or 0)
            device.update_param_value_display()
            _seeker.screen_ui.set_needs_redraw()
          end
        end
      end
    end


    -- Update the param key display
    device.update_param_key_display = function()
      -- Action-only components have no params to display
      if device.current_section_param_count == 0 then return end

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
          -- Skip drawing if modal is active (modal owns the display)
          if _seeker.modal and _seeker.modal.is_active() then
            clock.sleep(0.1)
          else
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
        end
      end)
    end
    
    -- Stop the pulse animation and clear ring 2
    device.stop_action_pulse = function()
      if device.action_pulse_clock then
        clock.cancel(device.action_pulse_clock)
        device.action_pulse_clock = nil
      end
      device.pulse_action_param = nil
      -- Clear ring 2 to prevent stale animation state
      for i = 1, 64 do
        device:led(2, i, 0)
      end
    end
    
    -- Display numeric value across 2-3 rings showing place values
    local function update_multi_float_rings(param_id)
        local current_value = params:get(param_id)
        local current_section_id = _seeker.ui_state.get_current_section()
        local current_section = _seeker.screen_ui.sections[current_section_id]
        local param = current_section.active_params[current_section.state.selected_index]
        local num_encoders = #param.arc_multi_float

        -- Light active rings (ring 1 + number of encoders, capped at ring 4)
        local max_ring = math.min(4, 1 + num_encoders)
        for ring = 2, max_ring do
            for i = 1, 64 do
                device:led(ring, i, 1) -- Dim base illumination
            end
        end

        -- Clear any unused rings
        for ring = max_ring + 1, 4 do
            for i = 1, 64 do
                device:led(ring, i, 0)
            end
        end
        
        -- Display value at each encoder's delta scale
        local value = math.abs(current_value)
        local remainder = value

        -- Ring 2: Show value at first encoder's delta scale
        if num_encoders >= 1 then
            local delta = param.arc_multi_float[1]
            local digit = math.floor(remainder / delta) % 10
            local leds_per_digit = math.floor(64 / 10)
            local led_start = digit * leds_per_digit + 1
            for i = 0, leds_per_digit - 1 do
                device:led(2, led_start + i, 10)
            end
            remainder = remainder % delta
        end

        -- Ring 3: Show value at second encoder's delta scale
        if num_encoders >= 2 then
            local delta = param.arc_multi_float[2]
            local digit = math.floor(remainder / delta) % 10
            local leds_per_digit = math.floor(64 / 10)
            local led_start = digit * leds_per_digit + 1
            for i = 0, leds_per_digit - 1 do
                device:led(3, led_start + i, 10)
            end
            remainder = remainder % delta
        end

        -- Ring 4: Show value at third encoder's delta scale
        if num_encoders >= 3 then
            local delta = param.arc_multi_float[3]
            local digit = math.floor(remainder / delta) % 10
            local leds_per_digit = math.floor(64 / 10)
            local led_start = digit * leds_per_digit + 1
            for i = 0, leds_per_digit - 1 do
                device:led(4, led_start + i, 10)
            end
        end
        
        -- Add sign indicator on ring 2 if negative
        if current_value < 0 then
            device:led(2, 32, 15) -- Bright LED at bottom to indicate negative
        end
    end

    device.update_param_value_display = function()
      -- Get current section first
      local current_section_id = _seeker.ui_state.get_current_section()

      -- Check if dual keyboard is active - if so, use dual keyboard velocity display
      local dual_state = _seeker.dual_keyboard_state
      local dual_keyboard_active = dual_state and dual_state.is_active
      if dual_keyboard_active then
        device.update_dual_keyboard_velocity_display()
        return
      end

      -- When modal is active, handle display specially
      if _seeker.modal and _seeker.modal.is_active() then
        local modal_type = _seeker.modal.get_type()

        -- Stop any pulse animation when modal is active
        if device.pulse_action_param then
          device.stop_action_pulse()
        end

        -- ADSR modal: show A/D/S/R values on rings 1-4
        if modal_type == _seeker.modal.TYPE.ADSR then
          device.update_adsr_display()
          return
        end

        -- Waveform modal: show start/stop selection on ring 1, value position on rings 2-4
        if modal_type == _seeker.modal.TYPE.WAVEFORM then
          device.update_waveform_display()
          return
        end

        -- Other modals: clear rings 3 and 4
        for ring = 3, 4 do
          for i = 1, 64 do
            device:led(ring, i, 0)
          end
        end
        device:refresh()
        return
      end

      -- Get current param info
      local current_section = _seeker.screen_ui.sections[current_section_id]
      local param = current_section.active_params[current_section.state.selected_index]

      -- Sections with no params: clear rings 2-4
      if not param then
        for ring = 2, 4 do
          for i = 1, 64 do
            device:led(ring, i, 0)
          end
        end
        device:refresh()
        return
      end

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
            elseif param_info.behavior == "toggle" or param_info.behavior == "trigger" then

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
      -- Use display override if registered (component-driven)
      if device.display_override then
        device.display_override()
      end
    end

    -- Clear rings 3 and 4 (used when modal takes over input)
    device.clear_outer_rings = function()
      for ring = 3, 4 do
        for i = 1, 64 do
          device:led(ring, i, 0)
        end
      end
      device:refresh()
    end

    -- Display ADSR modal: ring 1 shows selected stage, rings 2-4 show value position
    device.update_adsr_display = function()
      local Modal = _seeker.modal
      if not Modal then return end

      local selected = Modal.get_adsr_selected()
      local param_ids = Modal.get_adsr_param_ids()

      -- Fallback to lane params if modal didn't provide param IDs
      if not param_ids then
        local lane_idx = _seeker.ui_state.get_focused_lane()
        param_ids = {
          "lane_" .. lane_idx .. "_attack",
          "lane_" .. lane_idx .. "_decay",
          "lane_" .. lane_idx .. "_sustain",
          "lane_" .. lane_idx .. "_release"
        }
      end

      -- Ring 1: Selection indicator (A/D/S/R at cardinal positions)
      for i = 1, 64 do
        device:led(1, i, 0)
      end
      -- Show all 4 stages dimly, selected brightly
      local stage_positions = {1, 17, 33, 49}  -- Cardinal positions for A, D, S, R
      for stage = 1, 4 do
        local brightness = (stage == selected) and 15 or 4
        local pos = stage_positions[stage]
        device:led(1, pos, brightness)
        device:led(1, pos + 1, math.floor(brightness * 0.5))
        if pos > 1 then device:led(1, pos - 1, math.floor(brightness * 0.5)) end
      end

      -- Rings 2-4: Value position for selected stage
      local param_id = param_ids[selected]
      local value = params:get(param_id)

      -- Get param range
      local p = params:lookup_param(param_id)
      local min_val, max_val
      if p.controlspec then
        min_val = p.controlspec.minval
        max_val = p.controlspec.maxval
      elseif p.min and p.max then
        min_val = p.min
        max_val = p.max
      else
        min_val = 0
        max_val = 1
      end

      -- Normalize value to 0-1 range
      local normalized = (value - min_val) / (max_val - min_val)
      normalized = util.clamp(normalized, 0, 1)

      -- Calculate LED position for rings 2-4
      local led_pos = math.floor(normalized * 63) + 1

      for ring = 2, 4 do
        -- Dim base illumination
        for i = 1, 64 do
          device:led(ring, i, 2)
        end
        -- Highlight value position
        device:led(ring, led_pos, 15)
        if led_pos > 1 then device:led(ring, led_pos - 1, 10) end
        if led_pos < 64 then device:led(ring, led_pos + 1, 10) end
      end

      device:refresh()
    end

    -- Display waveform modal: ring 1 shows start/stop selection, rings 2-4 show value position
    device.update_waveform_display = function()
      local Modal = _seeker.modal
      if not Modal then return end

      local selected = Modal.get_waveform_selected()  -- 1 = start, 2 = stop
      local positions = Modal.get_waveform_positions()
      local start_pos = positions.start_pos or 0
      local stop_pos = positions.stop_pos or 1
      local duration = positions.duration or 1

      -- Ring 1: Selection indicator (Start/Stop at opposite positions)
      for i = 1, 64 do
        device:led(1, i, 0)
      end
      -- Show both positions dimly, selected brightly
      local stage_positions = {1, 33}  -- Left for start, right for stop
      for stage = 1, 2 do
        local brightness = (stage == selected) and 15 or 4
        local pos = stage_positions[stage]
        device:led(1, pos, brightness)
        device:led(1, pos + 1, math.floor(brightness * 0.5))
        if pos > 1 then device:led(1, pos - 1, math.floor(brightness * 0.5)) end
      end

      -- Normalize selected value position relative to total duration
      local value = (selected == 1) and start_pos or stop_pos
      local normalized = (duration > 0) and (value / duration) or 0
      normalized = util.clamp(normalized, 0, 1)

      -- Calculate LED position for rings 2-4
      local led_pos = math.floor(normalized * 63) + 1

      for ring = 2, 4 do
        -- Dim base illumination
        for i = 1, 64 do
          device:led(ring, i, 2)
        end
        -- Highlight value position
        device:led(ring, led_pos, 15)
        if led_pos > 1 then device:led(ring, led_pos - 1, 10) end
        if led_pos < 64 then device:led(ring, led_pos + 1, 10) end
      end

      device:refresh()
    end

  else
    print("No Arc device found")
  end

  return device
end

return Arc 
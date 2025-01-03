function init()
    -- Wrap parameter initialization in pcall for error handling
    local success, err = pcall(function()
        -- Initialize parameters
        params:add_separator("SEEKER II")
        
        -- Add parameters with prefix and error checking
        local param_ids = {}
        local function add_param(args)
            -- Add prefix to ID
            args.id = PARAM_PREFIX .. args.id
            -- Track parameter IDs
            if param_ids[args.id] then
                print("WARNING: Parameter ID collision detected: " .. args.id)
            end
            param_ids[args.id] = true
            -- Add parameter
            params:add(args)
        end

        -- Initialize other components
        // ... rest of init code ...
    end)

    if not success then
        print("ERROR during initialization: " .. tostring(err))
    end
end

-- Add error handler for parameter access
local function handle_param_error(err)
    print("Parameter error: " .. tostring(err))
    -- Log additional debug info
    print("Stack trace:")
    print(debug.traceback())
end 
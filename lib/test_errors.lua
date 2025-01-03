-- Test file for error handling
local params_manager = include('lib/params_manager')

function test_param_collisions()
    print("\nTesting parameter collisions...")
    -- Try to add a parameter with same ID twice
    params:add_number("test_param", "Test Param", 1, 10, 1)
    params:add_number("test_param", "Test Param 2", 1, 10, 1)
end

function test_nil_params()
    print("\nTesting nil parameter access...")
    -- Try to access non-existent parameter
    local value = params_manager.safe_get_param("nonexistent_param")
    print("Safe get returned: " .. tostring(value))
    
    -- Try to set non-existent parameter
    local success = params_manager.safe_set_param("nonexistent_param", 5)
    print("Safe set returned: " .. tostring(success))
end

function run_tests()
    print("Starting error handler tests...")
    test_param_collisions()
    test_nil_params()
    print("Tests complete.")
end

return { run_tests = run_tests } 
-- Test file for error handling
local params_manager = include('lib/params_manager')

function test_param_collisions()
    print("\nTesting parameter collisions...")
    -- Test that our prefix system prevents collisions
    local test_id = params_manager.PARAM_PREFIX .. "test_param"
    params:add_number(test_id, "Test Param", 1, 10, 1)
    
    -- Test collision prevention with different prefix
    local different_id = "different_prefix_test_param"
    params:add_number(different_id, "Different Prefix", 1, 10, 1)
    print("Successfully added parameters with different prefixes")
end

function test_nil_params()
    print("\nTesting nil parameter access...")
    -- Try to access non-existent parameter
    local value = params_manager.safe_get_param("nonexistent_param")
    if value == nil then
        print("Safe get handled nil parameter correctly")
    end
    
    -- Try to set non-existent parameter
    local success = params_manager.safe_set_param("nonexistent_param", 5)
    if not success then
        print("Safe set handled nil parameter correctly")
    end
end

function run_tests()
    print("Starting error handler tests...")
    test_param_collisions()
    test_nil_params()
    print("Tests complete.")
end

return { run_tests = run_tests } 
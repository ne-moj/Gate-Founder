--[[
    TableShow Unit Tests
    
    Run with: /unittests tableshow
    
    Tests cover:
    - Basic value serialization (string, number, boolean, nil)
    - Simple table serialization
    - Nested table serialization
    - Empty table handling
    - Circular reference handling
    - Key sorting
    - Mixed key types
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/commands/?.lua"

local TableShow = include("tableshow")

local TestTableShow = {}

-- Test results accumulator
local results = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- Helper: Assert equality
local function assertEqual(name, expected, actual)
    if expected == actual then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = tostring(expected),
            actual = tostring(actual)
        })
        return false
    end
end

-- Helper: Assert truthy
local function assertTrue(name, value)
    return assertEqual(name, true, value == true)
end

-- Helper: Assert not nil
local function assertNotNil(name, value)
    if value ~= nil then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {name = name, status = "FAIL", expected = "not nil", actual = "nil"})
        return false
    end
end

-- Helper: Assert type
local function assertType(name, expectedType, value)
    local actualType = type(value)
    if actualType == expectedType then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {name = name, status = "FAIL", expected = expectedType, actual = actualType})
        return false
    end
end

-- Helper: Assert contains substring
local function assertContains(name, substring, str)
    if str and str:find(substring, 1, true) then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {name = name, status = "FAIL", expected = "contains '" .. substring .. "'", actual = tostring(str)})
        return false
    end
end

-- Reset results between runs
function TestTableShow.reset()
    results = {passed = 0, failed = 0, tests = {}}
end

-- ============================================================================
-- TEST: Function Exists
-- ============================================================================

function TestTableShow.test_function_exists()
    assertNotNil("TableShow is defined", TableShow)
    assertType("TableShow is function", "function", TableShow)
end

-- ============================================================================
-- TEST: Non-Table Values
-- ============================================================================

function TestTableShow.test_number_value()
    local result = TableShow(42, "num")
    assertContains("number serialization", "42", result)
end

function TestTableShow.test_string_value()
    local result = TableShow("hello", "str")
    assertContains("string serialization", "hello", result)
end

function TestTableShow.test_boolean_true()
    local result = TableShow(true, "bool")
    assertContains("boolean true", "true", result)
end

function TestTableShow.test_boolean_false()
    local result = TableShow(false, "bool")
    assertContains("false", "false", result)
end

function TestTableShow.test_nil_value()
    local result = TableShow(nil, "val")
    assertContains("nil serialization", "nil", result)
end

-- ============================================================================
-- TEST: Simple Tables
-- ============================================================================

function TestTableShow.test_empty_table()
    local result = TableShow({}, "t")
    assertContains("empty table has {}", "{}", result)
end

function TestTableShow.test_simple_array()
    local result = TableShow({1, 2, 3}, "arr")
    assertContains("array contains 1", "1", result)
    assertContains("array contains 2", "2", result)
    assertContains("array contains 3", "3", result)
end

function TestTableShow.test_simple_hash()
    local result = TableShow({a = 1, b = 2}, "hash")
    assertContains("hash contains a", "a", result)
    assertContains("hash contains b", "b", result)
end

function TestTableShow.test_mixed_keys()
    local result = TableShow({[1] = "one", ["two"] = 2}, "mix")
    assertContains("mixed has numeric key", "[1]", result)
    assertContains("mixed has string key", "two", result)
end

-- ============================================================================
-- TEST: Nested Tables
-- ============================================================================

function TestTableShow.test_nested_table()
    local result = TableShow({outer = {inner = 123}}, "nested")
    assertContains("nested contains outer", "outer", result)
    assertContains("nested contains inner", "inner", result)
    assertContains("nested contains 123", "123", result)
end

function TestTableShow.test_deeply_nested()
    local t = {level1 = {level2 = {level3 = "deep"}}}
    local result = TableShow(t, "deep")
    assertContains("deep nesting works", "deep", result)
end

-- ============================================================================
-- TEST: Circular References
-- ============================================================================

function TestTableShow.test_self_reference()
    local t = {name = "test"}
    t.self = t
    local result = TableShow(t, "circular")
    -- Should not crash and should indicate self-reference
    assertNotNil("circular ref returns result", result)
    assertContains("indicates self reference", "self reference", result)
end

function TestTableShow.test_mutual_reference()
    local a = {name = "a"}
    local b = {name = "b"}
    a.ref = b
    b.ref = a
    local result = TableShow(a, "mutual")
    -- Should not crash
    assertNotNil("mutual ref returns result", result)
end

-- ============================================================================
-- TEST: Key Sorting
-- ============================================================================

function TestTableShow.test_keys_are_sorted()
    local result = TableShow({z = 1, a = 2, m = 3}, "sorted")
    -- Find positions of keys
    local pos_a = result:find('"a"') or result:find('%[a%]')
    local pos_m = result:find('"m"') or result:find('%[m%]')
    local pos_z = result:find('"z"') or result:find('%[z%]')
    
    -- a should come before m, m before z
    local sorted = pos_a and pos_m and pos_z and pos_a < pos_m and pos_m < pos_z
    assertTrue("keys are sorted alphabetically", sorted)
end

-- ============================================================================
-- TEST: Output Format
-- ============================================================================

function TestTableShow.test_output_is_string()
    local result = TableShow({a = 1}, "t")
    assertType("output is string", "string", result)
end

function TestTableShow.test_named_table()
    local result = TableShow({a = 1}, "myTable")
    assertContains("uses provided name", "myTable", result)
end

function TestTableShow.test_unnamed_table()
    local result = TableShow({a = 1})
    assertContains("uses default name", "__unnamed__", result)
end

-- ============================================================================
-- TEST: Special Values
-- ============================================================================

function TestTableShow.test_function_value()
    local result = TableShow({fn = function() end}, "t")
    assertContains("function is serialized", "function", result)
end

function TestTableShow.test_numeric_string_keys()
    local result = TableShow({["123"] = "value"}, "t")
    assertContains("numeric string key works", "123", result)
end

-- Run all tests
function TestTableShow.runAll()
    TestTableShow.reset()
    
    -- Function exists
    TestTableShow.test_function_exists()
    
    -- Non-table values
    TestTableShow.test_number_value()
    TestTableShow.test_string_value()
    TestTableShow.test_boolean_true()
    TestTableShow.test_boolean_false()
    TestTableShow.test_nil_value()
    
    -- Simple tables
    TestTableShow.test_empty_table()
    TestTableShow.test_simple_array()
    TestTableShow.test_simple_hash()
    TestTableShow.test_mixed_keys()
    
    -- Nested tables
    TestTableShow.test_nested_table()
    TestTableShow.test_deeply_nested()
    
    -- Circular references
    TestTableShow.test_self_reference()
    TestTableShow.test_mutual_reference()
    
    -- Key sorting
    TestTableShow.test_keys_are_sorted()
    
    -- Output format
    TestTableShow.test_output_is_string()
    TestTableShow.test_named_table()
    TestTableShow.test_unnamed_table()
    
    -- Special values
    TestTableShow.test_function_value()
    TestTableShow.test_numeric_string_keys()
    
    return results
end

-- Get formatted results
function TestTableShow.getResults()
    return results
end

return TestTableShow

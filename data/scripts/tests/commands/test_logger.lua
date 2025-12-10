--[[
    Logger Unit Tests
    
    Run with: /libtest logger
    
    Tests cover:
    - Instance creation
    - All log level methods
    - Bitmask operations
    - Table serialization
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/?.lua"

local Logger = include("logger")

local TestLogger = {}

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

-- Reset results between runs
function TestLogger.reset()
    results = {passed = 0, failed = 0, tests = {}}
end

--[[ TEST: Instance Creation ]]--
function TestLogger.test_new_creates_instance()
    local log = Logger:new("TestModule")
    assertNotNil("new() returns instance", log)
    assertType("instance is table", "table", log)
end

function TestLogger.test_new_sets_module_name()
    local log = Logger:new("MyModule")
    assertEqual("moduleName is set", "MyModule", log.moduleName)
end

function TestLogger.test_new_default_module_name()
    local log = Logger:new()
    assertEqual("default moduleName is Unknown", "Unknown", log.moduleName)
end

function TestLogger.test_new_sets_print_mask()
    local log = Logger:new("Test")
    assertTrue("printMask is set", log.printMask > 0)
end

function TestLogger.test_new_sets_save_mask()
    local log = Logger:new("Test")
    assertTrue("saveMask is set", log.saveMask > 0)
end

--[[ TEST: Enum Types ]]--
function TestLogger.test_enum_types_defined()
    assertNotNil("ERROR defined", Logger.enumTypes.ERROR)
    assertNotNil("WARNING defined", Logger.enumTypes.WARNING)
    assertNotNil("INFO defined", Logger.enumTypes.INFO)
    assertNotNil("DEBUG defined", Logger.enumTypes.DEBUG)
    assertNotNil("RUN_FUN defined", Logger.enumTypes.RUN_FUN)
end

function TestLogger.test_enum_types_are_powers_of_2()
    assertEqual("ERROR = 0x1", 0x1, Logger.enumTypes.ERROR)
    assertEqual("WARNING = 0x2", 0x2, Logger.enumTypes.WARNING)
    assertEqual("INFO = 0x4", 0x4, Logger.enumTypes.INFO)
    assertEqual("DEBUG = 0x8", 0x8, Logger.enumTypes.DEBUG)
    assertEqual("RUN_FUN = 0x10", 0x10, Logger.enumTypes.RUN_FUN)
end

--[[ TEST: Bitmask Operations ]]--
function TestLogger.test_prepareMask_single_type()
    local log = Logger:new("Test")
    local mask = log:_prepareMask({'ERROR'})
    assertEqual("single type mask", 0x1, mask)
end

function TestLogger.test_prepareMask_multiple_types()
    local log = Logger:new("Test")
    local mask = log:_prepareMask({'ERROR', 'WARNING'})
    assertEqual("combined mask", 0x3, mask)  -- 0x1 | 0x2 = 0x3
end

function TestLogger.test_prepareMask_all_types()
    local log = Logger:new("Test")
    local mask = log:_prepareMask({'ERROR', 'WARNING', 'INFO', 'DEBUG', 'RUN_FUN'})
    assertEqual("all types mask", 0x1F, mask)  -- 0x1 | 0x2 | 0x4 | 0x8 | 0x10 = 0x1F
end

function TestLogger.test_prepareMask_empty()
    local log = Logger:new("Test")
    local mask = log:_prepareMask({})
    assertEqual("empty mask", 0, mask)
end

function TestLogger.test_prepareMask_invalid_type()
    local log = Logger:new("Test")
    local mask = log:_prepareMask({'INVALID', 'ERROR'})
    assertEqual("ignores invalid, keeps ERROR", 0x1, mask)
end

--[[ TEST: Log Level Methods (existence check) ]]--
function TestLogger.test_methods_exist()
    local log = Logger:new("Test")
    assertType("Error is function", "function", log.Error)
    assertType("Warning is function", "function", log.Warning)
    assertType("Info is function", "function", log.Info)
    assertType("Debug is function", "function", log.Debug)
    assertType("RunFunc is function", "function", log.RunFunc)
    assertType("serialize is function", "function", log.serialize)
end

--[[ TEST: Serialize ]]--
function TestLogger.test_serialize_simple_table()
    local log = Logger:new("Test")
    local data = {a = 1, b = 2}
    local result = log:serialize(data, "test")
    assertNotNil("serialize returns string", result)
    assertType("serialize result is string", "string", result)
end

function TestLogger.test_serialize_nested_table()
    local log = Logger:new("Test")
    local data = {outer = {inner = 123}}
    local result = log:serialize(data, "nested")
    assertNotNil("serialize nested table", result)
end

-- Run all tests
function TestLogger.runAll()
    TestLogger.reset()
    
    -- Instance creation tests
    TestLogger.test_new_creates_instance()
    TestLogger.test_new_sets_module_name()
    TestLogger.test_new_default_module_name()
    TestLogger.test_new_sets_print_mask()
    TestLogger.test_new_sets_save_mask()
    
    -- Enum types tests
    TestLogger.test_enum_types_defined()
    TestLogger.test_enum_types_are_powers_of_2()
    
    -- Bitmask tests
    TestLogger.test_prepareMask_single_type()
    TestLogger.test_prepareMask_multiple_types()
    TestLogger.test_prepareMask_all_types()
    TestLogger.test_prepareMask_empty()
    TestLogger.test_prepareMask_invalid_type()
    
    -- Method existence tests
    TestLogger.test_methods_exist()
    
    -- Serialize tests
    TestLogger.test_serialize_simple_table()
    TestLogger.test_serialize_nested_table()
    
    return results
end

-- Get formatted results
function TestLogger.getResults()
    return results
end

return TestLogger

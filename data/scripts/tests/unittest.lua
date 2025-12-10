--[[
    Unit Test Helper Library
    
    Collection of assertion methods for unit tests.
    
    Usage:
        local UnitTest = include("unittest")
        local t = UnitTest:new()
        
        t:assertEqual("Name", 1, 1)
        return t:getResults()
    
    OR (Global Injection Mode - what existing tests seem to expect/emulate):
    
    The current existing tests (test_configs.lua, etc.) seem to use local helper functions.
    To support "include('unittest')" and global-like usage, we can export a table 
    that functions can be called on, OR we can inject globals if desired, 
    but explicit calls are cleaner: UnitTest.assertEqual(...)
--]]

local UnitTest = {}

-- Results accumulator
local results = {
    passed = 0,
    failed = 0,
    tests = {}
}

function UnitTest.reset()
    results = {
        passed = 0,
        failed = 0,
        tests = {}
    }
end

function UnitTest.getResults()
    return results
end

function UnitTest.assertEqual(name, expected, actual)
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

function UnitTest.assertNotEqual(name, notExpected, actual)
    if notExpected ~= actual then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = "Not " .. tostring(notExpected),
            actual = tostring(actual)
        })
        return false
    end
end

function UnitTest.assertTrue(name, condition)
    if condition then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = "true",
            actual = tostring(condition)
        })
        return false
    end
end

function UnitTest.assertFalse(name, condition)
    if not condition then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = "false",
            actual = tostring(condition)
        })
        return false
    end
end

function UnitTest.assertNil(name, value)
    if value == nil then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = "nil",
            actual = tostring(value)
        })
        return false
    end
end

function UnitTest.assertNotNil(name, value)
    if value ~= nil then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = "not nil",
            actual = "nil"
        })
        return false
    end
end

function UnitTest.assertType(name, expectedType, value)
    if type(value) == expectedType then
        results.passed = results.passed + 1
        table.insert(results.tests, {name = name, status = "PASS"})
        return true
    else
        results.failed = results.failed + 1
        table.insert(results.tests, {
            name = name, 
            status = "FAIL",
            expected = expectedType,
            actual = type(value)
        })
        return false
    end
end

-- Inject into global environment for convenience (optional but helpful for consistent tests)
-- Use with caution.
function UnitTest.injectGlobals()
    _G.assertEqual = UnitTest.assertEqual
    _G.assertNotEqual = UnitTest.assertNotEqual
    _G.assertTrue = UnitTest.assertTrue
    _G.assertFalse = UnitTest.assertFalse
    _G.assertNil = UnitTest.assertNil
    _G.assertNotNil = UnitTest.assertNotNil
    _G.assertType = UnitTest.assertType
end

return UnitTest

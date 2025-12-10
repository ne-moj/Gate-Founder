--[[
    Configs Unit Tests
    
    Run with: /unittests configs
    
    Tests cover:
    - Instance creation
    - Schema initialization and defaults
    - Get/Set methods with validation
    - Type validators (number, string, boolean, table)
    - Min/max validation
    - Enum validation
    - Direct field access (Config.FieldName)
    - Save/Load functionality
    - Reset to defaults
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/commands/?.lua"

local Configs = include("configs")

local TestConfigs = {}

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

-- Helper: Assert falsy
local function assertFalse(name, value)
    return assertEqual(name, false, value == true)
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
function TestConfigs.reset()
    results = {passed = 0, failed = 0, tests = {}}
end

-- ============================================================================
-- TEST: Instance Creation
-- ============================================================================

function TestConfigs.test_new_creates_instance()
    local config = Configs.new("TestModule")
    assertNotNil("new() returns instance", config)
    assertType("instance is table", "table", config)
end

function TestConfigs.test_callable_syntax()
    local config = Configs("TestModule")
    assertNotNil("Configs() callable syntax works", config)
end

function TestConfigs.test_sets_module_name()
    local config = Configs("MyModule")
    assertEqual("moduleName is set", "MyModule", config.moduleName)
end

function TestConfigs.test_default_module_name()
    local config = Configs()
    assertEqual("default moduleName is Unknown", "Unknown", config.moduleName)
end

function TestConfigs.test_colon_syntax_initialization()
    -- Explicitly test Configs:new syntax
    local config = Configs:new("ColonModule")
    assertNotNil("Colon syntax returns instance", config)
    assertEqual("Colon syntax sets moduleName correctly", "ColonModule", config.moduleName)
    -- Check that moduleName is NOT a table (which was the bug)
    assertType("moduleName is string", "string", config.moduleName)
end

function TestConfigs.test_dot_syntax_initialization()
    -- Explicitly test Configs.new syntax (backwards compatibility)
    -- Note: Since we changed definition to :new, calling with .new makes 'self' literal string
    -- and our fix handles that argument shifting.
    local config = Configs.new("DotModule")
    assertNotNil("Dot syntax returns instance", config)
    assertEqual("Dot syntax sets moduleName correctly", "DotModule", config.moduleName)
end

-- ============================================================================
-- TEST: Schema and Defaults
-- ============================================================================

function TestConfigs.test_schema_initializes_defaults()
    local schema = {
        TestValue = {default = 42, type = "number"}
    }
    local config = Configs("Test", {schema = schema})
    assertEqual("default value initialized", 42, config:get("TestValue"))
end

function TestConfigs.test_schema_initializes_comments()
    local schema = {
        TestValue = {default = 42, type = "number", comment = "Test comment"}
    }
    local config = Configs("Test", {schema = schema})
    local meta = config:get("TestValue", true)
    assertEqual("comment initialized", "Test comment", meta.comment)
end

function TestConfigs.test_multiple_defaults()
    local schema = {
        NumVal = {default = 100, type = "number"},
        StrVal = {default = "hello", type = "string"},
        BoolVal = {default = true, type = "boolean"}
    }
    local config = Configs("Test", {schema = schema})
    assertEqual("number default", 100, config:get("NumVal"))
    assertEqual("string default", "hello", config:get("StrVal"))
    assertEqual("boolean default", true, config:get("BoolVal"))
end

-- ============================================================================
-- TEST: Get/Set Methods
-- ============================================================================

function TestConfigs.test_get_returns_value()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    assertEqual("get() returns value", 42, config:get("TestValue"))
end

function TestConfigs.test_get_with_meta()
    local schema = {TestValue = {default = 42, type = "number", comment = "My comment"}}
    local config = Configs("Test", {schema = schema})
    local meta = config:get("TestValue", true)
    assertType("get(,true) returns table", "table", meta)
    assertEqual("meta.value", 42, meta.value)
    assertEqual("meta.comment", "My comment", meta.comment)
end

function TestConfigs.test_set_updates_value()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    config:set("TestValue", 100)
    assertEqual("set() updates value", 100, config:get("TestValue"))
end

function TestConfigs.test_set_returns_success()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", 100)
    assertTrue("set() returns true on success", ok)
end

function TestConfigs.test_getAll_returns_all_values()
    local schema = {
        Val1 = {default = 1, type = "number"},
        Val2 = {default = 2, type = "number"}
    }
    local config = Configs("Test", {schema = schema})
    local all = config:getAll()
    assertEqual("getAll() has Val1", 1, all.Val1)
    assertEqual("getAll() has Val2", 2, all.Val2)
end

function TestConfigs.test_setAll_sets_multiple()
    local schema = {
        Val1 = {default = 1, type = "number"},
        Val2 = {default = 2, type = "number"}
    }
    local config = Configs("Test", {schema = schema})
    config:setAll({Val1 = 10, Val2 = 20})
    assertEqual("setAll updated Val1", 10, config:get("Val1"))
    assertEqual("setAll updated Val2", 20, config:get("Val2"))
end

-- ============================================================================
-- TEST: Validation - Number
-- ============================================================================

function TestConfigs.test_number_validation_accepts_number()
    local schema = {TestValue = {type = "number"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", 42)
    assertTrue("number accepts number", ok)
end

function TestConfigs.test_number_validation_rejects_string()
    local schema = {TestValue = {type = "number"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", "not a number")
    assertFalse("number rejects string", ok)
end

function TestConfigs.test_number_min_validation()
    local schema = {TestValue = {type = "number", min = 10}}
    local config = Configs("Test", {schema = schema})
    local ok1, _ = config:set("TestValue", 5)
    assertFalse("number min rejects below", ok1)
    local ok2, _ = config:set("TestValue", 15)
    assertTrue("number min accepts above", ok2)
end

function TestConfigs.test_number_max_validation()
    local schema = {TestValue = {type = "number", max = 100}}
    local config = Configs("Test", {schema = schema})
    local ok1, _ = config:set("TestValue", 150)
    assertFalse("number max rejects above", ok1)
    local ok2, _ = config:set("TestValue", 50)
    assertTrue("number max accepts below", ok2)
end

function TestConfigs.test_number_min_max_range()
    local schema = {TestValue = {type = "number", min = 10, max = 100}}
    local config = Configs("Test", {schema = schema})
    local ok1, _ = config:set("TestValue", 5)
    assertFalse("range rejects below min", ok1)
    local ok2, _ = config:set("TestValue", 150)
    assertFalse("range rejects above max", ok2)
    local ok3, _ = config:set("TestValue", 50)
    assertTrue("range accepts in range", ok3)
end

-- ============================================================================
-- TEST: Validation - String
-- ============================================================================

function TestConfigs.test_string_validation_accepts_string()
    local schema = {TestValue = {type = "string"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", "hello")
    assertTrue("string accepts string", ok)
end

function TestConfigs.test_string_validation_rejects_number()
    local schema = {TestValue = {type = "string"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", 42)
    assertFalse("string rejects number", ok)
end

function TestConfigs.test_string_enum_validation()
    local schema = {TestValue = {type = "string", enum = {"a", "b", "c"}}}
    local config = Configs("Test", {schema = schema})
    local ok1, _ = config:set("TestValue", "a")
    assertTrue("enum accepts valid value", ok1)
    local ok2, _ = config:set("TestValue", "d")
    assertFalse("enum rejects invalid value", ok2)
end

-- ============================================================================
-- TEST: Validation - Boolean
-- ============================================================================

function TestConfigs.test_boolean_validation_accepts_boolean()
    local schema = {TestValue = {type = "boolean"}}
    local config = Configs("Test", {schema = schema})
    local ok1, _ = config:set("TestValue", true)
    assertTrue("boolean accepts true", ok1)
    local ok2, _ = config:set("TestValue", false)
    assertTrue("boolean accepts false", ok2)
end

function TestConfigs.test_boolean_validation_rejects_string()
    local schema = {TestValue = {type = "boolean"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", "true")
    assertFalse("boolean rejects string", ok)
end

-- ============================================================================
-- TEST: Validation - Table
-- ============================================================================

function TestConfigs.test_table_validation_accepts_table()
    local schema = {TestValue = {type = "table"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", {a = 1, b = 2})
    assertTrue("table accepts table", ok)
end

function TestConfigs.test_table_validation_rejects_string()
    local schema = {TestValue = {type = "table"}}
    local config = Configs("Test", {schema = schema})
    local ok, err = config:set("TestValue", "not a table")
    assertFalse("table rejects string", ok)
end

-- ============================================================================
-- TEST: Direct Field Access
-- ============================================================================

function TestConfigs.test_direct_read_access()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    assertEqual("direct read access", 42, config.TestValue)
end

function TestConfigs.test_direct_write_access()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    config.TestValue = 100
    assertEqual("direct write access", 100, config.TestValue)
end

-- ============================================================================
-- TEST: Reset
-- ============================================================================

function TestConfigs.test_reset_restores_defaults()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = Configs("Test", {schema = schema})
    config:set("TestValue", 100)
    config:reset()
    assertEqual("reset restores default", 42, config:get("TestValue"))
end

-- ============================================================================
-- TEST: Schema Management
-- ============================================================================

function TestConfigs.test_getSchema()
    local schema = {TestValue = {default = 42, type = "number", min = 1}}
    local config = Configs("Test", {schema = schema})
    local s = config:getSchema("TestValue")
    assertEqual("getSchema returns schema", "number", s.type)
    assertEqual("getSchema has min", 1, s.min)
end

function TestConfigs.test_setSchema_adds_new()
    local config = Configs("Test")
    config:setSchema("NewValue", {default = 99, type = "number"})
    assertEqual("setSchema sets default", 99, config:get("NewValue"))
end

-- ============================================================================
-- TEST: Save/Load (File Operations)
-- ============================================================================

-- Test file path for save/load tests
local testConfigName = "UnitTestConfig"

-- Helper: Get test config with file path helper
local function createTestConfig(schema)
    return Configs(testConfigName, {schema = schema or {}, useSeed = false})
end

-- Helper: Clean up test file using config's path
local function cleanupTestFile(config)
    if config then
        local filepath = config:_getFilePath()
        os.remove(filepath)
    end
end

function TestConfigs.test_save_returns_success()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = createTestConfig(schema)
    cleanupTestFile(config)
    local ok, err = config:save()
    assertTrue("save() returns true", ok)
    cleanupTestFile(config)
end

function TestConfigs.test_save_creates_file()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = createTestConfig(schema)
    cleanupTestFile(config)
    config:save()
    
    -- Check file exists using config's actual path
    local filepath = config:_getFilePath()
    local file = io.open(filepath, "r")
    local exists = file ~= nil
    if file then file:close() end
    
    assertTrue("save creates file", exists)
    cleanupTestFile(config)
end

function TestConfigs.test_load_returns_success()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = createTestConfig(schema)
    cleanupTestFile(config)
    config:save()
    
    -- Create new instance and load
    local config2 = createTestConfig(schema)
    local data, err = config2:load()
    assertNotNil("load() returns non-nil data", data)
    assertType("load() returns table", "table", data)
    cleanupTestFile(config)
end

function TestConfigs.test_save_load_preserves_values()
    local schema = {
        NumValue = {default = 10, type = "number"},
        StrValue = {default = "default", type = "string"},
        BoolValue = {default = false, type = "boolean"}
    }
    
    -- Save config with changed values
    local config1 = createTestConfig(schema)
    cleanupTestFile(config1)
    config1:set("NumValue", 999)
    config1:set("StrValue", "changed")
    config1:set("BoolValue", true)
    config1:save()
    
    -- Load into new instance
    local config2 = createTestConfig(schema)
    config2:load()
    
    assertEqual("load preserves number", 999, config2:get("NumValue"))
    assertEqual("load preserves string", "changed", config2:get("StrValue"))
    assertEqual("load preserves boolean", true, config2:get("BoolValue"))
    cleanupTestFile(config1)
end

function TestConfigs.test_load_nonexistent_uses_defaults()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = createTestConfig(schema)
    cleanupTestFile(config)
    local data, err = config:load()
    
    assertNotNil("load() returns non-nil data for missing file", data)
    assertEqual("uses default when file missing", 42, config:get("TestValue"))
end

function TestConfigs.test_isLoaded_after_load()
    local schema = {TestValue = {default = 42, type = "number"}}
    local config = createTestConfig(schema)
    cleanupTestFile(config)
    
    assertFalse("isLoaded false before load", config:isLoaded())
    config:load()
    assertTrue("isLoaded true after load", config:isLoaded())
end

function TestConfigs.test_save_load_with_comments()
    local schema = {
        TestValue = {default = 42, type = "number", comment = "Test comment for value"}
    }
    
    local config1 = createTestConfig(schema)
    cleanupTestFile(config1)
    config1:save()
    
    -- Check file contains comment using config's actual path
    local filepath = config1:_getFilePath()
    local file = io.open(filepath, "r")
    local content = file and file:read("*all") or ""
    if file then file:close() end
    
    local hasComment = content:find("Test comment") ~= nil
    assertTrue("save includes comments", hasComment)
    cleanupTestFile(config1)
end

-- Run all tests
function TestConfigs.runAll()
    TestConfigs.reset()
    
    -- Instance creation
    TestConfigs.test_new_creates_instance()
    TestConfigs.test_colon_syntax_initialization()
    TestConfigs.test_dot_syntax_initialization()
    TestConfigs.test_callable_syntax()
    TestConfigs.test_sets_module_name()
    TestConfigs.test_default_module_name()
    
    -- Schema and defaults
    TestConfigs.test_schema_initializes_defaults()
    TestConfigs.test_schema_initializes_comments()
    TestConfigs.test_multiple_defaults()
    
    -- Get/Set methods
    TestConfigs.test_get_returns_value()
    TestConfigs.test_get_with_meta()
    TestConfigs.test_set_updates_value()
    TestConfigs.test_set_returns_success()
    TestConfigs.test_getAll_returns_all_values()
    TestConfigs.test_setAll_sets_multiple()
    
    -- Number validation
    TestConfigs.test_number_validation_accepts_number()
    TestConfigs.test_number_validation_rejects_string()
    TestConfigs.test_number_min_validation()
    TestConfigs.test_number_max_validation()
    TestConfigs.test_number_min_max_range()
    
    -- String validation
    TestConfigs.test_string_validation_accepts_string()
    TestConfigs.test_string_validation_rejects_number()
    TestConfigs.test_string_enum_validation()
    
    -- Boolean validation
    TestConfigs.test_boolean_validation_accepts_boolean()
    TestConfigs.test_boolean_validation_rejects_string()
    
    -- Table validation
    TestConfigs.test_table_validation_accepts_table()
    TestConfigs.test_table_validation_rejects_string()
    
    -- Direct field access
    TestConfigs.test_direct_read_access()
    TestConfigs.test_direct_write_access()
    
    -- Reset
    TestConfigs.test_reset_restores_defaults()
    
    -- Schema management
    TestConfigs.test_getSchema()
    TestConfigs.test_setSchema_adds_new()
    
    -- Save/Load (File Operations)
    TestConfigs.test_save_returns_success()
    TestConfigs.test_save_creates_file()
    TestConfigs.test_load_returns_success()
    TestConfigs.test_save_load_preserves_values()
    TestConfigs.test_load_nonexistent_uses_defaults()
    TestConfigs.test_isLoaded_after_load()
    TestConfigs.test_save_load_with_comments()
    
    return results
end

-- Get formatted results
function TestConfigs.getResults()
    return results
end

return TestConfigs

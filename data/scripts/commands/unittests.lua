--[[
    Unit Test Runner Command
    
    Usage:
        /unittests           - Run all tests
        /unittests logger    - Run Logger tests only
        /unittests configs   - Run Configs tests only
        /unittests help      - Show help
    
    NOTE: Delete this file and data/scripts/tests/ folder before release!
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/commands/?.lua"

-- Available test modules (loaded from tests/commands/)
local testModules = {
    logger = "test_logger",
    configs = "test_configs",
    tableshow = "test_tableshow",
    ui = "test_ui",
    colorutils = "test_colorutils",
    gateregistry = "test_gateregistry"
}

-- Format test results for output
local function formatResults(moduleName, results)
    local output = {}
    
    table.insert(output, string.format("\n=== %s Tests ===", moduleName:upper()))
    table.insert(output, string.format("Passed: %d | Failed: %d", results.passed, results.failed))
    table.insert(output, "---")
    
    for _, test in ipairs(results.tests) do
        if test.status == "PASS" then
            table.insert(output, string.format("[PASS] %s", test.name))
        else
            table.insert(output, string.format("[FAIL] %s", test.name))
            table.insert(output, string.format("       Expected: %s", test.expected or "?"))
            table.insert(output, string.format("       Actual:   %s", test.actual or "?"))
        end
    end
    
    return table.concat(output, "\n")
end

-- Run tests for a specific module
local function runModuleTests(moduleName)
    local testFile = testModules[moduleName]
    if not testFile then
        return nil, nil, string.format("Unknown test module: %s", moduleName)
    end
    
    local ok, testModule = pcall(include, testFile)
    if not ok then
        return nil, nil, string.format("Failed to load %s: %s", testFile, tostring(testModule))
    end
    
    local results = testModule.runAll()
    return formatResults(moduleName, results), results, nil
end

-- Run all tests
local function runAllTests()
    local allOutput = {}
    local totalPassed = 0
    local totalFailed = 0
    
    for moduleName, _ in pairs(testModules) do
        local output, results, err = runModuleTests(moduleName)
        if err then
            table.insert(allOutput, string.format("[ERROR] %s: %s", moduleName, err))
        else
            table.insert(allOutput, output)
            -- Count totals
            if results then
                totalPassed = totalPassed + (results.passed or 0)
                totalFailed = totalFailed + (results.failed or 0)
            end
        end
    end
    
    table.insert(allOutput, "\n=== SUMMARY ===")
    table.insert(allOutput, string.format("Total Passed: %d | Total Failed: %d", totalPassed, totalFailed))
    
    if totalFailed == 0 then
        table.insert(allOutput, "All tests passed!")
    else
        table.insert(allOutput, "Some tests failed!")
    end
    
    return table.concat(allOutput, "\n")
end

-- Show help
local function showHelp()
    local modules = {}
    for name, _ in pairs(testModules) do
        table.insert(modules, name)
    end
    
    return string.format([[
Unit Test Runner

Usage:
    /unittests           - Run all tests
    /unittests <module>  - Run specific module tests
    /unittests help      - Show this help

Available modules: %s

Tests location: data/scripts/tests/commands/

NOTE: Delete commands/unittests.lua and tests/ folder before release!
]], table.concat(modules, ", "))
end

-- Main command entry point
function execute(sender, commandName, moduleName)
    if moduleName == "help" then
        return 0, "", showHelp()
    end
    
    local output
    
    if moduleName then
        local result, _, err = runModuleTests(moduleName)
        if err then
            return 1, "", err
        end
        output = result
    else
        output = runAllTests()
    end
    
    -- Print to console
    print(output)
    
    return 0, "", output
end

function getDescription()
    return "Run unit tests for mod libraries (DEV ONLY)"
end

function getHelp()
    return showHelp()
end

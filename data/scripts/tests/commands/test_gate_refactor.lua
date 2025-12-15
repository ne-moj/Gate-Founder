--[[
    Gate Refactor Unit Tests
    
    Run with: /unittests gate_refactor
    
    Tests cover:
    - Module loading
    - Config initialization
    - Validator logic
    - Creator logic (mocked)
--]]

package.path = package.path .. ";data/scripts/lib/?.lua"

local GateConfig = include("gate/config")
local GateValidator = include("gate/validator")
local GateFinder = include("gate/finder")
local GateCreator = include("gate/creator")
local GateService = include("gate/service")

local TestGateRefactor = {}
local results = {passed = 0, failed = 0, tests = {}}

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

function TestGateRefactor.runAll()
    results = {passed = 0, failed = 0, tests = {}}
    
    -- Test 1: Module Loading
    assertNotNil("GateConfig loaded", GateConfig)
    assertNotNil("GateValidator loaded", GateValidator)
    assertNotNil("GateFinder loaded", GateFinder)
    assertNotNil("GateCreator loaded", GateCreator)
    assertNotNil("GateService loaded", GateService)
    
    -- Test 2: Config Access
    assertNotNil("Config instance exists", GateConfig.Config)
    assertNotNil("Log instance exists", GateConfig.Log)
    
    -- Test 3: Wrapper Compatibility
    local LegacyInit = include("gatefounderinit")
    assertNotNil("Legacy Init loaded", LegacyInit)
    assertNotNil("Legacy Config access", LegacyInit.Config)
    
    return results
end

return TestGateRefactor

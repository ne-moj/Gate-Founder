package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/?.lua"

local UnitTest = include("unittest")
UnitTest.injectGlobals()

-- Mock Global Environment for Server interactions
local OriginalOnServer = _G.onServer
local OriginalOnClient = _G.onClient
local OriginalServer = _G.Server

-- Mock Server class
local MockServerStore = {}
local MockServer = {
    getValue = function(self, key)
        return MockServerStore[key]
    end,
    setValue = function(self, key, value)
        MockServerStore[key] = value
    end,
    time = 1234567890
}
local function MockServerFunc() return MockServer end

-- Include GateRegistry after mocks definition (but before assignment to _G if we did it globally)
-- Note: include just loads the table, functions inside call Server() dynamically.
local GateRegistry = include("gate/registry")

local TestGateRegistry = {}

function TestGateRegistry.test_add_gate_v2()
    UnitTest.reset()
    MockServerStore = {} -- Clear store
    
    -- Add gate from 10:20 -> 100:200
    local success = GateRegistry.add(10, 20, 999, 100, 200)
    assertTrue("add returns true", success)
    
    -- Verify retrieval with full route
    local gate = GateRegistry.get(10, 20, 100, 200)
    assertNotNil("gate stored", gate)
    assertEqual("owner correct", 999, gate.owner)
    assertEqual("linkedTo x", 100, gate.linkedTo.x)
    assertEqual("linkedTo y", 200, gate.linkedTo.y)
    
    -- Add ANOTHER gate from 10:20 -> 300:400 (Multiple gates in same sector)
    local success2 = GateRegistry.add(10, 20, 999, 300, 400)
    assertTrue("second add returns true", success2)
    
    local gate2 = GateRegistry.get(10, 20, 300, 400)
    assertNotNil("second gate stored", gate2)
    
    -- Check persistence
    assertNotNil("saved to server", MockServerStore["GateRegistry"])
end

function TestGateRegistry.test_get_in_sector()
    MockServerStore = {}
    GateRegistry.load() 
    
    GateRegistry.add(50, 50, 1, 100, 100)
    GateRegistry.add(50, 50, 1, 200, 200)
    GateRegistry.add(60, 60, 1, 100, 100) -- Different sector
    
    local sectorGates = GateRegistry.getInSector(50, 50)
    assertEqual("found 2 gates in 50:50", 2, #sectorGates)
    
    -- Verify data integrity
    local found100 = false
    local found200 = false
    for _, g in ipairs(sectorGates) do
        if g.linkedTo.x == 100 then found100 = true end
        if g.linkedTo.x == 200 then found200 = true end
        assertEqual("source x correct", 50, g.x)
        assertEqual("source y correct", 50, g.y)
    end
    assertTrue("found target 100", found100)
    assertTrue("found target 200", found200)
end

function TestGateRegistry.test_remove_gate_v2()
    MockServerStore = {}
    GateRegistry.load()
    GateRegistry.add(5, 5, 1, 10, 10)
    
    local success = GateRegistry.remove(5, 5, 10, 10)
    assertTrue("remove returns true", success)
    assertNil("gate removed from memory", GateRegistry.get(5, 5, 10, 10))
end

function TestGateRegistry.test_update_gate_v2()
    MockServerStore = {}
    GateRegistry.load()
    GateRegistry.add(10, 10, 111, 20, 20)
    
    local success = GateRegistry.update(10, 10, 20, 20, {status = "disabled"})
    assertTrue("update returns true", success)
    
    local gate = GateRegistry.get(10, 10, 20, 20)
    assertEqual("status updated", "disabled", gate.status)
end

function TestGateRegistry.test_getNearest_v2()
    MockServerStore = {}
    GateRegistry.load()
    GateRegistry.add(0, 0, 100, 10, 10)    -- Dist 0
    GateRegistry.add(10, 0, 100, 10, 10)   -- Dist 10
    GateRegistry.add(20, 0, 200, 10, 10)   -- Dist 20
    GateRegistry.add(0, 0, 100, 20, 20)    -- Dist 0 (Same sector, diff target)
    
    local results = GateRegistry.getNearest(0, 0, 10)
    assertEqual("found all", 4, #results)
    
    -- First two should be distance 0 (order unstable but both 0)
    assertTrue("first is at 0,0", results[1].distSq == 0)
    assertTrue("second is at 0,0", results[2].distSq == 0)
    
    -- Test radius
    local radiusFiltered = GateRegistry.getNearest(0, 0, 10, nil, 5)
    assertEqual("found 2 gates within radius 5 (at 0,0)", 2, #radiusFiltered)
end

function TestGateRegistry.test_migration()
    -- Test old schema migration
    local oldData = "{ ['10_10'] = { owner = 777, linkedTo = {x=20, y=20}, created=123 } }"
    MockServerStore["GateRegistry"] = oldData
    
    GateRegistry.load()
    
    -- Should have migrated to '10_10_20_20'
    local newGate = GateRegistry.get(10, 10, 20, 20)
    assertNotNil("migrated gate found", newGate)
    assertEqual("owner preserved", 777, newGate.owner)
    
    -- Check if old key is gone (getInSector(10,10) returns it, but internally key structure changed)
    -- We can inspect storage to verify save format
    local saved = MockServerStore["GateRegistry"]
    assertNotNil("saved", saved)
    -- Simple string check
    if saved:find("10_10_20_20") then
         assertTrue("New key format found in save", true)
    else
         assertTrue("New key format NOT found in save", false)
    end
end

function TestGateRegistry.runAll()
    -- INSTALL MOCKS
    _G.onServer = function() return true end
    _G.onClient = function() return false end
    _G.Server = MockServerFunc

    local status, err = pcall(function()
        UnitTest.reset()
        TestGateRegistry.test_add_gate_v2()
        TestGateRegistry.test_get_in_sector()
        TestGateRegistry.test_remove_gate_v2()
        TestGateRegistry.test_update_gate_v2()
        TestGateRegistry.test_getNearest_v2()
        TestGateRegistry.test_migration()
    end)

    -- RESTORE GLOBALS
    _G.onServer = OriginalOnServer
    _G.onClient = OriginalOnClient
    _G.Server = OriginalServer

    if not status then
        error(err)
    end

    return UnitTest.getResults()
end

function TestGateRegistry.getResults()
    return UnitTest.getResults()
end

return TestGateRegistry

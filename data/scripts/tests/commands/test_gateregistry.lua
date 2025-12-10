package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/tests/?.lua"

local UnitTest = include("unittest")
UnitTest.injectGlobals()

-- Mock Global Environment for Server interactions
_G.onServer = function() return true end
_G.onClient = function() return false end

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
_G.Server = function() return MockServer end

-- Include GateRegistry after mocks
local GateRegistry = include("gateregistry")

local TestGateRegistry = {}

function TestGateRegistry.test_add_gate()
    UnitTest.reset()
    MockServerStore = {} -- Clear store
    
    local success = GateRegistry.add(10, 20, 999, 100, 200)
    assertTrue("add returns true", success)
    
    local gate = GateRegistry.get(10, 20)
    assertNotNil("gate stored", gate)
    assertEqual("owner correct", 999, gate.owner)
    assertEqual("linkedTo x", 100, gate.linkedTo.x)
    assertEqual("linkedTo y", 200, gate.linkedTo.y)
    
    -- Verify persistence was called (value in store)
    assertNotNil("saved to server", MockServerStore["GateRegistry"])
end

function TestGateRegistry.test_remove_gate()
    MockServerStore = {}
    GateRegistry.load() -- Reset state
    GateRegistry.add(5, 5, 1, 0, 0)
    
    local success = GateRegistry.remove(5, 5)
    assertTrue("remove returns true", success)
    assertNil("gate removed from memory", GateRegistry.get(5, 5))
end

function TestGateRegistry.test_getByOwner()
    MockServerStore = {}
    GateRegistry.load() -- Reset state
    GateRegistry.add(1, 1, 555, 0, 0)
    GateRegistry.add(2, 2, 555, 0, 0)
    GateRegistry.add(3, 3, 666, 0, 0)
    
    local gates555 = GateRegistry.getByOwner(555)
    assertEqual("found 2 gates for owner 555", 2, #gates555)
    
    local gates666 = GateRegistry.getByOwner(666)
    assertEqual("found 1 gate for owner 666", 1, #gates666)
end

function TestGateRegistry.test_update_gate()
    MockServerStore = {}
    GateRegistry.load() -- Reset state
    GateRegistry.add(10, 10, 111, 0, 0)
    
    local success = GateRegistry.update(10, 10, {status = "disabled", usageCount = 5})
    assertTrue("update returns true", success)
    
    local gate = GateRegistry.get(10, 10)
    assertEqual("status updated", "disabled", gate.status)
    assertEqual("usageCount updated", 5, gate.usageCount)
    assertEqual("owner preserved", 111, gate.owner)
end

function TestGateRegistry.test_getNearest()
    MockServerStore = {}
    GateRegistry.load() -- Reset state
    GateRegistry.add(0, 0, 100, 10, 10)    -- Dist 0
    GateRegistry.add(10, 0, 100, 10, 10)   -- Dist 10
    GateRegistry.add(20, 0, 200, 10, 10)   -- Dist 20 (Diff owner)
    GateRegistry.add(5, 5, 100, 10, 10)    -- Dist ~7
    
    -- Test sorting (searching from 0,0)
    local results = GateRegistry.getNearest(0, 0, 10)
    assertEqual("found all", 4, #results)
    assertEqual("first is (0,0)", 0, results[1].gate.x)
    assertEqual("second is (5,5)", 5, results[2].gate.x)
    assertEqual("third is (10,0)", 10, results[3].gate.x)
    
    -- Test limit
    local limited = GateRegistry.getNearest(0, 0, 2)
    assertEqual("found limited", 2, #limited)
    
    -- Test owner filter (owner 100 only)
    local filtered = GateRegistry.getNearest(0, 0, 10, 100)
    assertEqual("found filtered", 3, #filtered)
    -- Check none have owner 200
    for _, res in pairs(filtered) do
        if res.gate.owner == 200 then
             assertTrue("Filter fail", false)
        end
    end

    -- Test radius filter (radius 8 -> include 0,0 and 5,5 (d~7.07), exclude 10,0)
    local radiusFiltered = GateRegistry.getNearest(0, 0, 10, nil, 8)
    assertEqual("found in radius 8", 2, #radiusFiltered)
    -- Should be (0,0) and (5,5)
    
    local farRadius = GateRegistry.getNearest(0, 0, 10, nil, 10) -- includes 10,0? distSq 100. maxSq 100. includes.
    assertEqual("found in radius 10", 3, #farRadius)
end

function TestGateRegistry.test_persistence()
    -- Manually set Mock Store with serialized data
    -- GateRegistry uses custom simple serialize: "{ ... }"
    local mockData = "{ ['10_10'] = { owner = 777 } }"
    MockServerStore["GateRegistry"] = mockData
    
    -- Force reload (we might need a reload method or hack internal state)
    -- GateRegistry doesn't have public reload, but load() checks onServer.
    -- We can call GateRegistry.load() explicitly.
    GateRegistry.load()
    
    local gate = GateRegistry.get(10, 10)
    assertNotNil("loaded data from persistence", gate)
    assertEqual("loaded correct owner", 777, gate.owner)
end

function TestGateRegistry.runAll()
    UnitTest.reset()
    TestGateRegistry.test_add_gate()
    TestGateRegistry.test_remove_gate()
    TestGateRegistry.test_getByOwner()
    TestGateRegistry.test_update_gate()
    TestGateRegistry.test_getNearest()
    TestGateRegistry.test_persistence()
    return UnitTest.getResults()
end

function TestGateRegistry.getResults()
    return UnitTest.getResults()
end

return TestGateRegistry

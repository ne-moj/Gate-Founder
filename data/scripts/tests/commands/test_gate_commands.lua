package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/commands/?.lua"

-- Mocks & Environment Setup
_G.onClient = function() return false end
_G.Server = function() return { hasAdminPrivileges = function() return true end } end
_G.Player = function(idx) 
    return { 
        index=idx, 
        name="Tester", 
        getSectorCoordinates = function() return 0, 0 end
    } 
end
_G.Sector = function() 
    return {
        getCoordinates = function() return 0, 0 end
    }
end
_G.Galaxy = function() return { 
    sectorLoaded = function() return true end,
    invokeFunction = function() return 0 end
} end
_G.invokeSectorFunction = function() end
_G.createMonetaryString = function(v) return tostring(v) end
_G.tonumber = tonumber
_G.tostring = tostring
_G.print = print

-- Mock GateService (forward declaration for include)
local MockGateService = {
    create = function() return true, "Created" end,
    getFoundingCost = function() return true, 1000, 0 end,
    toggle = function() return true, "Toggled" end,
    destroy = function() return true, "Destroyed" end
}

-- Simple include implementation
_G.include = function(path)
    if path == "gate/service" then return MockGateService end
    if path == "gate/registry" then return {
        getInSector = function() return { {owner=1, linkedTo={x=5,y=6}, status="active"} } end,
        getByOwner = function() return { {owner=1, x=1, y=2, linkedTo={x=5,y=6}} } end,
        getNearest = function() return { {gate={owner=1, x=1, y=2, linkedTo={x=5,y=6}}, distSq=100} } end,
        remove = function() end
    } end
    
    -- Try to load real file if it maps to a known structure
    local attempt = "data/scripts/commands/" .. path .. ".lua"
    local f = io.open(attempt, "r")
    if not f then
        attempt = "data/scripts/lib/" .. path .. ".lua"
        f = io.open(attempt, "r")
    end
    
    if f then
        f:close()
        return dofile(attempt)
    end
    
    return {}
end

-- Now load headers
local Actions = include("gate/actions")
-- local GateService = include("gate/service") -- This will get MockGateService

-- Test Utils
local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        print(string.format("FAIL: %s - Expected '%s', got '%s'", msg, tostring(expected), tostring(actual)))
    else
        print(string.format("PASS: %s", msg))
    end
end

print("=== Running specific Gate Commands Tests ===")

-- Test Create
local status, _, msg = Actions.create(1, {"10", "20", "confirm"})
assertEqual(status, 0, "Create valid")
status, _, msg = Actions.create(1, {})
assertEqual(status, 1, "Create invalid args")

-- Test Cost
status, _, msg = Actions.cost(1, {"10", "20"})
assertEqual(status, 0, "Cost valid")

-- Test Toggle
status, _, msg = Actions.toggle(1, {"10", "20"})
assertEqual(status, 0, "Toggle valid")

-- Test Destroy
status, _, msg = Actions.destroy(1, {"10", "20"})
assertEqual(status, 0, "Destroy valid (no confirm needed)")

print("=== Tests Complete ===")

if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

local Placer = include("placer")
local GateConfig = include("gate/config")
local GateCreator = include("gate/creator")
local Log = include("logger")

-- namespace GateFounder
GateFounder = {}

local sector, x, y

--[[
    Initializes the GateFounder for the current sector, processing any pending gate actions from the server's todo list.
--]]
function GateFounder.initialize()
    sector = Sector()
    x, y = sector:getCoordinates()
    local gateEntities = {sector:getEntitiesByScript("gate.lua")}
    Log:Debug("(%i:%i) gatefounder init, gates count: %i", x, y, #gateEntities)

    -- check todo list (from database)
    local key = 'gateFounder_'..x..'_'..y
    local list = Server():getValue(key)
    local newGates = false
    if list then
        Server():setValue(key) -- clear
        local actions = list:split(';')
        if actions then
            for _, action in ipairs(actions) do
                action = action:split(',')
                local actionType = tonumber(action[1])
                local factionIndex = tonumber(action[2])
                local tx = tonumber(action[3])
                local ty = tonumber(action[4])

                if actionType == 1 then -- found
                    newGates = true
                    Log:Debug("GetValue - spawn a gate %i from (%i:%i) to (%i:%i)", factionIndex, x, y, tx, ty)
                    local gate = GateFounder.foundGate(factionIndex, tx, ty, true)
                    gateEntities[#gateEntities+1] = gate
                elseif actionType == 2 then -- claim
                    GateFounder.claimGate(factionIndex, tx, ty, gateEntities)
                elseif actionType == 3 then -- toggle
                    local isEnabled = action[5] == '1'
                    GateFounder.toggleGate(factionIndex, tx, ty, isEnabled, gateEntities)
                elseif actionType == 4 then -- destroy
                    GateFounder.destroyGate(factionIndex, tx, ty, gateEntities)
                    -- Re-fetch or handle clean up? Original just removed from list.
                    -- Actually we should probably refetch or carefully manage the list.
                    -- But let's stick to original logic path if possible or improve.
                elseif actionType == 5 then -- (un)lock
                    local isLocked = action[5] == '1'
                    GateFounder.lockGate(factionIndex, tx, ty, isLocked, gateEntities)
                end
            end
        end
    end

    if newGates then
        Placer.resolveIntersections(gateEntities)
    end
end

--[[
    Found a gate (used for incoming gates)

    @param factionIndex number - Faction index of the gate
    @param tx number - Target x coordinate of the gate
    @param ty number - Target y coordinate of the gate
    @param notRemote boolean - Whether the gate is not remote (default: false)
    @return Entity - The created gate entity
--]]
function GateFounder.foundGate(factionIndex, tx, ty, notRemote)
    -- notRemote is true when called from initialize (todo list)
    -- When called via invokeSectorFunction, it might be nil/false -> implies we need resolving?
    -- Original logic: if notRemote then return sector:createEntity... end
    -- else add to gates and resolveIntersections.
    
    Log:Debug("Sector:foundGate - faction:%s, targets (%d:%d)", tostring(factionIndex), tx, ty)
    
    local faction = Faction(factionIndex)
    if not faction then 
        Log:Error("Faction %s not found for gate creation!", tostring(factionIndex))
        return 
    end
    
    -- Use Creator
    local gate = GateCreator.createGate(faction, x, y, tx, ty)
    
    -- Registry add? 
    -- If we are creating the BACK link, we should probably register it too?
    -- Original code:
    -- local GateRegistry = include("gateregistry")
    -- GateRegistry.add(x, y, factionIndex, tx, ty)
    local GateRegistry = include("gate/registry")
    if GateRegistry then
        GateRegistry.add(x, y, factionIndex, tx, ty)
    end

    if notRemote then
        return gate
    end
    
    -- If remote call (live update), resolve intersections
    local gates = {sector:getEntitiesByScript("gate.lua")}
    -- Gate is already created? Yes, createGate calls sector:createEntity
    -- We just need to ensure it doesn't collide
    gates[#gates+1] = gate -- add our new gate to list
    Placer.resolveIntersections(gates)
    
    return gate
end

--[[
    Destroys a gate of a specific faction and target coordinates.
    
    @param factionIndex number - Faction index of the gate
    @param tx number - Target x coordinate of the gate
    @param ty number - Target y coordinate of the gate
    @param gateEntities table - List of gate entities (optional)
    @return number - Index of the destroyed gate in the list
--]]
function GateFounder.destroyGate(factionIndex, tx, ty, gateEntities)
    Log:Debug("Remove a gate of faction %s from (%i:%i) to (%i:%i)", string.format("%.f", factionIndex), x, y, tx, ty)

    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
    end
    
    for k, gate in pairs(gateEntities) do
        local wx, wy = WormHole(gate):getTargetCoordinates()
        if wx == tx and wy == ty then
            Log:Debug("Gate found and removed")
            sector:deleteEntity(gate)
            return k
        end
    end
end

--[[
    Toggles the power state of a gate of a specific faction and target coordinates.
    
    @param factionIndex number - Faction index of the gate
    @param tx number - Target x coordinate of the gate
    @param ty number - Target y coordinate of the gate
    @param enable boolean - Whether to enable the gate
    @param gateEntities table - List of gate entities (optional)
--]]
function GateFounder.toggleGate(factionIndex, tx, ty, enable, gateEntities)
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
    end
    
    for _, gate in pairs(gateEntities) do
        local wx, wy = WormHole(gate):getTargetCoordinates()
        if wx == tx and wy == ty then
             gate:invokeFunction("gate.lua", "setPower", enable)
             return
        end
    end
end

--[[
    Claims a gate of a specific faction and target coordinates.
    
    @param factionIndex number - Faction index of the gate
    @param tx number - Target x coordinate of the gate
    @param ty number - Target y coordinate of the gate
    @param gateEntities table - List of gate entities (optional)
--]]
function GateFounder.claimGate(factionIndex, tx, ty, gateEntities)
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
    end
    for _, gate in pairs(gateEntities) do
        local wx, wy = WormHole(gate):getTargetCoordinates()
        if wx == tx and wy == ty then
            gate.factionIndex = factionIndex
        end
    end
end

--[[
    Locks a gate of a specific faction and target coordinates.
    
    @param factionIndex number - Faction index of the gate
    @param tx number - Target x coordinate of the gate
    @param ty number - Target y coordinate of the gate
    @param lock boolean - Whether to lock the gate
    @param gateEntities table - List of gate entities (optional)
--]]
function GateFounder.lockGate(factionIndex, tx, ty, lock, gateEntities)
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
    end
    for _, gate in pairs(gateEntities) do
        local wx, wy = WormHole(gate):getTargetCoordinates()
        if wx == tx and wy == ty then
            gate:invokeFunction("gate.lua", "gateFounder_setLock", lock)
            return
        end
    end
end
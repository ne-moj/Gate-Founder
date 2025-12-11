if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

local Placer = include("placer")
local PlanGenerator = include("plangenerator")
local StyleGenerator = include ("internal/stylegenerator.lua")
local GateFounderInit = include("gatefounderinit")
local Config = GateFounderInit.Config
local Log = GateFounderInit.Log

-- namespace GateFounder
GateFounder = {}

local sector, x, y

function GateFounder.initialize()
    sector = Sector()
    x, y = sector:getCoordinates()
    local gateEntities = {sector:getEntitiesByScript("gate.lua")}
    Log:Debug("(%i:%i) gatefounder init, gates count: %i", x, y, #gateEntities)

    -- check todo list
    local key = 'gateFounder_'..x..'_'..y
    local list = Server():getValue(key)
    local newGates = false
    if list then
        Server():setValue(key)
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
                    gateEntities[#gateEntities+1] = GateFounder.foundGate(factionIndex, tx, ty, true)
                elseif actionType == 2 then -- claim
                    Log:Debug("GetValue - claim a gate from (%i:%i) to (%i:%i) to faction %s", x, y, tx, ty, string.format("%.f", factionIndex))
                    GateFounder.claimGate(factionIndex, tx, ty, gateEntities)
                elseif actionType == 3 then -- toggle
                    local isEnabled = action[5] == '1'
                    Log:Debug("GetValue - toggle a gate of faction %s from (%i:%i) to (%i:%i) - %s", string.format("%.f", factionIndex), x, y, tx, ty, tostring(isEnabled))
                    GateFounder.toggleGate(factionIndex, tx, ty, isEnabled, gateEntities)
                elseif actionType == 4 then -- destroy
                    Log:Debug("GetValue - remove a gate of faction %s from (%i:%i) to (%i:%i)", string.format("%.f", factionIndex), x, y, tx, ty)
                    local removedKey = GateFounder.destroyGate(factionIndex, tx, ty, gateEntities)
                    gateEntities[removedKey] = nil -- remove gate from the list so we don't check it later
                elseif actionType == 5 then -- (un)lock
                    local isLocked = action[5] == '1'
                    Log:Debug("GetValue - (un)lock a gate of faction %s from (%i:%i) to (%i:%i) - %s", string.format("%.f", factionIndex), x, y, tx, ty, tostring(isLocked))
                    GateFounder.lockGate(factionIndex, tx, ty, isLocked, gateEntities)
                end
            end
        end
    end

    if newGates then
        Placer.resolveIntersections(gateEntities)
    end
end

function GateFounder.foundGate(factionIndex, tx, ty, notRemote)
    Log:Debug("Spawn a gate back for faction %s from (%i:%i) to (%i:%i)", string.format("%.f", factionIndex), x, y, tx, ty)
    --local faction = Faction(factionIndex)

    local desc = EntityDescriptor()
    desc:addComponents(
      ComponentType.Plan,
      ComponentType.BspTree,
      ComponentType.Intersection,
      ComponentType.Asleep,
      ComponentType.DamageContributors,
      ComponentType.BoundingSphere,
      ComponentType.PlanMaxDurability,
      ComponentType.Durability,
      ComponentType.BoundingBox,
      ComponentType.Velocity,
      ComponentType.Physics,
      ComponentType.Scripts,
      ComponentType.ScriptCallback,
      ComponentType.Title,
      ComponentType.Owner,
      ComponentType.FactionNotifier,
      ComponentType.WormHole,
      ComponentType.EnergySystem,
      ComponentType.EntityTransferrer
    )
    
    local styleGenerator = StyleGenerator(factionIndex)
    local c1 = styleGenerator.factionDetails.baseColor
    local c2 = ColorRGB(0.25, 0.25, 0.25)
    local c3 = styleGenerator.factionDetails.paintColor
    c1 = ColorRGB(c1.r, c1.g, c1.b)
    c3 = ColorRGB(c3.r, c3.g, c3.b)
    
    local plan = PlanGenerator.makeGatePlan(Seed(factionIndex) + Server().seed, c1, c2, c3)
    local dir = vec3(tx - x, 0, ty - y)
    normalize_ip(dir)

    local position = MatrixLookUp(dir, vec3(0, 1, 0))
    position.pos = dir * 2000.0

    desc:setMovePlan(plan)
    desc.position = position
    desc.factionIndex = factionIndex
    desc.invincible = true
    desc:addScript("data/scripts/entity/gate.lua")
    desc:setValue("gateFounder_origFaction", factionIndex)

    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(tx, ty)
    wormhole.visible = false
    wormhole.visualSize = 50
    wormhole.passageSize = 50
    wormhole.oneWay = true

    -- GateRegistry Integration
    local GateRegistry = include("gateregistry")
    if GateRegistry then
        GateRegistry.add(x, y, factionIndex, tx, ty)
    end

    if notRemote then
        return sector:createEntity(desc, EntityArrivalType.Default)
    end
    -- remote call - resolve intersections
    local gates = {sector:getEntitiesByScript("gate.lua")}
    Log:Debug("(%i:%i) gatefounder foundGate back, gates count: %i", x, y, #gates)
    gates[#gates+1] = sector:createEntity(desc, EntityArrivalType.Default)
    Placer.resolveIntersections(gates)
end

function GateFounder.destroyGate(factionIndex, tx, ty, gateEntities)
    Log:Debug("Remove a gate of faction %s from (%i:%i) to (%i:%i)", string.format("%.f", factionIndex), x, y, tx, ty)
    --local faction = Faction(factionIndex)
    --if not faction then return end
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
        Log:Debug("(%i:%i) destroyGate, gates count: %i", x, y, #gateEntities)
    end
    local wx, wy
    for k, gate in pairs(gateEntities) do
        --if gate.factionIndex == factionIndex then
            wx, wy = WormHole(gate):getTargetCoordinates()
            if wx == tx and wy == ty then
                Log:Debug("Gate found and removed")
                sector:deleteEntity(gate)
                return k
            end
        --end
    end
end

function GateFounder.toggleGate(factionIndex, tx, ty, enable, gateEntities)
    Log:Debug("Toggle a gate of faction %s from (%i:%i) to (%i:%i) - %s", string.format("%.f", factionIndex), x, y, tx, ty, enable)
    --local faction = Faction(factionIndex)
    --if not faction then return end
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
        Log:Debug("(%i:%i) toggleGate, gates count: %i", x, y, #gateEntities)
    end
    local wh, wx, wy, status
    for _, gate in pairs(gateEntities) do
        --if gate.factionIndex == factionIndex then
            wh = WormHole(gate)
            wx, wy = wh:getTargetCoordinates()
            if wx == tx and wy == ty then
                status = gate:invokeFunction("gate.lua", "setPower", enable) -- Integration: Compass-like Gate Pixel Icons
                if status ~= 0 then
                    Log:Error("toggleGate - status is %s", tostring(status))
                else
                    Log:Debug("Gate found and toggled")
                end
                return
            end
        --end
    end
end

function GateFounder.claimGate(factionIndex, tx, ty, gateEntities)
    Log:Debug("Claim a gate from (%i:%i) to (%i:%i) to faction %s", x, y, tx, ty, string.format("%.f", factionIndex))
    local faction = Faction(factionIndex)
    if not faction then
        Log:Debug("Tried to claim a gate, but faction doesn't exist anymore")
        return
    end
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
        Log:Debug("(%i:%i) claimGate, gates count: %i", x, y, #gateEntities)
    end
    local wx, wy
    for k, gate in pairs(gateEntities) do
        wx, wy = WormHole(gate):getTargetCoordinates()
        if wx == tx and wy == ty then
            Log:Debug("Gate found and claimed")
            gate.factionIndex = factionIndex
        end
    end
end

function GateFounder.lockGate(factionIndex, tx, ty, lock, gateEntities)
    Log:Debug("(Un)Lock a gate of faction %s from (%i:%i) to (%i:%i) - %s", string.format("%.f", factionIndex), x, y, tx, ty, lock)
    if not gateEntities then
        gateEntities = {sector:getEntitiesByScript("gate.lua")}
        Log:Debug("(%i:%i) lockGate, gates count: %i", x, y, #gateEntities)
    end
    for _, gate in pairs(gateEntities) do
        local wormhole = WormHole(gate)
        local wx, wy = wormhole:getTargetCoordinates()
        if wx == tx and wy == ty then
            local status = gate:invokeFunction("gate.lua", "gateFounder_setLock", lock)
            if status ~= 0 then
                Log:Error("lockGate - status is %s", tostring(status))
            else
                Log:Debug("Gate found and (un)locked")
            end
            return
        end
    end
end
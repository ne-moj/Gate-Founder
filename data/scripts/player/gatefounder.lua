if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include("faction")
include("galaxy")
include("stringutility")
local PassageMap = include("passagemap")
local Placer = include("placer")
local PlanGenerator = include("plangenerator")
local SectorSpecifics = include("sectorspecifics")
local Azimuth, Config, Log = unpack(include("gatefounderinit"))

-- namespace GateFounder
GateFounder = {}

local function createGates(faction, x, y, tx, ty)
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
    local plan = PlanGenerator.makeGatePlan(Seed(faction.index) + Server().seed, faction.color1, faction.color2, faction.color3)
    local dir = vec3(tx - x, 0, ty - y)
    normalize_ip(dir)

    local position = MatrixLookUp(dir, vec3(0, 1, 0))
    position.pos = dir * 2000.0

    desc:setMovePlan(plan)
    desc.position = position
    desc.factionIndex = faction.index
    desc.invincible = true
    desc:addScript("data/scripts/entity/gate.lua")

    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(tx, ty)
    wormhole.visible = false
    wormhole.visualSize = 50
    wormhole.passageSize = 50
    wormhole.oneWay = true

    return Sector():createEntity(desc)
end

function GateFounder.found(tx, ty, confirm, isCommand)
    Log.Debug("Player:GateFounder - found", tx, ty, confirm, isCommand)
    local server = Server()
    local player = Player()
    local isAdmin = server:hasAdminPrivileges(player)

    if isCommand and Config.UseStationFounderShip and not isAdmin then
        player:sendChatMessage("", 1, "Build station founder ships on any shipyard in order to found gates!"%_t)
        return
    end

    local buyer, _, player = getInteractingFaction(player.index, AlliancePrivilege.FoundStations)
    if not buyer then
        Log.Error("Player:GateFounder - buyer is nil")
        player:sendChatMessage("", 1, "GateFounder: An error has occured")
        return
    end

    if buyer.isPlayer and Config.AlliancesOnly then
        player:sendChatMessage("", 1, "Only alliances can found gates!"%_t)
        return
    end

    local gateCount = buyer:getValue("gates_founded") or 0
    if gateCount >= Config.MaxGatesPerFaction then
        player:sendChatMessage("", 1, "Reached the maximum amount of founded gates!"%_t)
        return
    end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    if x == tx and y == ty then       
        player:sendChatMessage("", 1, "Gates can't lead in the same sector!"%_t)
        return
    end

    local d = distance(vec2(x, y), vec2(tx, ty))
    if d > Config.MaxDistance then
        player:sendChatMessage("", 1, "Distance between gates is too big!"%_t)
        return
    end

    passageMap = PassageMap(server.seed)
    if not passageMap:passable(tx, ty) and not isAdmin then
        player:sendChatMessage("", 1, "Gates can't lead into rifts!"%_t)
        return
    end

    local xyInsideRing = passageMap:insideRing(x, y)
    if xyInsideRing ~= passageMap:insideRing(tx, ty) then
        if not Config.AllowToPassBarrier then
            player:sendChatMessage("", 1, "Gates can't cross barrier!"%_t)
            return
        elseif not xyInsideRing then
            player:sendChatMessage("", 1, "Gates that cross barrier need to be built from the inner ring!"%_t)
            return
        end
    end

    local galaxy = Galaxy()
    if Config.ShouldOwnOriginSector then
        local owner = galaxy:getControllingFaction(x, y)
        if not owner or owner.index ~= buyer.index then
            player:sendChatMessage("", 1, "Only faction that controls the orign sector can found gates!"%_t)
            return
        end
    end

    if Config.ShouldOwnDestinationSector then
        local owner = galaxy:getControllingFaction(tx, ty)
        if not owner or owner.index ~= buyer.index then
            player:sendChatMessage("", 1, "Only faction that controls the destination sector can found gates!"%_t)
            return
        end
    end

    if sector:hasScript("activateteleport.lua") then
        player:sendChatMessage("", 1, "It's not possible to build gates from/to teleporter sectors!"%_t)
        return
    end

    if confirm and confirm == "confirm" then -- only check when player is ready to pay, otherwise people will use this to search for teleporter sectors
        local generatorScript = SectorSpecifics(tx, ty, Server().seed):getScript()
        if string.gsub(generatorScript, "^[^/]+/", "") == "teleporter" then
            player:sendChatMessage("", 1, "It's not possible to build gates from/to teleporter sectors!"%_t)
            return
        end
    end

    -- check if sector already has a gate that leads to that sector
    local gates = {sector:getEntitiesByScript("gate.lua")}
    Log.Debug("Player gatefounder - found, gates count: %i", #gates)
    local wormhole, wx, wy
    for i = 1, #gates do
        wormhole = WormHole(gates[i].index)
        wx, wy = wormhole:getTargetCoordinates()
        if wx == tx and wy == ty then
            player:sendChatMessage("", 1, "This sector already has gate that leads in \\s(%i:%i)!"%_t, tx, ty)
            return
        end
    end

    -- now calculate basic gate transfer fee
    local price = math.ceil(d * 30 * Balancing_GetSectorRichnessFactor((x + tx) / 2, (y + ty) / 2))
    Log.Debug("Base fee %i", price)
    -- and resulting price
    price = price * Config.BasePriceMultiplier
    Log.Debug("BasePriceMultiplier %f", price)
    price = price * math.pow(Config.SubsequentGatePriceMultiplier, gateCount)
    Log.Debug("SubsequentGatePriceMultiplier %f", price)
    price = math.pow(price, math.pow(Config.SubsequentGatePricePower, gateCount))
    Log.Debug("SubsequentGatePricePower %f", price)
    price = math.ceil(price)

    if not confirm or confirm ~= "confirm" then
        player:sendChatMessage("Server"%_t, 0, "Founding a gate from \\s(%i:%i) to \\s(%i:%i) will cost %i credits. Repeat command with additional 'confirm' in the end to found a gate."%_t, x, y, tx, ty, price)
    else -- try to found a gate
        local canPay, msg, args = buyer:canPay(price)
        if not canPay then
            player:sendChatMessage("", 1, msg, unpack(args))
            return
        end
        -- increment gate count and spawn a gate
        buyer:setValue("gates_founded", gateCount + 1)
        gates[#gates+1] = createGates(buyer, x, y, tx, ty)
        Placer.resolveIntersections(gates)
        -- try to spawn the gate back if target sector is loaded
        if Galaxy():sectorLoaded(tx, ty) then
            invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "gatefounder.lua", "foundGate", buyer.index, x, y)
        else -- save data so the gate back will be spawned once someone will enter that sector
            local gatesInfo = server:getValue("gate_founder_"..tx.."_"..ty)
            if gatesInfo then
                gatesInfo = gatesInfo..";"..buyer.index..","..x..","..y
            else
                gatesInfo = buyer.index..","..x..","..y
            end
            server:setValue("gate_founder_"..tx.."_"..ty, gatesInfo)
        end
        player:sendChatMessage("Server"%_t, 0, "Successfully founded a gate from \\s(%i:%i) to \\s(%i:%i)."%_t, x, y, tx, ty)
    end
    return true
end
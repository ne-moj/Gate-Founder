if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include("faction")
include("galaxy")
include("stringutility")
local PassageMap = include("passagemap")
local Placer = include("placer")
local PlanGenerator = include("plangenerator")
local StyleGenerator = include ("internal/stylegenerator.lua")
local SectorSpecifics = include("sectorspecifics")
local GateFounderInit = include("gatefounderinit")
local Config = GateFounderInit.Config
local Log = GateFounderInit.Log
if not Log then
    print("[GateFounder] WARNING: GateFounderInit.Log is nil! Using fallback logger.")
    Log = include("logger"):new("GateFounderFallback")
end

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
    
    local styleGenerator = StyleGenerator(faction.index)
    local c1 = styleGenerator.factionDetails.baseColor
    local c2 = ColorRGB(0.25, 0.25, 0.25)
    local c3 = styleGenerator.factionDetails.paintColor
    c1 = ColorRGB(c1.r, c1.g, c1.b)
    c3 = ColorRGB(c3.r, c3.g, c3.b)
    
    local plan = PlanGenerator.makeGatePlan(Seed(faction.index) + Server().seed, c1, c2, c3)
    local dir = vec3(tx - x, 0, ty - y)
    normalize_ip(dir)

    local position = MatrixLookUp(dir, vec3(0, 1, 0))
    position.pos = dir * 2000.0

    desc:setMovePlan(plan)
    desc.position = position
    desc.factionIndex = faction.index
    desc.invincible = true
    desc:setValue("gateFounder_origFaction", faction.index)
    desc:addScript("data/scripts/entity/gate.lua")

    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(tx, ty)
    wormhole.visible = false
    wormhole.visualSize = 50
    wormhole.passageSize = 50
    wormhole.oneWay = true

    return Sector():createEntity(desc, EntityArrivalType.Default)
end

function GateFounder.found(tx, ty, confirm, otherFaction, isCommand)
    Log:Debug("Player:GateFounder - found", tx, ty, confirm, isCommand)
    local server = Server()
    local player = Player()
    local isAdmin = server:hasAdminPrivileges(player)
    local isAdminCommand = isAdmin and confirm and confirm == "cheat"

    if isCommand and Config.UseStationFounderShip and not isAdminCommand then
        if isAdmin then
            player:sendChatMessage("", 1, "%1% Or use admin mode: /foundgate x y cheat"%_t, "Build a station founder ship on any shipyard in order to found gates!"%_t)
        else
            player:sendChatMessage("", 1, "Build a station founder ship on any shipyard in order to found gates!"%_t)
        end
        return
    end

    local buyer, _, player = getInteractingFaction(player.index, AlliancePrivilege.FoundStations)
    if isAdminCommand and otherFaction then
        local otherIndex = tonumber(otherFaction)
        if otherIndex then -- index
            buyer = Galaxy():findFaction(otherIndex)
            if buyer then
                Log:Debug('Found buyer with index %i - "%s"', otherIndex, tostring(buyer.name or ""))
            else
                player:sendChatMessage("", 1, "Couldn't find faction with specified index"%_t)
                return
            end
        else -- name
            buyer = nil
            for _, player in pairs({Server():getOnlinePlayers()}) do
                if player.name == otherFaction then
                    buyer = player
                    break
                end
            end
            if buyer then
                Log:Debug('Found buyer with name "%s" - %i', otherFaction, buyer.index)
            else
                player:sendChatMessage("", 1, "Couldn't find online player with that name"%_t)
                return
            end
        end
    end
    if not buyer then
        Log:Error("Player:GateFounder - buyer is nil")
        player:sendChatMessage("", 1, "An error has occured"%_t)
        return
    end

    if buyer.isPlayer and Config.AlliancesOnly and not isAdminCommand then
        player:sendChatMessage("", 1, "Only alliances can found gates!"%_t)
        return
    end

    local gateCount = buyer:getValue("gates_founded") or 0
    if gateCount >= Config.MaxGatesPerFaction and not isAdminCommand then
        player:sendChatMessage("", 1, "Reached the maximum amount of founded gates!"%_t)
        return
    end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    if x == tx and y == ty then       
        player:sendChatMessage("", 1, "Gates can't lead in the same sector!"%_t)
        return
    end

    if Config.NeedHelpFromDestinationSector and not isAdminCommand then
        local playerHelp = player:getNamesOfShipsInSector(tx, ty)
        local allianceHelp
        if player.index ~= buyer.index then
            allianceHelp = buyer:getNamesOfShipsInSector(tx, ty)
        end
        if not playerHelp and not allianceHelp then
            player:sendChatMessage("", 1, "You need to have a ship/station in the target sector to help you build a gate!"%_t)
            return
        end
    end

    if ((x == 0 and y == 0) or (tx == 0 and ty == 0)) and not isAdminCommand then
        player:sendChatMessage("", 1, "Gates can't lead to the center of the galaxy!"%_t)
        return
    end

    local d = distance(vec2(x, y), vec2(tx, ty))
    if d > Config.MaxDistance and not isAdminCommand then
        player:sendChatMessage("", 1, "Distance between gates is too big!"%_t)
        return
    end

    passageMap = PassageMap(server.seed)
    if not passageMap:passable(tx, ty) and not isAdminCommand then
        player:sendChatMessage("", 1, "Gates can't lead into rifts!"%_t)
        return
    end

    local xyInsideRing = passageMap:insideRing(x, y)
    if xyInsideRing ~= passageMap:insideRing(tx, ty) and not isAdminCommand then
        if not Config.AllowToPassBarrier then
            player:sendChatMessage("", 1, "Gates can't cross barrier!"%_t)
            return
        elseif not xyInsideRing then
            player:sendChatMessage("", 1, "Gates that cross barrier need to be built from the inner ring!"%_t)
            return
        end
    end

    local galaxy = Galaxy()
    if Config.ShouldOwnOriginSector and not isAdminCommand then
        local owner = galaxy:getControllingFaction(x, y)
        if not owner or owner.index ~= buyer.index then
            player:sendChatMessage("", 1, "Only faction that controls the orign sector can found gates!"%_t)
            return
        end
    end

    if Config.ShouldOwnDestinationSector and not isAdminCommand then
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

    if confirm and (confirm == "confirm" or isAdminCommand) then -- only check when player is ready to pay, otherwise people will use this to search for teleporter sectors
        local generatorScript = SectorSpecifics(tx, ty, Server().seed):getScript()
        if string.gsub(generatorScript, "^[^/]+/", "") == "teleporter" then
            player:sendChatMessage("", 1, "It's not possible to build gates from/to teleporter sectors!"%_t)
            return
        end
    end

    -- check if sector already has a gate that leads to that sector
    local gates = {sector:getEntitiesByScript("gate.lua")}
    Log:Debug("Player gatefounder - found, gates count: %i", #gates)
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
    Log:Debug("Base fee %i", price)
    -- and resulting price
    price = price * Config.BasePriceMultiplier
    Log:Debug("BasePriceMultiplier %f", price)
    price = price * math.pow(Config.SubsequentGatePriceMultiplier, gateCount)
    Log:Debug("SubsequentGatePriceMultiplier %f", price)
    price = math.pow(price, math.pow(Config.SubsequentGatePricePower, gateCount))
    Log:Debug("SubsequentGatePricePower %f", price)
    price = math.ceil(price)

    if not confirm or (confirm ~= "confirm" and not isAdminCommand) then
        player:sendChatMessage("Server"%_t, 0, "Founding a gate from \\s(%i:%i) to \\s(%i:%i) will cost %i credits. Repeat command with additional 'confirm' in the end to found a gate."%_t, x, y, tx, ty, price)
    else -- try to found a gate
        if not isAdminCommand then
            local canPay, msg, args = buyer:canPay(price)
            if not canPay then
                player:sendChatMessage("", 1, msg, unpack(args))
                return
            end
            buyer:pay("Paid %1% Credits to found a gate."%_T, price)
        end
        -- increment gate count and spawn a gate
        buyer:setValue("gates_founded", gateCount + 1)
        gates[#gates+1] = createGates(buyer, x, y, tx, ty)
        
        -- GateRegistry Integration
        local GateRegistry = include("gateregistry")
        if GateRegistry then
            GateRegistry.add(x, y, buyer.index, tx, ty)
        end

        Placer.resolveIntersections(gates)
        -- try to spawn the gate back if target sector is loaded
        if Galaxy():sectorLoaded(tx, ty) then
            invokeSectorFunction(tx, ty, true, "gatefounder.lua", "foundGate", buyer.index, x, y)
        else -- save data so the gate back will be spawned once someone will enter that sector
            local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 1, tx, ty, buyer.index, x, y)
            if status ~= 0 then
                Log:Error("gatefounder.lua - failed to mark gate for creation: %i", status)
            end
        end
        player:sendChatMessage("Server"%_t, 0, "Successfully founded a gate from \\s(%i:%i) to \\s(%i:%i)."%_t, x, y, tx, ty)
    end
    return true
end
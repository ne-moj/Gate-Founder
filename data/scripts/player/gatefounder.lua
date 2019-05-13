if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"
include("faction")
include("galaxy")
include("stringutility")
local PassageMap = include("passagemap")
local Placer = include("placer")
local PlanGenerator = include("plangenerator")
local Azimuth = include("azimuthlib-basic")

-- namespace GateFounder
GateFounder = {}

local config, Log

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

function GateFounder.initialize()
    -- load config
    local configOptions = {
      _version = { default = "1.0", comment = "Config version. Don't touch." },
      LogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
      OwnedSectorsOnly = { default = true, comment = "If true, faction can spawn the gate only if it owns sector." },
      MaxDistance = { default = 15, min = 1, format = "floor", comment = "Max gate distance." },
      BasePriceMultiplier = { default = 15000, min = 1, comment = "Affects basic gate price." },
      MaxGatesPerFaction = { default = 5, min = 0, format = "floor", comment = "How many gates can each faction found." },
      AlliancesOnly = { default = false, comment = "If true, only alliances wiil be able to found gates." },
      SubsequentGatePriceMultiplier = { default = 1.1, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula." },
      SubsequentGatePricePower = { default = 1.01, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula." },
      AllowToPassBarrier = { default = false, comment = "If true, players will be able to build gates through barrier." }
    }
    local isModified
    config, isModified = Azimuth.loadConfig("GateFounder", configOptions)
    if isModified then
        Azimuth.saveConfig("GateFounder", config, configOptions)
    end
    Log = Azimuth.logs("GateFounder", config.LogLevel)
end

function GateFounder.found(tx, ty, confirm)
    local buyer, _, player = getInteractingFaction(Player().index, AlliancePrivilege.FoundStations)
    if not buyer then return end
    if buyer.isPlayer and config.AlliancesOnly then
        player:sendChatMessage("", 1, "Only alliances can found gates!"%_t)
        return
    end
    local gateCount = buyer:getValue("gates_founded") or 0
    if gateCount >= config.MaxGatesPerFaction then
        player:sendChatMessage("", 1, "Reached the maximum amount of founded gates!"%_t)
        return
    end
    local x, y = Sector():getCoordinates()
    if x == tx and y == ty then
        player:sendChatMessage("", 1, "You can't found a gate that leads in the same sector!"%_t)
        return
    end
    local d = distance(vec2(x, y), vec2(tx, ty))
    if d > config.MaxDistance then
        player:sendChatMessage("", 1, "Distance between gates is too big!"%_t)
        return
    end
    passageMap = PassageMap(Server().seed)
    if not passageMap:passable(tx, ty) then
        player:sendChatMessage("", 1, "Gates can't lead into rifts!"%_t)
        return
    end
    if passageMap:insideRing(x, y) ~= passageMap:insideRing(tx, ty) then
        if not config.AllowToPassBarrier then
            player:sendChatMessage("", 1, "Gates can't cross barrier!"%_t)
            return
        elseif not passageMap:insideRing(x, y) then
            player:sendChatMessage("", 1, "Gates that cross barrier need to be built from the inner ring!"%_t)
            return
        end
    end
    if config.OwnedSectorsOnly then
        local owner = Galaxy():getControllingFaction(x, y)
        if not owner or owner.index ~= buyer.index then
            player:sendChatMessage("", 1, "Only faction that controls the sector can found gates!"%_t)
            return
        end
    end
    -- check if sector already has a gate that leads to that sector
    local gates = {Sector():getEntitiesByScript("data/scripts/entity/gate.lua")}
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
    price = price * config.BasePriceMultiplier
    Log.Debug("BasePriceMultiplier %f", price)
    price = price * math.pow(config.SubsequentGatePriceMultiplier, gateCount)
    Log.Debug("SubsequentGatePriceMultiplier %f", price)
    price = math.pow(price, math.pow(config.SubsequentGatePricePower, gateCount))
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
            invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "data/scripts/sector/gatefounder.lua", "foundGate", buyer.index, x, y)
        else -- save data so the gate back will be spawned once someone will enter that sector
            local gatesInfo = Server():getValue("gate_founder_"..tx.."_"..ty)
            if gatesInfo then
                gatesInfo = gatesInfo..";"..buyer.index..","..x..","..y
            else
                gatesInfo = buyer.index..","..x..","..y
            end
            Server():setValue("gate_founder_"..tx.."_"..ty, gatesInfo)
        end
        player:sendChatMessage("Server"%_t, 0, "Successfully founded a gate from \\s(%i:%i) to \\s(%i:%i)."%_t, x, y, tx, ty)
    end
end
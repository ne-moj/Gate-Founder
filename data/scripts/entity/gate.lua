-- Override
function Gate.canTransfer(index)
    local ship = Sector():getEntity(index)
    local faction = Faction(ship.factionIndex)

    -- gates can't travel through gates
    if ship.hasComponent and ship:hasComponent(ComponentType.WormHole) then
        return 0
    end

    -- unowned objects and AI factions can always pass
    if not faction or faction.isAIFaction then
        return 1
    end

    -- when a craft has no pilot then the owner faction must pay
    local pilotIndex = ship:getPilotIndices()
    local buyer, player
    if pilotIndex then
        buyer, _, player = getInteractingFaction(pilotIndex, AlliancePrivilege.SpendResources)

        if not buyer then return 0 end
    else
        buyer = faction
        if faction.isPlayer then
            player = Player(faction.index)
        end
    end

    local fee = math.ceil(base * Gate.factor(buyer, Faction()))
    local canPay, msg, args = buyer:canPay(fee)

    if not canPay then
        if player then
            player:sendChatMessage("Gate Control"%_t, 1, msg, unpack(args))
        end

        return 0
    end

    if player then
        player:sendChatMessage("Gate Control"%_t, 3, "'%s' - paid %i credits gate passage fee."%_t, ship.name or "", fee)
    end

    buyer:pay((ship.name or "") .. " - "..("Paid %1% credits gate passage fee."%_t), fee)

    return 1
end

-- New
function Gate.interactionPossible(playerIndex, option)
    if option == 0 and not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
        return false
    end
    if option == 1 and not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return false
    end
    return true
end

function Gate.initUI()
    ScriptUI():registerInteraction("Toggle"%_t, "onToggle");
    ScriptUI():registerInteraction("Destroy"%_t, "onDestroy");
end

function Gate.onToggle()
    if onClient() then
        invokeServerFunction("onToggle")
        return
    end
    local entity = Entity()
    local faction, craft, player = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
    if not faction then return end
    local x, y = Sector():getCoordinates()
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "data/scripts/sector/gatefounder.lua", "toggleGate", faction.index, x, y, not wormhole.enabled)
    else
        local gatesInfo = Server():getValue("gate_toggler_"..tx.."_"..ty)
        if gatesInfo then
            gatesInfo = gatesInfo..";"..faction.index..","..x..","..y..","..(wormhole.enabled and "0" or "1")
        else
            gatesInfo = faction.index..","..x..","..y..","..(wormhole.enabled and "0" or "1")
        end
        Server():setValue("gate_toggler_"..tx.."_"..ty, gatesInfo)
    end
    wormhole.enabled = not wormhole.enabled
    Gate.updateTooltip(nil, true) -- Integration: Compass-like Gate Pixel Icons
end
callable(Gate, "onToggle")

function Gate.onDestroy()
    if onClient() then
        invokeServerFunction("onDestroy")
        return
    end
    local entity = Entity()
    local faction, craft, player = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
    if not faction then return end
    local x, y = Sector():getCoordinates()
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "data/scripts/sector/gatefounder.lua", "destroyGate", faction.index, x, y)
    else
        local gatesInfo = Server():getValue("gate_destroyer_"..tx.."_"..ty)
        if gatesInfo then
            gatesInfo = gatesInfo..";"..faction.index..","..x..","..y
        else
            gatesInfo = faction.index..","..x..","..y
        end
        Server():setValue("gate_destroyer_"..tx.."_"..ty, gatesInfo)
    end
    Sector():deleteEntity(entity)
    local gateCount = faction:getValue("gates_founded") or 0
    if gateCount > 0 then
        faction:setValue("gates_founded", gateCount - 1)
    end
end
callable(Gate, "onDestroy")
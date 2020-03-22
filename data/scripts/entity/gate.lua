local Azimuth, GateFounderConfig, GateFounderLog -- server
local gateFounder_canTransfer -- extended server functions
local gateFounder_interactionPossible, gateFounder_initUI -- extended client functions


if onClient() then


gateFounder_interactionPossible = Gate.interactionPossible
function Gate.interactionPossible(playerIndex, option)
    local canToggle = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    local canDelete = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)

    if option == 0 then
        return canToggle
    end
    if option == 1 then
        return canDelete
    end
    if not canToggle and not canDelete then
        if gateFounder_interactionPossible then
            return gateFounder_interactionPossible(playerIndex, option)
        end
        return false
    end
    return true
end

gateFounder_initUI = Gate.initUI
function Gate.initUI(...)
    if gateFounder_initUI then gateFounder_initUI(...) end
    
    local scriptUI = ScriptUI()
    scriptUI:registerInteraction("Close"%_t, "")
    scriptUI:registerInteraction("Toggle"%_t, "gateFounder_onToggle")
    scriptUI:registerInteraction("Destroy"%_t, "gateFounder_onDestroy")
end


else -- onServer


Azimuth, GateFounderConfig, GateFounderLog = unpack(include("gatefounderinit"))

if GateFounderConfig.ForbidGatesForEnemies then

gateFounder_canTransfer = Gate.canTransfer
function Gate.canTransfer(index)
    local ship = Sector():getEntity(index)
    local faction = Faction(ship.factionIndex)
    local selfFaction = Faction()

    if selfFaction and faction and not faction.isAIFaction and selfFaction:getRelationStatus(ship.factionIndex) == RelationStatus.War then
        local pilotIndex = ship:getPilotIndices()
        if pilotIndex then
            local player = Player(pilotIndex)
            if player then
                local msgRed = "<Gate Control> "%_t.."%1%"
                player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, "Access denied, we will not allow our enemies to pass through our gate!"%_t)
            end
        end
        return 0
    end

    return gateFounder_canTransfer(index)
end

end

function Gate.isTransferrable() -- gates shouldn't be transferrable
    return false
end

function Gate.updateFaction() -- overridden
    local entity = Entity()
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    local targetFaction = Galaxy():getControllingFaction(tx, ty)

    if targetFaction then
        local origOwner = entity:getValue("gateFounder_origFaction")
        if origOwner and origOwner ~= targetFaction.index and not GateFounderConfig.BuiltGatesCanBeCaptured then return end

        entity.factionIndex = targetFaction.index
        Gate.updateTooltip()
    end
end


end


function Gate.gateFounder_onToggle()
    if onClient() then
        invokeServerFunction("gateFounder_onToggle")
        return
    end
    local entity = Entity()
    local faction, craft, player = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
    if not faction then return end
    -- check sector owner
    local x, y = Sector():getCoordinates()
    local targetFaction = Galaxy():getControllingFaction(x, y)
    if targetFaction and faction.index ~= targetFaction.index and faction:getRelationStatus(targetFaction.index) ~= RelationStatus.Allies then
        if player then
            local msgRed = "<Gate Control> "%_t.."%1%"
            player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, "Can't toggle the gate, this sector is being controlled by a non-ally faction!"%_t)
        end
        return
    end
    -- toggle
    local wormhole = Entity():getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "toggleGate", faction.index, x, y, not wormhole.enabled)
    else
        local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 3, tx, ty, faction.index, x, y, not wormhole.enabled)
        if status ~= 0 then
            GateFounderLog:Error("gate.lua - failed to mark gate for toggle: %i", status)
        end
    end
    wormhole.enabled = not wormhole.enabled
    callingPlayer = nil -- we need 'updateTooltip' to broadcast the changes
    Gate.updateTooltip(nil, true) -- Integration: Compass-like Gate Pixel Icons
end
callable(Gate, "gateFounder_onToggle")

function Gate.gateFounder_onDestroy()
    if onClient() then
        invokeServerFunction("gateFounder_onDestroy")
        return
    end
    local entity = Entity()
    local faction, craft, player = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
    if not faction then return end
    local x, y = Sector():getCoordinates()
    -- check sector owner
    local targetFaction = Galaxy():getControllingFaction(x, y)
    if targetFaction and faction.index ~= targetFaction.index and faction:getRelationStatus(targetFaction.index) ~= RelationStatus.Allies then
        if player then
            local msgRed = "<Gate Control> "%_t.."%1%"
            player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, "Can't destroy the gate, this sector is being controlled by a non-ally faction!"%_t)
        end
        return
    end
    local originalOwner = entity:getValue("gateFounder_origFaction")
    if originalOwner and originalOwner ~= faction.index and not GateFounderConfig.CapturedBuiltGatesCanBeDestroyed then
        if player then
            local msgRed = "<Gate Control> "%_t.."%1%"
            player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, "Only original builder of the gate can destroy it!"%_t)
        end
        return
    end
    if not originalOwner and not GateFounderConfig.CapturedNPCGatesCanBeDestroyed then
        if player then
            local msgRed = "<Gate Control> "%_t.."%1%"
            player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, "This gate was built by an old faction. You have no idea how to destroy it."%_t)
        end
        return
    end
    -- destroy
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "destroyGate", faction.index, x, y)
    else
        local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 4, tx, ty, faction.index, x, y)
        if status ~= 0 then
            GateFounderLog:Error("gate.lua - failed to mark gate for destruction: %i", status)
        end
    end
    -- return points
    local owner
    if originalOwner then
        owner = Faction(originalOwner)
    end
    if owner then -- gate destruction should reduce owner gate counter
        local gateCount = owner:getValue("gates_founded") or 0
        if gateCount > 0 then
            owner:setValue("gates_founded", gateCount - 1)
        end
    end

    Sector():deleteEntity(entity)
end
callable(Gate, "gateFounder_onDestroy")
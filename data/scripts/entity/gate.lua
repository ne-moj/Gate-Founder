local Azimuth, GateFounderConfig, GateFounderLog, gateFounder_isLocked -- server
local gateFounder_canTransfer, gateFounder_secure, gateFounder_restore -- extended server functions
local gateFounder_interactionPossible, gateFounder_initUI -- extended client functions


if onClient() then


gateFounder_interactionPossible = Gate.interactionPossible
function Gate.interactionPossible(playerIndex, option)
    if option == 0 then
        return true
    end
    if option then
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

    ScriptUI():registerInteraction("Manage gates"%_t, "gateFounder_showManageDialog")
end

function Gate.gateFounder_onDestroyDialog()
    ScriptUI():interactShowDialog({
      text = "This will destroy this pair of gates. Are you sure?"%_t,
      answers = {
        { answer = "Cancel"%_t },
        { answer = "Destroy"%_t, onSelect = "gateFounder_onDestroy" },
      }
    })
end


else -- onServer


Azimuth, GateFounderConfig, GateFounderLog = unpack(include("gatefounderinit"))

gateFounder_canTransfer = Gate.canTransfer
function Gate.canTransfer(index)
    if not Gate.getPower() then -- don't allow to pass if gate is toggled off
        return false
    end

    if GateFounderConfig.ForbidGatesForEnemies then
        local ship = Sector():getEntity(index)
        local faction = Faction(ship.factionIndex)
        local selfFaction = Faction()

        if selfFaction and faction and not faction.isAIFaction and selfFaction:getRelationStatus(ship.factionIndex) == RelationStatus.War then
            local pilotIndex = ship:getPilotIndices()
            if pilotIndex then
                local player = Player(pilotIndex)
                if player then
                    player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, "<%1%> Access denied, we will not allow our enemies to pass through our gate!"%_t, "Gate Control"%_t)
                end
            end
            return 0
        end
    end

    return gateFounder_canTransfer(index)
end

function Gate.isTransferrable() -- gates shouldn't be transferrable
    return false
end

function Gate.updateFaction() -- overridden
    local entity = Entity()
    local wormhole = WormHole()
    local tx, ty = wormhole:getTargetCoordinates()
    local targetFaction = Galaxy():getControllingFaction(tx, ty)

    if targetFaction then
        local origOwner = entity:getValue("gateFounder_origFaction")
        if origOwner and origOwner ~= targetFaction.index and not GateFounderConfig.BuiltGatesCanBeCaptured then return end

        if GateFounderLog.isDebug then
            local oldIndex = entity.factionIndex
            if not oldIndex or oldIndex ~= targetFaction.index then
                GateFounderLog:Debug("gate.lua, updateFaction - now faction %s owns the gate", string.format("%.f", targetFaction.index))
            end
        end
        entity.factionIndex = targetFaction.index
        Gate.updateTooltip()
        
        if not gateFounder_isLocked and targetFaction.isAIFaction and not Gate.getPower() then -- if AI controls both gates, they will toggle them on
            local x, y = Sector():getCoordinates()
            local curFaction = Galaxy():getControllingFaction(x, y)
            if curFaction and curFaction.index == targetFaction.index then
                if Galaxy():sectorLoaded(tx, ty) then
                    invokeSectorFunction(tx, ty, true, "gatefounder.lua", "toggleGate", targetFaction.index, x, y, true)
                else
                    local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 3, tx, ty, targetFaction.index, x, y, true)
                    if status ~= 0 then
                        GateFounderLog:Error("gate.lua, updateFaction - failed to mark gate for toggle: %i", status)
                    end
                end
                Gate.setPower(true)
                GateFounderLog:Debug("gate.lua, updateFaction - AI faction toggled gates on")
            end
        end
    end
end

gateFounder_secure = Gate.secure
function Gate.secure()
    local data = {}
    if gateFounder_secure then
        data = gateFounder_secure()
    end
    data.locked = gateFounder_isLocked
    return data
end

gateFounder_restore = Gate.restore
function Gate.restore(data)
    gateFounder_isLocked = data.locked
    if gateFounder_restore then
        gateFounder_restore(data)
    end
end

function Gate.gateFounder_setLock(value)
    gateFounder_isLocked = value
end


end


function Gate.gateFounder_showManageDialog(entityIndex, isAdmin, isLocked)
    if onClient() then
        if isAdmin == nil then -- get player admin rights and gate lock
            invokeServerFunction("gateFounder_showManageDialog")
        else -- got response
            local canToggle = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
            local canDestroy = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
            if not isAdmin and not canToggle and not canDestroy then
                ScriptUI():interactShowDialog({ text = "You don't have permissions to manage this pair of gates."%_t })
            else
                local text = ""
                if isLocked then
                    text = "[The gates were locked by an admin]\n"%_t
                end
                text = text.."Choose an action:"%_t
                local answers = {
                  { answer = "Cancel"%_t }
                }
                if (not isLocked and canToggle) or isAdmin then
                    text = text.."\n* Toggling gates off will prevent them from transporting ships"%_t
                    local toggle = Gate.getPower() and "Toggle off"%_t or "Toggle on"%_t
                    answers[#answers+1] = {
                      answer = canToggle and toggle or string.format("%s (%s)", toggle, "admin"%_t),
                      onSelect = "gateFounder_onToggle"
                    }
                end
                if (not isLocked and canDestroy) or isAdmin then
                    text = text.."\n* Destroying gates will delete them but won't return resources"%_t
                    answers[#answers+1] = {
                      answer = canDestroy and "Destroy"%_t or string.format("%s (%s)", "Destroy"%_t, "admin"%_t),
                      onSelect = "gateFounder_onDestroyDialog"
                    }
                end
                if isAdmin then
                    text = text.."\n* Locking gates will prevent them from being toggled or destroyed by owners"%_t
                    local lock = isLocked and "Unlock"%_t or "Lock"%_t
                    answers[#answers+1] = {
                      answer = string.format("%s (%s)", lock, "admin"%_t),
                      onSelect = "gateFounder_onLock"
                    }
                end
                ScriptUI():interactShowDialog({
                  text = text,
                  answers = answers
                })
            end
        end
    else
        local player = Player(callingPlayer)
        invokeClientFunction(player, "gateFounder_showManageDialog", nil, Server():hasAdminPrivileges(player), gateFounder_isLocked)
    end
end
callable(Gate, "gateFounder_showManageDialog")

function Gate.gateFounder_onToggle()
    if onClient() then
        invokeServerFunction("gateFounder_onToggle")
        return
    end
    local player = Player(callingPlayer)
    local isAdmin = Server():hasAdminPrivileges(player)
    local faction
    if isAdmin then
        faction = Faction()
    else
        faction = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    end
    if not faction then
        player:sendChatMessage("Gate Control"%_t, 1, "An error has occured"%_t)
        return
    end
    if not isAdmin and gateFounder_isLocked then return end
    local x, y = Sector():getCoordinates()
    -- check sector owner
    if not isAdmin then
        local targetFaction = Galaxy():getControllingFaction(x, y)
        if targetFaction and faction.index ~= targetFaction.index and faction:getRelationStatus(targetFaction.index) ~= RelationStatus.Allies then
            if player then
                player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, "Can't toggle the gate, this sector is being controlled by a non-ally faction!"%_t)
            end
            return
        end
    end
    -- toggle
    local wormhole = WormHole()
    local tx, ty = wormhole:getTargetCoordinates()
    local newPower = not Gate.getPower()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "toggleGate", faction.index, x, y, newPower)
    else
        local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 3, tx, ty, faction.index, x, y, newPower)
        if status ~= 0 then
            GateFounderLog:Error("gate.lua - failed to mark gate for toggle: %i", status)
        end
    end
    Gate.setPower(newPower)
end
callable(Gate, "gateFounder_onToggle")

function Gate.gateFounder_onDestroy()
    if onClient() then
        invokeServerFunction("gateFounder_onDestroy")
        return
    end
    local entity = Entity()
    local player = Player(callingPlayer)
    local isAdmin = Server():hasAdminPrivileges(player)
    local faction
    if isAdmin then
        faction = Faction()
    else
        faction = checkEntityInteractionPermissions(entity, AlliancePrivilege.FoundStations)
    end
    if not faction then
        player:sendChatMessage("Gate Control"%_t, 1, "An error has occured"%_t)
        return
    end
    if not isAdmin and gateFounder_isLocked then return end
    local x, y = Sector():getCoordinates()
    -- check sector owner
    if not isAdmin then
        local targetFaction = Galaxy():getControllingFaction(x, y)
        if targetFaction and faction.index ~= targetFaction.index and faction:getRelationStatus(targetFaction.index) ~= RelationStatus.Allies then
            if player then
                player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, "Can't destroy the gate, this sector is being controlled by a non-ally faction!"%_t)
            end
            return
        end
    end
    local originalOwner = entity:getValue("gateFounder_origFaction")
    if not isAdmin then
        if originalOwner and originalOwner ~= faction.index and not GateFounderConfig.CapturedBuiltGatesCanBeDestroyed then
            if player then
                player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, "Only original builder of the gate can destroy it!"%_t)
            end
            return
        end
        if not originalOwner and not GateFounderConfig.CapturedNPCGatesCanBeDestroyed then
            if player then
                player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, "This gate was built by an old faction. You have no idea how to destroy it."%_t)
            end
            return
        end
    end
    -- destroy
    local wormhole = WormHole()
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
        owner = Galaxy():findFaction(originalOwner)
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

function Gate.gateFounder_onLock()
    if onClient() then
        invokeServerFunction("gateFounder_onLock")
        return
    end
    local player = Player(callingPlayer)
    local isAdmin = Server():hasAdminPrivileges(player)
    if not isAdmin then return end
    local x, y = Sector():getCoordinates()
    local wormhole = WormHole()
    local tx, ty = wormhole:getTargetCoordinates()
    local newLocked = not gateFounder_isLocked
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "lockGate", 0, x, y, newLocked)
    else
        local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 5, tx, ty, 0, x, y, newLocked)
        if status ~= 0 then
            GateFounderLog:Error("gate.lua - failed to mark gate for locking: %i", status)
        end
    end
    if newLocked then
        player:sendChatMessage("Gate Control"%_t, 0, "Gates locked"%_t)
    else
        player:sendChatMessage("Gate Control"%_t, 0, "Gates unlocked"%_t)
    end
    gateFounder_isLocked = newLocked
end
callable(Gate, "gateFounder_onLock")
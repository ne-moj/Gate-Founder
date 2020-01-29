local gateFounder_canTransfer_post0_26 -- extended functions

gateFounder_canTransfer_post0_26 = Gate.canTransfer
function Gate.canTransfer(index)
    local ship = Sector():getEntity(index)
    -- gates can't travel through gates
    if ship.hasComponent and ship:hasComponent(ComponentType.WormHole) then
        return 0
    end

    return gateFounder_canTransfer_post0_26(index)
end

-- New
local gateFounder_interactionPossible = Gate.interactionPossible
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

local gateFounder_initUI = Gate.initUI
function Gate.initUI(...)
    if gateFounder_initUI then gateFounder_initUI(...) end
    
    local scriptUI = ScriptUI()
    scriptUI:registerInteraction("Close"%_t, "")
    scriptUI:registerInteraction("Toggle"%_t, "gateFounder_onToggle")
    scriptUI:registerInteraction("Destroy"%_t, "gateFounder_onDestroy")
end

function Gate.gateFounder_onToggle()
    if onClient() then
        invokeServerFunction("gateFounder_onToggle")
        return
    end
    local entity = Entity()
    local faction, craft, player = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
    if not faction then return end
    local x, y = Sector():getCoordinates()
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "toggleGate", faction.index, x, y, not wormhole.enabled)
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
    local wormhole = entity:getWormholeComponent()
    local tx, ty = wormhole:getTargetCoordinates()
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "destroyGate", faction.index, x, y)
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
callable(Gate, "gateFounder_onDestroy")
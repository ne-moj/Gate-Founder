function ClaimFromAlliance.claim()
    if not ClaimFromAlliance.interactionPossible(callingPlayer) then return end
    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local entity = Entity()
    entity.factionIndex = faction.index
    
    if entity.hasScript and entity:hasScript("data/scripts/entity/gate.lua") then -- claim both gates at once
        local x, y = Sector():getCoordinates()
        local wormhole = entity:getWormholeComponent()
        local tx, ty = wormhole:getTargetCoordinates()
        if Galaxy():sectorLoaded(tx, ty) then
            invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "data/scripts/sector/gatefounder.lua", "claimGate", faction.index, x, y)
        else
            local gatesInfo = Server():getValue("gate_claim_"..tx.."_"..ty)
            if gatesInfo then
                gatesInfo = gatesInfo..";"..faction.index..","..x..","..y..","..(wormhole.enabled and "0" or "1")
            else
                gatesInfo = faction.index..","..x..","..y..","..(wormhole.enabled and "0" or "1")
            end
            Server():setValue("gate_claim_"..tx.."_"..ty, gatesInfo)
        end
    end

    terminate()
end

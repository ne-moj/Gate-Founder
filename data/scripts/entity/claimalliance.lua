local Azimuth, GateFounderConfig -- serverside
local gatefounder_claim -- extended functions

if onServer() then


Azimuth, GateFounderConfig = unpack(include("gatefounderinit"))

gatefounder_claim = ClaimFromAlliance.claim
function ClaimFromAlliance.claim()
    if not ClaimFromAlliance.interactionPossible(callingPlayer) then return end
    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local entity = Entity()

    if entity.hasScript and entity:hasScript("gate.lua") then -- claim both gates at once
        if faction.isPlayer and GateFounderConfig.AlliancesOnly then
            player:sendChatMessage("", 1, "Only alliances can claim gates!"%_t)
            return
        end
        local gateCount = faction:getValue("gates_founded") or 0
        if gateCount >= GateFounderConfig.MaxGatesPerFaction then
            player:sendChatMessage("", 1, "Reached the maximum amount of founded gates!"%_t)
            return
        end
        faction:setValue("gates_founded", gateCount + 1)
    
        local x, y = Sector():getCoordinates()
        local wormhole = entity:getWormholeComponent()
        local tx, ty = wormhole:getTargetCoordinates()
        if Galaxy():sectorLoaded(tx, ty) then
            invokeRemoteSectorFunction(tx, ty, "Couldn't load the sector", "gatefounder.lua", "claimGate", faction.index, x, y)
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

    gatefounder_claim() -- resume vanilla
end


end
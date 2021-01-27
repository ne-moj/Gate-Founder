local gateFounder_claim -- extended functions

if onServer() then

gateFounder_claim = ClaimFromAlliance.claim
function ClaimFromAlliance.claim()
    local entity = Entity()
    if entity.hasScript and entity:hasScript("gate.lua") then -- claim both gates at once
        if not ClaimFromAlliance.interactionPossible(callingPlayer) then return end
        local faction, ship, player = getInteractingFaction(callingPlayer)
        if not faction then return end

        local _, GateFounderConfig, GateFounderLog = unpack(include("gatefounderinit"))

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
        local wormhole = WormHole()
        local tx, ty = wormhole:getTargetCoordinates()
        if Galaxy():sectorLoaded(tx, ty) then
            invokeSectorFunction(tx, ty, true, "gatefounder.lua", "claimGate", faction.index, x, y)
        else -- mark gate to be claimed when the target sector will be loaded
            local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 2, tx, ty, faction.index, x, y)
            if status ~= 0 then
                GateFounderLog:Error("claimalliance.lua - failed to mark gate for claiming: %i", status)
            end
        end
    end

    gateFounder_claim() -- resume vanilla
end


end
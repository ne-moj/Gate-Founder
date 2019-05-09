local Azimuth = include("azimuthlib-basic")
local GateFounderConfig

local gatefounder_initialize = ClaimFromAlliance.initialize
function ClaimFromAlliance.initialize()
    -- load config
    local configOptions = {
      MaxGatesPerFaction = { default = 5, min = 0, format = "floor", comment = "How many gates can each faction found." }
    }
    GateFounderConfig = Azimuth.loadConfig("GateFounder", configOptions)

    if gatefounder_initialize then gatefounder_initialize() end -- in case other mod will define it
end

local gatefounder_claim = ClaimFromAlliance.claim
function ClaimFromAlliance.claim()
    if not ClaimFromAlliance.interactionPossible(callingPlayer) then return end
    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local entity = Entity()

    if entity.hasScript and entity:hasScript("data/scripts/entity/gate.lua") then -- claim both gates at once
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

    gatefounder_claim() -- resume vanilla
end

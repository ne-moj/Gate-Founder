--[[
    Gate Finder v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This module is responsible for finding and managing gate entities within the game world.
      It handles the detection of existing gates, checking for teleporter sectors, and finding buyer factions.
    
    FEATURES:
       - Checks for the existence of gates in the current sector.
       - Determines if a target sector is a teleporter sector (requires loading generator).
       - Finds the buyer faction based on interaction (player or alliance).
       - Handles admin overrides for buyer selection.
    
    USAGE:
        To check if a gate exists in the current sector, call the `GateFinder.hasGateTo` function:
        `local exists = GateFinder.hasGateTo(tx, ty)`
        
        - `tx, ty`: The X and Y coordinates of the target sector.
        
        The function returns a boolean indicating whether a gate exists in the target sector.
--]]

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

include("faction")

local GateConfig = include("gate/config")
local Log = include("logger"):new("GateFinder")

local GateFinder = {}

--[[
    Find the buyer faction based on interaction
    
    @param playerIndex number
    @param otherFactionNameOrIndex string|nil - Optional override (for admins)
    @return Faction|nil, string|nil - Buyer faction and error message
--]]
function GateFinder.findBuyer(playerIndex, otherFactionNameOrIndex)
    Log:RunFunc("GateFinder:findBuyer(%s, %s)", playerIndex, otherFactionNameOrIndex)
    local player = Player(playerIndex)
    if not player then return nil, "Player not found" end

    -- Default: interacting faction (Player or Alliance)
    local buyer, _, _ = getInteractingFaction(playerIndex, AlliancePrivilege.FoundStations)

    -- Override if specified (Admin Command)
    if otherFactionNameOrIndex then
        local otherIndex = tonumber(otherFactionNameOrIndex)
        if otherIndex then
            buyer = Galaxy():findFaction(otherIndex)
            if not buyer then
                 return nil, "Couldn't find faction with specified index"%_t
            end
        else
            buyer = nil
            for _, p in pairs({Server():getOnlinePlayers()}) do
                if p.name == otherFactionNameOrIndex then
                    buyer = p
                    break
                end
            end
            if not buyer then
                return nil, "Couldn't find online player with that name"%_t
            end
        end
    end
    
    return buyer
end

--[[
    Check if a gate to target exists in current sector
    
    @param tx, ty number - Target coordinates
    @return boolean - True if gate exists
--]]
function GateFinder.hasGateTo(tx, ty)
    Log:RunFunc("GateFinder:hasGateTo(%s, %s)", tx, ty)
    local sector = Sector()
    local gates = {sector:getEntitiesByScript("gate.lua")}
    
    for _, gate in pairs(gates) do
        local wormhole = WormHole(gate.index)
        if wormhole then
            local wx, wy = wormhole:getTargetCoordinates()
            if wx == tx and wy == ty then
                return true
            end
        end
    end
    return false
end

--[[
    Check for Teleporter script in target sector (requires loading generator)
    
    @param tx, ty number
    @param seed Seed
    @return boolean - True if target is teleporter
--]]
function GateFinder.isTeleporterSector(tx, ty, seed)
    Log:RunFunc("GateFinder:isTeleporterSector(%s, %s, %s)", tx, ty, seed)
    local SectorSpecifics = include("sectorspecifics")
    -- We can check generator script without loading sector fully
    local generatorScript = SectorSpecifics(tx, ty, seed):getScript()
    return string.gsub(generatorScript, "^[^/]+/", "") == "teleporter"
end

return GateFinder

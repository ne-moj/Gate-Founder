--[[
    Gate Validator v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This library provides functionality to validate gate configurations and passage rules,
      ensuring consistency and correctness within the game's gate system.
    
    FEATURES:
       - Integrates with GateConfig for loading and accessing gate-specific settings.
       - Utilizes PassageMap for validating passage conditions and transitions.
       - Offers methods to check the validity of gate states, transitions, and associated data.
    
    USAGE:
        local GateValidator = include("gate/validator")
        -- Assuming 'gateData' is a table representing a gate's configuration
        if GateValidator.isValidGate(gateData) then
            print("Gate configuration is valid.")
        else
            print("Gate configuration is invalid.")
        end
        -- Specific validation functions would be added to the GateValidator table.
--]]

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local GateConfig = include("gate/config")
local PassageMap = include("passagemap")

local GateValidator = {}
local Log = include("logger"):new("GateValidator")

--[[
    Check if a connection is valid
    
    @param buyer Faction - The faction trying to found the gate
    @param x, y number - Origin coordinates
    @param tx, ty number - Target coordinates
    @param isAdmin boolean - If true, bypasses some checks
    @return boolean, string - validation status and error message
--]]
function GateValidator.canFoundGate(buyer, x, y, tx, ty, isAdmin)
    Log:RunFunc("GateValidator:canFoundGate(%s, %s, %s, %s, %s, %s)", buyer.index, x, y, tx, ty, isAdmin)
    -- Check 1: Same sector
    if x == tx and y == ty then
        return false, "Gates can't lead in the same sector!"%_t
    end

    -- Check 2: Center
    if ((x == 0 and y == 0) or (tx == 0 and ty == 0)) and not isAdmin then
        if not GateConfig:get("AllowGatesToCenter") then
            return false, "Gates can't lead to the center of the galaxy!"%_t
        end
    end

    -- Check 3: Distance
    local d = distance(vec2(x, y), vec2(tx, ty))
    local maxDist = GateConfig:get("MaxDistance")
    if d > maxDist and not isAdmin then
        return false, "Distance between gates is too big!"%_t
    end

    -- Check 4: Rifts and Barrier
    local seed = Server().seed
    local passageMap = PassageMap(seed)
    
    if not passageMap:passable(tx, ty) and not isAdmin then
        return false, "Gates can't lead into rifts!"%_t
    end

    local xyInsideRing = passageMap:insideRing(x, y)
    if xyInsideRing ~= passageMap:insideRing(tx, ty) and not isAdmin then
        if not GateConfig:get("AllowToPassBarrier") then
             return false, "Gates can't cross barrier!"%_t
        elseif not xyInsideRing then
             return false, "Gates that cross barrier need to be built from the inner ring!"%_t
        end
    end

    -- Check 5: Ownership (Origin)
    if GateConfig:get("ShouldOwnOriginSector") and not isAdmin then
        local owner = Galaxy():getControllingFaction(x, y)
        if not owner or owner.index ~= buyer.index then
            return false, "Only faction that controls the orign sector can found gates!"%_t
        end
    end

    -- Check 6: Ownership (Destination)
    if GateConfig:get("ShouldOwnDestinationSector") and not isAdmin then
        local owner = Galaxy():getControllingFaction(tx, ty)
        if not owner or owner.index ~= buyer.index then
            return false, "Only faction that controls the destination sector can found gates!"%_t
        end
    end
    
    -- Check 7: Teleporter logic
    -- NOTE: Sector():hasScript() only checks current loaded sector (Origin)
    if Sector():hasScript("activateteleport.lua") then
        return false, "It's not possible to build gates from/to teleporter sectors!"%_t
    end

    return true
end

--[[
    Check permissions for buyer
    
    @param buyer Faction
    @param isAdmin boolean
    @return boolean, string
--]]
function GateValidator.canBuyerFound(buyer, isAdmin)
    if buyer.isPlayer and GateConfig:get("AlliancesOnly") and not isAdmin then
        return false, "Only alliances can found gates!"%_t
    end
    
    local gateCount = buyer:getValue("gates_founded") or 0
    local maxGates = GateConfig:get("MaxGatesPerFaction")
    if gateCount >= maxGates and not isAdmin then
        return false, "Reached the maximum amount of founded gates!"%_t
    end
    
    return true
end

--[[
    Check if player has help in target sector
    
    @param player Player
    @param buyer Faction (Alliance or Player)
    @param tx, ty number
    @return boolean, string
--]]
function GateValidator.checkDestinationHelp(player, buyer, tx, ty)
    if not GateConfig:get("NeedHelpFromDestinationSector") then return true end
    
    local playerHelp = player:getNamesOfShipsInSector(tx, ty)
    local allianceHelp
    if player.index ~= buyer.index then
        allianceHelp = buyer:getNamesOfShipsInSector(tx, ty)
    end
    
    if not playerHelp and not allianceHelp then
        return false, "You need to have a ship/station in the target sector to help you build a gate!"%_t
    end
    return true
end

--[[
    Check money
    
    @param buyer Faction
    @param price number
    @return boolean, string, args
--]]
function GateValidator.canPay(buyer, price)
    return buyer:canPay(price)
end

return GateValidator

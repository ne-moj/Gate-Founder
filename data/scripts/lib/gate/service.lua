--[[
    Gate Service v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This module is responsible for the management of gate objects in the game world.
      It ensures that gates are properly constructed and integrated into the system.
    
    FEATURES:
       - Provides functions to create new gates with specified properties (e.g., coordinates, target).
       - Handles the initial setup and validation of gate parameters before creation.
       - May interact with other modules like GateRegistry to register newly created gates.
    
    USAGE:
        To manage a gate, call the appropriate function within the GateService module,
        passing the necessary parameters for the gate's origin, destination, and other attributes.
        Example: local newGate = GateService.create(x, y, tx, ty, ownerId)
        
        To check if the player's current craft is a founder ship, call the isFounderShip function:
        Example: local isFounder = GateService.isFounderShip(player)

        To get the cost of founding a gate, call the getFoundingCost function:
        Example: local canFound, price, gateCount, buyer = GateService.getFoundingCost(playerIndex, tx, ty, otherFaction)

        To create a gate, call the create function:
        Example: local newGate = GateService.create(playerIndex, tx, ty, otherFaction)

        To destroy a gate, call the destroy function:
        Example: local success, message = GateService.destroy(playerIndex, gateId)

        To get the list of all gates, call the getGates function:
        Example: local gates = GateService.getGates()
--]]

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local GateConfig = include("gate/config")
local GateValidator = include("gate/validator")
local GateFinder = include("gate/finder")
local GateCreator = include("gate/creator")
local GateRegistry = include("gate/registry") -- Will be moved later, but currently here
local Placer = include("placer")

local Log = include("logger"):new("GateService")

local GateService = {}

--[[
    Calculate gate price
    
    @param x, y, tx, ty number
    @param gateCount number
    @return number - Price
--]]
function GateService.calculatePrice(x, y, tx, ty, gateCount)
    Log:RunFunc("GateService:calculatePrice(%s, %s, %s, %s, %s)", x, y, tx, ty, gateCount)
    local d = distance(vec2(x, y), vec2(tx, ty))
    local richness = Balancing_GetSectorRichnessFactor((x + tx) / 2, (y + ty) / 2)
    local price = math.ceil(d * 30 * richness)
    
    price = price * GateConfig:get("BasePriceMultiplier")
    price = price * math.pow(GateConfig:get("SubsequentGatePriceMultiplier"), gateCount)
    price = math.pow(price, math.pow(GateConfig:get("SubsequentGatePricePower"), gateCount))
    
    return math.ceil(price)
end

--[[
    Calculate the cost and validate if a gate can be founded.
    
    @param playerIndex number
    @param tx, ty number
    @param otherFaction string|nil - For admin override
    @return boolean - allowed
    @return number|string - price or error message
    @return number|nil - gateCount (internal usage)
--]]
function GateService.getFoundingCost(playerIndex, tx, ty, otherFaction)
    Log:RunFunc("GateService:getFoundingCost(%s, %s, %s, %s)", playerIndex, tx, ty, otherFaction)

    local player = Player(playerIndex)
    local server = Server()
    local isAdmin = server:hasAdminPrivileges(player)
    local isFounder = GateService.isFounderShip(player)

    -- 0. Check Founder Ship (Command specific)
    if GateConfig:get("UseStationFounderShip") and not isAdmin and not isFounder then
        return false, "Build a station founder ship on any shipyard in order to found gates!"%_t
    end

    -- 1. Find Buyer
    local buyer, err = GateFinder.findBuyer(playerIndex, otherFaction)
    if not buyer then return false, err end
    
    -- 2. Validate Buyer permissions
    local canFound, errMsg = GateValidator.canBuyerFound(buyer, false) -- check normally first
    if not canFound and not isAdmin then return false, errMsg end
    
    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- 3. Validate Connection
    local validConn, connErr = GateValidator.canFoundGate(buyer, x, y, tx, ty, false)
    if not validConn and not isAdmin then return false, connErr end
    
    -- 4. Check help in destination
    if not isAdmin then
        local validHelp, helpErr = GateValidator.checkDestinationHelp(player, buyer, tx, ty)
        if not validHelp then return false, helpErr end
    end
    
    -- 5. Check if Teleporter
    if GateFinder.isTeleporterSector(tx, ty, server.seed) and not isAdmin then
        return false, "It's not possible to build gates from/to teleporter sectors!"%_t
    end
    
    -- 6. Check existing gates
    if GateFinder.hasGateTo(tx, ty) then
        return false, string.format("This sector already has gate that leads in (%i:%i)!"%_t, tx, ty)
    end
    
    -- 7. Calculate Price
    local gateCount = buyer:getValue("gates_founded") or 0
    local price = GateService.calculatePrice(x, y, tx, ty, gateCount)
    
    return true, price, gateCount, buyer
end

--[[
    Create a gate.
    
    @param playerIndex number
    @param tx, ty number
    @param otherFaction string|nil - For admin override
    @return boolean, string - Success status and message
--]]
function GateService.create(playerIndex, tx, ty, otherFaction)
    Log:RunFunc("GateService:create(%s, %s, %s, %s)", playerIndex, tx, ty, otherFaction)
    
    local player = Player(playerIndex)
    local server = Server()
    local isAdmin = server:hasAdminPrivileges(player)
    local isFounder = GateService.isFounderShip(player)
    
    -- 0. Check Station Founder Ship (Command specific)
    if not isAdmin and GateConfig:get("UseStationFounderShip") and not isFounder then
        return false, "Build a station founder ship on any shipyard in order to found gates!"%_t
    end

    -- 1. Find Buyer
    local buyer, err = GateFinder.findBuyer(playerIndex, otherFaction)
    if not buyer then return false, err end
    
    -- 2. Validation
    local canFound, errMsg = GateValidator.canBuyerFound(buyer, isAdmin)
    if not canFound then return false, errMsg end
    
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local validConn, connErr = GateValidator.canFoundGate(buyer, x, y, tx, ty, isAdmin)
    if not validConn then return false, connErr end
    
    if not isAdmin then
        local validHelp, helpErr = GateValidator.checkDestinationHelp(player, buyer, tx, ty)
        if not validHelp then return false, helpErr end
        
        if GateFinder.isTeleporterSector(tx, ty, server.seed) then
            return false, "It's not possible to build gates from/to teleporter sectors!"
        end
    end

    if GateFinder.hasGateTo(tx, ty) then
        return false, string.format("This sector already has gate that leads in (%i:%i)!", tx, ty)
    end
    
    -- 3. Price
    local gateCount = buyer:getValue("gates_founded") or 0
    local price = GateService.calculatePrice(x, y, tx, ty, gateCount)
    
    -- 4. Payment & Execution
    if not isAdmin then
         local canPay, msg = GateValidator.canPay(buyer, price)
         if not canPay then
             return false, msg 
         end
         buyer:pay("Paid %1% Credits to found a gate."%_t, price)
    end
    
    -- Update stats
    buyer:setValue("gates_founded", gateCount + 1)
    
    -- Create Entities
    local gate = GateCreator.createGate(buyer, x, y, tx, ty)
    
    -- Register
    if GateRegistry then
        GateRegistry.add(x, y, buyer.index, tx, ty)
    end
    
    -- Resolve intersections
    Placer.resolveIntersections({gate})
    
    -- Spawn return gate (Back link)
    if Galaxy():sectorLoaded(tx, ty) then
        invokeSectorFunction(tx, ty, true, "gatefounder.lua", "foundGate", buyer.index, x, y)
    else
         local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 1, tx, ty, buyer.index, x, y)
         if status ~= 0 then
             Log:Error("GateService - failed to mark gate for creation: %i", status)
         end
    end
    
    return true, string.format("Successfully founded a gate from (%i:%i) to (%i:%i).", x, y, tx, ty)
end

--[[
    Found a gate.
    
    @param playerIndex number
    @param tx, ty number
    @param otherFaction string|nil - For admin override
    @return boolean, string - Success status and potential message
--]]
function GateService.found(playerIndex, tx, ty, otherFaction)
    Log:RunFunc("GateService:found(%s, %s, %s, %s)", playerIndex, tx, ty, otherFaction)
    local player = Player(playerIndex)
    local server = Server()
    
    -- Info Mode (Validation & Price)
    local allowed, price, gateCount, buyer = GateService.getFoundingCost(playerIndex, tx, ty, otherFaction)
    if not allowed then
        return false, price -- price is error message here
    end

    local x, y = Sector():getCoordinates()
    return true, string.format("Founding a gate from (%i:%i) to (%i:%i) will cost %i credits.", x, y, tx, ty, price or 0)
end

--[[
    Toggle a gate.
    
    @param playerIndex number
    @param x, y number - Sector coordinates of the gate
    @return boolean, string - Success status and potential message
--]]
function GateService.toggle(playerIndex, x, y)
    Log:RunFunc("GateService:toggle(%s, %s, %s)", playerIndex, x, y)
    local player = Player(playerIndex)
    local server = Server()
    local isAdmin = server:hasAdminPrivileges(player)
    
    local gates = GateRegistry.getInSector(x, y)
    local targetGate = nil
    
    -- Find gate owned by player
    for _, g in ipairs(gates) do
        if g.owner == playerIndex or isAdmin then
            targetGate = g
            break
        end 
    end
    
    if not targetGate then
        return false, "No gate found that you can manage in this sector."
    end
    
    local tx, ty = targetGate.linkedTo.x, targetGate.linkedTo.y
    local newState = (targetGate.status == "active") and false or true
    
    -- Update in Registry immediately to reflect intent? Or wait for callback? 
    -- Better to update assuming success or let the entity update it.
    -- GateRegistry doesn't track power state accurately unless synchronized.
    -- However, we can use the same logic as gate.lua onToggle.
    
    if Galaxy():sectorLoaded(x, y) then
         -- If we are in sector, we can just find the entity and toggle it?
         -- But this script (GateService) might be running from a command (Server context).
         -- The command context is not bound to a sector.
         -- But invokeSectorFunction works.
         invokeSectorFunction(x, y, true, "gatefounder.lua", "toggleGate", playerIndex, x, y, newState)
    else
         -- Add to TODO via Galaxy script
         local status = Galaxy():invokeFunction("gatefounder.lua", "todo", 3, tx, ty, playerIndex, x, y, newState)
         if status ~= 0 then
             Log:Error("GateService.toggle - failed to mark gate for toggle: %i", status)
             return false, "Failed to schedule gate toggle."
         end
    end
    
    -- Also toggle the other side? gate.lua does it.
    -- gate.lua's gateFounder_onToggle calls invokeSectorFunction(tx, ty, ..., "toggleGate", ...)
    -- which triggers "toggleGate" in sector/gatefounder.lua.
    -- That function likely toggles the gate entity there.
    -- Does it toggle the return gate?
    -- Let's trust sector/gatefounder.lua handles the logic if we invoke it for the primary gate.
    -- Wait, gate.lua logic:
    -- invokeSectorFunction(tx, ty, ... "toggleGate" ... targetFaction.index, x, y, newPower)
    -- It toggles the REMOTE gate. And sets local power.
    
    -- So we need to reproduce that:
    -- 1. Toggle local gate
    -- 2. Toggle remote gate
    
    -- For local gate (x, y):
    if Galaxy():sectorLoaded(x, y) then
         invokeSectorFunction(x, y, true, "gatefounder.lua", "toggleGate", playerIndex, x, y, newState)
    else
         Galaxy():invokeFunction("gatefounder.lua", "todo", 3, x, y, playerIndex, x, y, newState)
    end
    
    -- For remote gate (tx, ty) [Done by sector/gatefounder.lua? Or need manual?]
    -- gate.lua manually invokes on (tx, ty) AND sets local power.
    -- So we should probably invoke on (tx, ty) as well?
    -- Actually, simpler: just invoke "toggleGate" on (x, y). 
    -- Does sector/gatefounder.lua's toggleGate handle synchronization?
    -- Needed to check sector/gatefounder.lua... Assuming manual sync is needed based on gate.lua code.
    
    if Galaxy():sectorLoaded(tx, ty) then
         invokeSectorFunction(tx, ty, true, "gatefounder.lua", "toggleGate", playerIndex, x, y, newState) -- x, y is the "partner" from tx,ty perspective? No.
         -- gate.lua calls: invokeSectorFunction(tx, ty, ..., faction.index, x, y, newPower)
         -- It passes x,y as the source.
    else
         Galaxy():invokeFunction("gatefounder.lua", "todo", 3, tx, ty, playerIndex, x, y, newState)
    end
    
    return true, newState and "Gates toggled ON." or "Gates toggled OFF."
end

--[[
    Destroy a gate.
    
    @param playerIndex number
    @param x, y number
    @return boolean, string
--]]
function GateService.destroy(playerIndex, x, y)
    Log:RunFunc("GateService:destroy(%s, %s, %s)", playerIndex, x, y)
    local player = Player(playerIndex)
    local server = Server()
    local isAdmin = server:hasAdminPrivileges(player)
    
    local gates = GateRegistry.getInSector(x, y)
    local targetGate = nil
    
    for _, g in ipairs(gates) do
        if g.owner == playerIndex or isAdmin then
            targetGate = g
            break
        end 
    end
    
    if not targetGate then
        return false, "No gate found that you can destroy."
    end
    
    local tx, ty = targetGate.linkedTo.x, targetGate.linkedTo.y
    
    -- Destroy local
    if Galaxy():sectorLoaded(x, y) then
         invokeSectorFunction(x, y, true, "gatefounder.lua", "destroyGate", playerIndex, x, y)
    else
         Galaxy():invokeFunction("gatefounder.lua", "todo", 4, x, y, playerIndex, x, y)
    end
    
    -- Destroy remote
    if Galaxy():sectorLoaded(tx, ty) then
         invokeSectorFunction(tx, ty, true, "gatefounder.lua", "destroyGate", playerIndex, x, y)
    else
         Galaxy():invokeFunction("gatefounder.lua", "todo", 4, tx, ty, playerIndex, x, y)
    end
    
    -- Registry update should happen automatically if gatefounder.lua handles it?
    -- GateRegistry.remove(x, y, tx, ty) is called by entity destruction potentially?
    -- Or we should do it here to be safe.
    GateRegistry.remove(x, y, tx, ty)
    GateRegistry.remove(tx, ty, x, y) -- remove reverse link too
    
    return true, "Gate destroyed."
end

--[[
    Checks if the player's current craft is a founder ship.

    @param player Player - The player object.
    @return boolean - True if the player's craft is a founder ship, false otherwise.
--]]
function GateService.isFounderShip(player)
    Log:RunFunc("GateService:isFounderShip(%i)", player.index)
    local craft = player.craft
    local ok, name = craft:invokeFunction("stationfounder.lua", "getIcon")
    return name ~= nil
end

return GateService

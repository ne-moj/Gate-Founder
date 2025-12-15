--[[
    Gate Commands
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    
    PURPOSE:
    Provides commands for managing gates in Avorion.
    
    USAGE:
        /gate create <x> <y>
        /gate cost <x> <y>
        /gate info <x> <y>
        /gate toggle <x> <y>
        /gate destroy <x> <y>
]]--

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local GateService = include("gate/service")
local Logger = include("logger"):new("Gate:Actions")
local Actions = {}

--[[
    Creates a gate at the specified coordinates.

    @param playerIndex The index of the player initiating the command.
    @param args A table containing the command arguments: {x, y}.
    @return number status code (0 for success, 1 for failure).
    @return string message (empty string).
    @return string error/success message.
]]--
function Actions.create(playerIndex, args)
    local player = Player(playerIndex)
    if not player then return 1, "", "Player not found"%_t end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate create <x> <y>"%_t
    end
    
    local success, msg = GateService.create(playerIndex, x, y, nil)
    
    if success then
        return 0, "", msg or "Command executed successfully"%_t
    else
        return 1, "", msg or "Command failed"%_t
    end
end

--[[
    Returns the cost of founding a gate at the specified coordinates.

    @param playerIndex The index of the player initiating the command.
    @param args A table containing the command arguments: {x, y}.
    @return number status code (0 for success, 1 for failure).
    @return string message (empty string).
    @return string error/success message.
]]--
function Actions.cost(playerIndex, args)
    local player = Player(playerIndex)
    if not player then return 1, "", "Player not found"%_t end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate cost <x> <y>"%_t
    end

    local allowed, price, gateCount = GateService.getFoundingCost(playerIndex, x, y, nil, true)
    
    if not allowed then
        -- price is error message in this case
        return 1, "", string.format("Cannot found gate: %s"%_t, tostring(price))
    else
        local sx, sy = Sector():getCoordinates()
        return 0, "", string.format("Founding a gate from (%i:%i) to (%i:%i) will cost %s credits."%_t, sx, sy, x, y, createMonetaryString(price))
    end
end

--[[
    Returns information about the gate at the specified coordinates.

    @param playerIndex The index of the player initiating the command.
    @param args A table containing the command arguments: {x, y}.
    @return number status code (0 for success, 1 for failure).
    @return string message (empty string).
    @return string error/success message.
]]--
function Actions.info(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate info <x> <y>"%_t
    end
    
    -- TODO: Implement gate info lookup using Registry?
    local msg = string.format("[Gate Info at (%d, %d)]:\n"%_t, x, y)
    msg = msg .. "No gate found at these coordinates.\n"%_t
    
    return 0, "", msg
end

--[[
    Toggles the gate at the specified coordinates.

    @param playerIndex The index of the player initiating the command.
    @param args A table containing the command arguments: {x, y}.
    @return number status code (0 for success, 1 for failure).
    @return string message (empty string).
    @return string error/success message.
]]--
function Actions.toggle(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate toggle <x> <y>"%_t
    end
    
    local success, msg = GateService.toggle(playerIndex, x, y)
    
    if success then
        return 0, "", msg or "Gate toggled."%_t
    else
        return 1, "", msg or "Failed to toggle gate."%_t
    end
end

--[[
    Destroys the gate at the specified coordinates.

    @param playerIndex The index of the player initiating the command.
    @param args A table containing the command arguments: {x, y}.
    @return number status code (0 for success, 1 for failure).
    @return string message (empty string).
    @return string error/success message.
]]--
function Actions.destroy(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate destroy <x> <y>"%_t
    end
    
    local success, msg = GateService.destroy(playerIndex, x, y)
    
    if success then
        return 0, "", msg or "Gate destroyed."%_t
    else
        return 1, "", msg or "Failed to destroy gate."%_t
    end
end

return Actions

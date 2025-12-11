package.path = package.path .. ";data/scripts/lib/?.lua"

local Actions = {}

Actions.create = function(playerIndex, args)
    local player = Player(playerIndex)
    if not player then return 1, "", "Player not found" end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local confirm = args[3]
    
    if not x or not y then
        return 1, "", "Usage: /gate create <x> <y> [confirm]"
    end
    
    if confirm == "confirm" then
        -- Actually create the gate
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, "confirm", nil, true)
        return 0, "", string.format("Creating gate to (%d, %d)...", x, y)
    else
        -- Show price info
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, nil, nil, true)
        return 0, "", string.format("Calculating price for gate to (%d, %d)...", x, y)
    end
end

Actions.info = function(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate info <x> <y>"
    end
    
    -- TODO: Implement gate info lookup
    local msg = string.format("**Gate Info at (%d, %d):**\n", x, y)
    msg = msg .. "No gate found at these coordinates.\n"
    
    return 0, "", msg
end

Actions.toggle = function(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate toggle <x> <y>"
    end
    
    -- TODO: Implement gate toggle
    return 0, "", string.format("Toggle gate at (%d, %d) - Not implemented yet", x, y)
end

Actions.destroy = function(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local confirm = args[3]
    
    if not x or not y then
        return 1, "", "Usage: /gate destroy <x> <y> [confirm]"
    end
    
    if confirm == "confirm" then
        -- TODO: Implement gate destruction
        return 0, "", string.format("Destroying gate at (%d, %d) - Not implemented yet", x, y)
    else
        return 0, "", string.format("Are you sure you want to destroy gate at (%d, %d)? Use '/gate destroy %d %d confirm' to confirm.", x, y, x, y)
    end
end

return Actions

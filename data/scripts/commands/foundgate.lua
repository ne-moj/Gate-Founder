function execute(sender, commandName, x, y, confirm)
    local player = Player(sender)
    if not player then
        return 1, "", "You're not in a ship!"
    end

    if not player.craft then
        return 1, "", "You're not in a ship!"
    end
    
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then
        player:sendChatMessage("Server", 0, getHelp())
    else
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, confirm, true)
    end

    return 0, "", ""
end

function getDescription()
    return "Allows to found gates."
end

function getHelp()
    return [[Allows to found gates. Usage:
    /foundgate x y - Get price info.
    /foundgate x y confirm - Found a gate. Visit target sector to spawn a gate back.]]
end
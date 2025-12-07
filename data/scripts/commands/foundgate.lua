package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, x, y, confirm, otherFaction)
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
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, confirm, otherFaction, true)
    end

    return 0, "", ""
end

function getDescription()
    return "Allows to found gates."
end

function getHelp()
    return [[Allows to found gates. Usage:
    /foundgate x y - Get price info
    /foundgate x y confirm - Found a gate
    /foundgate x y cheat - Found a gate as an admin, bypassing some checks and not paying for it
    /foundgate x y cheat "PlayerName" - Found a gate as an admin for other ONLINE player
    /foundgate x y cheat 12345 - Found a gate as an admin for other faction]]
end
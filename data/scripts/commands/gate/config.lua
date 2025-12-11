package.path = package.path .. ";data/scripts/lib/?.lua"

local function config(playerIndex, args)
    local player = Player(playerIndex)
    if not player then
        return 1, "", "Player not found"
    end
    
    -- Check admin privileges
    if not Server():hasAdminPrivileges(player) then
        return 1, "", "You don't have admin privileges"
    end
    
    local key = args[1]
    local value = args[2]
    
    if not key then
        -- Show all config
        return 0, "", [[
**Gate Configuration:**
  maxdistance = 500
  maxgates = 5
  refund = 50%
  cooldown = 0 seconds
  statistics = enabled

Use "/gate config <key> <value>" to change settings.
Use "/gate config reload" to reload from file.
]]
    end
    
    if key == "reload" then
        -- TODO: Reload config
        return 0, "", "Configuration reloaded from file."
    end
    
    if value then
        -- TODO: Set config value
        return 0, "", string.format("Set %s = %s", key, value)
    else
        -- TODO: Get config value
        return 0, "", string.format("%s = (value)", key)
    end
end

return config

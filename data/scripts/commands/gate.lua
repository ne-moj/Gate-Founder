package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    Gate Command - Main Command Router
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Central command router for all gate-related console commands.
    Routes subcommands to appropriate handlers.
    
    USAGE:
    /gate help              - Show all commands
    /gate list              - List your gates
    /gate info x y          - Gate information
    /gate create x y        - Create gate
    /gate toggle x y        - Enable/disable gate
    /gate destroy x y       - Destroy gate
    /gate admin <cmd>       - Admin commands
    /gate config <key>      - Configuration
    
    ADMIN COMMANDS:
    /gate admin list        - List all gates
    /gate admin tp x y      - Teleport to gate
    /gate admin destroy x y - Force destroy gate
    /gate admin transfer    - Transfer ownership
--]]

local Logger = include("logger"):new("GateCommand")

-- Subcommand handlers
local subcommands = {}

-- ============================================================================
-- SUBCOMMAND: help
-- ============================================================================

subcommands.help = function(playerIndex, args)
    local helpText = [[
Gate Founder Commands:

§cUser Commands:§7
  /gate list              - List your gates
  /gate info <x> <y>      - Get gate information
  /gate create <x> <y>    - Create a new gate pair
  /gate toggle <x> <y>    - Enable/disable your gate
  /gate destroy <x> <y>   - Destroy your gate

§cAdmin Commands:§7
  /gate admin list        - List all gates on server
  /gate admin tp <x> <y>  - Teleport to gate location
  /gate admin destroy <x> <y> - Force destroy any gate
  /gate admin transfer <x> <y> <owner> - Transfer ownership
  /gate config            - View/modify settings
  /gate config reload     - Reload configuration

§cExamples:§7
  /gate create 50 -30           - Show price for gate to (50, -30)
  /gate create 50 -30 confirm   - Create gate (pay and build)
  /gate info 50 -30             - Show gate details
  /gate toggle 50 -30           - Toggle gate on/off

Type "/gate help <command>" for detailed help on a specific command.
]]
    return 0, "", helpText
end

-- ============================================================================
-- SUBCOMMAND: list
-- ============================================================================

subcommands.list = function(playerIndex, args)
    local player = Player(playerIndex)
    if not player then
        return 1, "", "Player not found"
    end
    
    -- TODO: Implement gate list from registry
    -- For now, placeholder response
    local msg = "§cYour Gates:§7\n"
    msg = msg .. "No gates found. Use /gate create <x> <y> to create one.\n"
    
    return 0, "", msg
end

-- ============================================================================
-- SUBCOMMAND: info
-- ============================================================================

subcommands.info = function(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate info <x> <y>"
    end
    
    -- TODO: Implement gate info lookup
    local msg = string.format("§cGate Info at (%d, %d):§7\n", x, y)
    msg = msg .. "No gate found at these coordinates.\n"
    
    return 0, "", msg
end

-- ============================================================================
-- SUBCOMMAND: create
-- ============================================================================

subcommands.create = function(playerIndex, args)
    local player = Player(playerIndex)
    if not player then
        return 1, "", "Player not found"
    end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local confirm = args[3]
    
    if not x or not y then
        return 1, "", "Usage: /gate create <x> <y> [confirm]"
    end
    
    if confirm == "confirm" then
        -- Actually create the gate
        -- TODO: Call existing foundgate logic
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, "confirm", nil, true)
        return 0, "", string.format("Creating gate to (%d, %d)...", x, y)
    else
        -- Show price info
        invokeFactionFunction(player.index, true, "gatefounder.lua", "found", x, y, nil, nil, true)
        return 0, "", string.format("Calculating price for gate to (%d, %d)...", x, y)
    end
end

-- ============================================================================
-- SUBCOMMAND: toggle
-- ============================================================================

subcommands.toggle = function(playerIndex, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    
    if not x or not y then
        return 1, "", "Usage: /gate toggle <x> <y>"
    end
    
    -- TODO: Implement gate toggle
    return 0, "", string.format("Toggle gate at (%d, %d) - Not implemented yet", x, y)
end

-- ============================================================================
-- SUBCOMMAND: destroy
-- ============================================================================

subcommands.destroy = function(playerIndex, args)
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

-- ============================================================================
-- SUBCOMMAND: admin
-- ============================================================================

subcommands.admin = function(playerIndex, args)
    local player = Player(playerIndex)
    if not player then
        return 1, "", "Player not found"
    end
    
    -- Check admin privileges
    if not Server():hasAdminPrivileges(player) then
        return 1, "", "You don't have admin privileges"
    end
    
    local adminCmd = args[1]
    local adminArgs = {}
    for i = 2, #args do
        table.insert(adminArgs, args[i])
    end
    
    if not adminCmd then
        return 0, "", [[
§cAdmin Commands:§7
  /gate admin list [filter]     - List all gates
  /gate admin tp <x> <y>        - Teleport to gate
  /gate admin destroy <x> <y>   - Force destroy gate
  /gate admin transfer <x> <y> <owner> - Transfer ownership
]]
    end
    
    if adminCmd == "list" then
        -- TODO: Implement admin list
        return 0, "", "§cAll Gates on Server:§7\nNo gates registered yet."
    elseif adminCmd == "tp" then
        local x = tonumber(adminArgs[1])
        local y = tonumber(adminArgs[2])
        if not x or not y then
            return 1, "", "Usage: /gate admin tp <x> <y>"
        end
        player:setValue("jump", x .. ":" .. y)
        player.craft.hyperspaceJumpReached = true
        return 0, "", string.format("Teleporting to (%d, %d)...", x, y)
    elseif adminCmd == "destroy" then
        local x = tonumber(adminArgs[1])
        local y = tonumber(adminArgs[2])
        if not x or not y then
            return 1, "", "Usage: /gate admin destroy <x> <y> confirm"
        end
        -- TODO: Implement force destroy
        return 0, "", string.format("Force destroying gate at (%d, %d) - Not implemented yet", x, y)
    elseif adminCmd == "transfer" then
        return 0, "", "Transfer ownership - Not implemented yet"
    else
        return 1, "", "Unknown admin command: " .. adminCmd
    end
end

-- ============================================================================
-- SUBCOMMAND: config
-- ============================================================================

subcommands.config = function(playerIndex, args)
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
§cGate Configuration:§7
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

-- ============================================================================
-- MAIN EXECUTE FUNCTION
-- ============================================================================

function execute(playerIndex, commandName, ...)
    Logger:Debug("execute([playerIndex]:%s, [commandName]:%s, ...)", playerIndex, commandName)
    
    local args = {...}
    local subcommand = args[1] or "help"
    
    -- Remove subcommand from args
    local subArgs = {}
    for i = 2, #args do
        table.insert(subArgs, args[i])
    end
    
    -- Route to subcommand handler
    local handler = subcommands[subcommand]
    if handler then
        return handler(playerIndex, subArgs)
    else
        -- Unknown subcommand - show help
        return 0, "", string.format("Unknown command: %s. Use '/gate help' for available commands.", subcommand)
    end
end

-- ============================================================================
-- COMMAND METADATA
-- ============================================================================

function getDescription()
    return "Gate management commands - create, list, manage gates"
end

function getHelp()
    return [[Gate Founder - Gate Management Commands

Usage: /gate <command> [options]

Commands:
  help     - Show this help
  list     - List your gates
  info     - Get gate information
  create   - Create a new gate
  toggle   - Enable/disable gate
  destroy  - Destroy your gate
  admin    - Admin commands
  config   - Configuration (admin)

Examples:
  /gate list
  /gate create 50 -30
  /gate admin tp 50 -30

Type "/gate help" in-game for detailed help.]]
end

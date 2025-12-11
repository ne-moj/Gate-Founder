package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/commands/?.lua"

--[[
    Gate Command - Main Command Router
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Central command router for all gate-related console commands.
    Routes subcommands to appropriate handlers in commands/gate/.
--]]

local Logger = include("logger"):new("GateCommand")

-- Subcommand handlers
local subcommands = {}

-- Load submodules
subcommands.list = include("gate/list.lua")
subcommands.admin = include("gate/admin.lua")
subcommands.config = include("gate/config.lua")
subcommands.help = include("gate/help.lua")

-- Load and map actions
local actions = include("gate/actions.lua")
subcommands.create = actions.create
subcommands.info = actions.info
subcommands.toggle = actions.toggle
subcommands.destroy = actions.destroy

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
        local status, ret1, ret2, ret3 = pcall(handler, playerIndex, subArgs)
        if status then
             return ret1, ret2, ret3
        else
             Logger:Error("Subcommand '%s' failed: %s", subcommand, tostring(ret1))
             return 1, "", "Internal error executing command."
        end
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
    return subcommands.help(nil, {})
end

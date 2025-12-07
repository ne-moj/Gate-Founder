package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    GF Command - Alias for /gate
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Short alias for /gate command.
    Only works if EnableShortAlias is set to true in config.
    
    USAGE:
    /gf help    - Same as /gate help
    /gf list    - Same as /gate list
    etc.
--]]

-- Check if alias is enabled
local GateFounderInit = include("gatefounderinit")
local Config = GateFounderInit[2]

function execute(playerIndex, commandName, ...)
    if not Config or not Config.EnableShortAlias then
        return 1, "", "Short alias /gf is disabled. Enable it in config (EnableShortAlias = true) or use /gate instead."
    end
    
    -- Delegate to main gate command
    local gate = include("commands/gate")
    return gate.execute(playerIndex, commandName, ...)
end

function getDescription()
    return "Alias for /gate command (if enabled in config)"
end

function getHelp()
    return [[Short alias for /gate command.
    
This command only works if EnableShortAlias is set to true in the GateFounder config.

Usage: /gf <subcommand> [options]

This is equivalent to: /gate <subcommand> [options]

Use /gate help for full command list.]]
end

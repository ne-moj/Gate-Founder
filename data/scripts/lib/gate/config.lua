--[[
    Gate Config v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This module initializes the configuration settings for the Gate Founder mod,
      providing a centralized system for managing mod parameters.
    
    USAGE:
        To access configuration values:
            local value = GateConfig:get("someSettingName")
            
        To set a configuration value:
            local success, error = GateConfig:set("someSettingName", newValue)
            
        To reload the configuration:
            GateConfig:reload()
--]]
package.path = package.path .. ";data/scripts/lib/?.lua"

local Configs = include("configs")

-- Module exports
local GateConfig = {}

-- ============================================================================
-- CONFIGURATION SCHEMA
-- ============================================================================

local configSchema = {
    _version = {
        default = "0.1.0",
        type = "string",
        comment = "Config version. Don't touch."
    },
    LogLevel = {
        default = 4,
        type = "number",
        min = 0,
        max = 5,
        comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug, 5 - Fun Run."
    },
    FileLogLevel = {
        default = 4,
        type = "number",
        min = 0,
        max = 5,
        comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug, 5 - Fun Run."
    },
    MaxDistance = {
        default = 45,
        type = "number",
        min = 1,
        comment = "Max gate distance in sectors."
    },
    BasePriceMultiplier = {
        default = 15000,
        type = "number",
        min = 1,
        comment = "Affects basic gate price."
    },
    MaxGatesPerFaction = {
        default = 1000,
        type = "number",
        min = 0,
        comment = "How many gates can each faction found."
    },
    AlliancesOnly = {
        default = false,
        type = "boolean",
        comment = "If true, only alliances will be able to found gates."
    },
    SubsequentGatePriceMultiplier = {
        default = 1.1,
        type = "number",
        min = 0,
        comment = "Affects price of all subsequent gates. Look at mod page for formula."
    },
    SubsequentGatePricePower = {
        default = 1.01,
        type = "number",
        min = 0,
        comment = "Affects price of all subsequent gates. Look at mod page for formula."
    },
    AllowToPassBarrier = {
        default = false,
        type = "boolean",
        comment = "If true, players will be able to build gates through barrier."
    },
    UseStationFounderShip = {
        default = true,
        type = "boolean",
        comment = "If true, in order to found gates you'll need to build station founder ship on any shipyard."
    },
    ShouldOwnOriginSector = {
        default = false,
        type = "boolean",
        comment = "If true, faction can found a gate only if it owns current sector."
    },
    ShouldOwnDestinationSector = {
        default = false,
        type = "boolean",
        comment = "If true, faction can found a gate only if it owns destination sector."
    },
    AllowGatesToCenter = {
        default = false,
        type = "boolean",
        comment = "If true, it's possible to build gates to/from center of a galaxy (0:0)."
    },
    NeedHelpFromDestinationSector = {
        default = false,
        type = "boolean",
        comment = "If true, players will need to have a ship/station in destination sector."
    },
    ForbidGatesForEnemies = {
        default = true,
        type = "boolean",
        comment = "If true, enemies of gate owner faction will not be able to pass."
    },
    BuiltGatesCanBeCaptured = {
        default = true,
        type = "boolean",
        comment = "If false, player-built gates will not be captured by NPC."
    },
    CapturedBuiltGatesCanBeDestroyed = {
        default = true,
        type = "boolean",
        comment = "If false, only initial builder can destroy a gate."
    },
    CapturedNPCGatesCanBeDestroyed = {
        default = true,
        type = "boolean",
        comment = "If false, captured NPC gates cannot be destroyed."
    },
    RefundOnDestroy = {
        default = 50,
        type = "number",
        min = 0,
        max = 100,
        comment = "Percentage of gate cost refunded when destroyed (0-100)."
    },
    EnableStatistics = {
        default = true,
        type = "boolean",
        comment = "If true, track gate usage statistics."
    },
    CreateCooldown = {
        default = 0,
        type = "number",
        min = 0,
        comment = "Cooldown in seconds between creating gates (0 = no cooldown)."
    },
    EnableShortAlias = {
        default = false,
        type = "boolean",
        comment = "If true, enable /gf as alias for /gate command."
    }
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local useSeed = onClient() -- Client uses seed, Server doesn't
GateConfig = Configs("GateFounderV2", {
    useSeed = useSeed,
    schema = configSchema
})

-- Load config
local ok, err = GateConfig:load()

if onServer() then
    -- Migration logic
    local version = GateConfig:get("_version")
    local needsSave = false
    
    if version == "0.0.1" then
        GateConfig:set("_version", "0.1.0")
        if GateConfig:get("MaxGatesPerFaction") == "5" then
            GateConfig:set("MaxGatesPerFaction", 1000)
        end
        needsSave = true
        version = "0.1.0"
    end
    
    if needsSave then
        GateConfig:save()
    end
end


-- ============================================================================
-- HELPERS
-- ============================================================================
--[[
    @brief Gets a configuration value
    
    This function gets a configuration value based on the key.
    @param key The key of the configuration value.
    @return The configuration value.
]]--
function GateConfig:get(key)
    if GateConfig then
        return GateConfig:get(key)
    end
    return nil
end

--[[
    @brief Sets a configuration value
    
    This function sets a configuration value based on the key.
    @param key The key of the configuration value.
    @param value The value to set.
    @return A tuple (boolean, string) where the boolean indicates success and the string is an error message if validation fails.
]]--
function GateConfig:set(key, value)
    if GateConfig then
        local ok, err = GateConfig:set(key, value)
        if ok then
            GateConfig:save()
        end
        return ok, err
    end
    return false, "Config not initialized"
end

--[[
    @brief Reloads the configuration
    
    This function reloads the configuration from the file.
]]--
function GateConfig.reload()
    if GateConfig then
        GateConfig:load()
    end
end

return GateConfig

package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    Gate Founder Initialization
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Initializes Gate Founder mod configuration and logging.
    Replaces Azimuth dependency with native Configs and Logger modules.
    
    USAGE:
        local GateFounderInit = include("gatefounderinit")
        local Config = GateFounderInit.Config
        local Log = GateFounderInit.Log
        
        -- Access config values
        local maxDistance = Config:get("MaxDistance")
        
        -- Log messages
        Log:Info("Gate created at %d, %d", x, y)
--]]

local Configs = include("configs")
local Logger = include("logger")

-- Module exports
local GateFounderInit = {
    Config = nil,
    Log = nil
}

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
        default = 2,
        type = "number",
        min = 0,
        max = 4,
        comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."
    },
    FileLogLevel = {
        default = 2,
        type = "number",
        min = 0,
        max = 4,
        comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."
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

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Common Initialization (Client & Server)
-- Create config instance
-- Client uses seed-dependent config name automatically if useSeed=true, but here we want same config?
-- Actually, the server config (moddata/GateFounderV2.lua) is shared/synced? 
-- No, client config is usually separate "moddata/GateFounderV2<seed>.lua".
-- But the schema is the same.

local useSeed = onClient() -- Client uses seed, Server doesn't
GateFounderInit.Config = Configs("GateFounderV2", {
    useSeed = useSeed,
    schema = configSchema
})

-- Load config
local ok, err = GateFounderInit.Config:load()
if not ok and onServer() then
    print("[GateFounder] Failed to load config: " .. (err or "unknown error"))
end

if onServer() then
    -- Migration from old versions (Server only)
    local version = GateFounderInit.Config:get("_version")
    local needsSave = false
    
    if version == "0.0.1" then
        GateFounderInit.Config:set("_version", "0.1.0")
        if GateFounderInit.Config:get("MaxGatesPerFaction") == "5" then
            GateFounderInit.Config:set("MaxGatesPerFaction", 1000)
        end
        needsSave = true
        version = "0.1.0"
    end
    
    if needsSave then
        GateFounderInit.Config:save()
    end
    print("[GateFounder] Initialized with config version " .. (version or "unknown"))
end

-- Create logger with configured log levels
local logLevel = GateFounderInit.Config:get("LogLevel") or 2
local fileLogLevel = GateFounderInit.Config:get("FileLogLevel") or 2

print("[GateFounderInit] Initializing Log...")
GateFounderInit.Log = Logger:new("GateFounder")
print("[GateFounderInit] Log initialized: " .. tostring(GateFounderInit.Log))

-- Map log levels (0-4) to bitmasks
-- 0 = none, 1 = errors, 2 = +warnings, 3 = +info, 4 = +debug
local levelMasks = {
    [0] = {},
    [1] = {'ERROR'},
    [2] = {'ERROR', 'WARNING'},
    [3] = {'ERROR', 'WARNING', 'INFO'},
    [4] = {'ERROR', 'WARNING', 'INFO', 'DEBUG'},
    [5] = {'ERROR', 'WARNING', 'INFO', 'DEBUG', 'FUN_RUN'}
}

GateFounderInit.Log.printMask = GateFounderInit.Log:_prepareMask(levelMasks[logLevel] or levelMasks[2])
GateFounderInit.Log.saveMask = GateFounderInit.Log:_prepareMask(levelMasks[fileLogLevel] or levelMasks[2])

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
    Get a config value (shortcut)
    @param key string - Config key
    @return any - Config value
--]]
function GateFounderInit.get(key)
    if GateFounderInit.Config then
        return GateFounderInit.Config:get(key)
    end
    return nil
end

--[[
    Set a config value (shortcut)
    @param key string - Config key
    @param value any - New value
    @return boolean, string - success and error
--]]
function GateFounderInit.set(key, value)
    if GateFounderInit.Config then
        local ok, err = GateFounderInit.Config:set(key, value)
        if ok then
            GateFounderInit.Config:save()
        end
        return ok, err
    end
    return false, "Config not initialized"
end

--[[
    Reload config from file
--]]
function GateFounderInit.reload()
    if GateFounderInit.Config then
        GateFounderInit.Config:load()
    end
end

return GateFounderInit
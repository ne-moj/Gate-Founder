package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth, Config, Log

if onServer() then


Azimuth = include("azimuthlib-basic")

-- load config
local configOptions = {
  _version = { default = "1.2", comment = "Config version. Don't touch." },
  LogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
  FileLogLevel = { default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug." },
  MaxDistance_Post0_26 = { default = 45, min = 1, format = "floor", comment = "Max gate distance for Avorion >= 0.26." },
  MaxDistance = { default = 15, min = 1, format = "floor", comment = "Max gate distance for Avorion pre 0.26." },
  BasePriceMultiplier = { default = 15000, min = 1, comment = "Affects basic gate price." },
  MaxGatesPerFaction = { default = 5, min = 0, format = "floor", comment = "How many gates can each faction found." },
  AlliancesOnly = { default = false, comment = "If true, only alliances wiil be able to found gates." },
  SubsequentGatePriceMultiplier = { default = 1.1, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula." },
  SubsequentGatePricePower = { default = 1.01, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula." },
  AllowToPassBarrier = { default = false, comment = "If true, players will be able to build gates through barrier." },
  UseStationFounderShip = { default = true, comment = "If true, in order to found gates you'll need to build station founder ship on any shipyard." },
  ShouldOwnOriginSector = { default = false, comment = "If true, faction can found a gate only if it owns current sector." },
  ShouldOwnDestinationSector = { default = false, comment = "If true, faction can found a gate only if it owns destinaton sector." }
}
local isModified
Config, isModified = Azimuth.loadConfig("GateFounder", configOptions)
if Config._version == "1.0" then
    Config._version = "1.1"
    isModified = true
    Config.UseStationFounderShip = false -- use old settings to avoid confusion
end
if Config._version == "1.1" then
    Config._version = "1.2"
    isModified = true
    Config.ShouldOwnOriginSector = Config.OwnedSectorsOnly
    Config.OwnedSectorsOnly = nil -- remove old config
    Config.FileLogLevel = Config.LogLevel -- sync log levels
end
if isModified then
    Azimuth.saveConfig("GateFounder", Config, configOptions)
end
Config._version = nil

local version = GameVersion()
if version.minor >= 26 then
    Config.MaxDistance = Config.MaxDistance_Post0_26
end

Log = Azimuth.logs("GateFounder", Config.LogLevel, Config.FileLogLevel)


end

return {Azimuth, Config, Log}
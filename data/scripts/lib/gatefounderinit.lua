package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth, Config, Log

if onServer() then


Azimuth = include("azimuthlib-basic")

-- load config
local configOptions = {
  _version = {"1.3", comment = "Config version. Don't touch."},
  LogLevel = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  FileLogLevel = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  MaxDistance = {45, round = -1, min = 1, comment = "Max gate distance."},
  BasePriceMultiplier = {15000, min = 1, comment = "Affects basic gate price."},
  MaxGatesPerFaction = {5, min = 0, format = "floor", comment = "How many gates can each faction found."},
  AlliancesOnly = {false, comment = "If true, only alliances wiil be able to found gates."},
  SubsequentGatePriceMultiplier = {1.1, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula."},
  SubsequentGatePricePower = {1.01, min = 0, comment = "Affects price of all subsequent gates. Look at mod page for formula."},
  AllowToPassBarrier = {false, comment = "If true, players will be able to build gates through barrier."},
  UseStationFounderShip = {true, comment = "If true, in order to found gates you'll need to build station founder ship on any shipyard."},
  ShouldOwnOriginSector = {false, comment = "If true, faction can found a gate only if it owns current sector."},
  ShouldOwnDestinationSector = {false, comment = "If true, faction can found a gate only if it owns destinaton sector."},
  AllowGatesToCenter = {false, comment = "If true, it's possible to build gates to/from center of a galaxy (0:0)."},
  NeedHelpFromDestinationSector = {false, comment = "If true, players will need to have a ship/station (theirs or alliance) in a destination sector to help them build a gate."},
  ForbidGatesForEnemies = {true, comment = "If true, if a ship player/alliance faction is at war with the gate owner faction, they will not be able to pass."},
  BuiltGatesCanBeCaptured = {true, comment = "If false, gates built by players/alliances will not be captured by NPC and other players/alliances."},
  CapturedBuiltGatesCanBeDestroyed = {true, comment = "If false, only initial builder of a gate will be able to destroy it."},
  CapturedNPCGatesCanBeDestroyed = {true, comment = "If false, it won't be possible to destroy captured NPC gates."}
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
if Config._version == "1.2" then
    Config._version = "1.3"
    isModified = true
    Config.MaxDistance = Config.MaxDistance_Post0_26 and Config.MaxDistance_Post0_26 or 45 -- use new 0.26+ distance
    Config.MaxDistance_Post0_26 = nil -- remove old config
end
if isModified then
    Azimuth.saveConfig("GateFounder", Config, configOptions)
end
configOptions = nil

Log = Azimuth.logs("GateFounder", Config.LogLevel, Config.FileLogLevel)


end

return {Azimuth, Config, Log}
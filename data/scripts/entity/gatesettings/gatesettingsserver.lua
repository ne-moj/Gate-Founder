package.path = package.path .. ";data/scripts/lib/?.lua"

local Configs = include("configs"):new("GateSettings")
local Logger = include("logger"):new("GateSettings:Server")

--[[
    Gate Settings - Server Module
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Handles all server-side logic for gate settings.
    Manages settings persistence, validation, and client-server synchronization.
    
    DATA FLOW:
    1. Client requests settings → Server loads from file → Sends to client
    2. Client saves settings → Server validates → Saves to file → Notifies client
    
    PERMISSIONS:
    Only administrators can view and modify gate settings.
    
    STORAGE:
    Settings are stored in: <server_folder>/moddata/GateSettings.lua
    Format: Lua table serialization (see configs.lua)
--]]

local GateSettingsServer = {}

-- Internal state
local _loadedData = nil

--[[
    Load settings from file
    
    @return table - Loaded settings data
    
    Called by: updateSettings(), saveSettingsInServer()
--]]
function GateSettingsServer._uploadSettings()
    Logger:RunFunc("_uploadSettings()")
    if _loadedData == nil then
        _loadedData = Configs:load()
    end
    return _loadedData
end

--[[
    Save settings to file
    
    @return boolean - Success status
    
    Called by: saveSettingsInServer()
--]]
function GateSettingsServer._saveSettings()
    Logger:RunFunc("_saveSettings()")
    return _loadedData and Configs:save(_loadedData) or ""
end

--[[
    Update settings for client
    
    Called from client via invokeServerFunction("updateSettings")
    Sends current settings to requesting client if they are admin.
    
    @param callingPlayer number - Player index (automatic from Avorion)
--]]
function GateSettingsServer.updateSettings(callingPlayer)
    Logger:RunFunc("updateSettings()")
    local player = Player(callingPlayer)
    local data = GateSettingsServer._uploadSettings()
    
    if player == nil then
        -- Called from server - broadcast to all admins in sector
        local allPlayers = {Sector():getPlayers()}
        for _, player in pairs(allPlayers) do
            if Server():hasAdminPrivileges(player) then
                invokeClientFunction(player, "updateClientData", data, Server():hasAdminPrivileges(player))
            end
        end
    elseif Server():hasAdminPrivileges(player) then
        -- Called from client and player is admin
        invokeClientFunction(player, "updateClientData", data, Server():hasAdminPrivileges(player))
    end
end

--[[
    Save settings from client
    
    Called from client via invokeServerFunction("saveSettingsInServer", settings)
    Validates permissions, saves settings, and notifies client of result.
    
    @param callingPlayer number - Player index (automatic from Avorion)
    @param settings table - Settings to save
--]]
function GateSettingsServer.saveSettingsInServer(callingPlayer, settings)
    Logger:RunFunc("saveSettingsInServer([settings]:%s)", settings)
    local player = Player(callingPlayer)
    
    -- Check admin privileges
    if not Server():hasAdminPrivileges(player) then
        invokeClientFunction(player, "saveSettingsInServer", {
            isSave = false,
            errorMessage = "You do not have permission to perform this operation." % _t,
        })
        return
    end
    
    -- Validate settings data
    if not settings then
        invokeClientFunction(player, "saveSettingsInServer", {
            isSave = false,
            errorMessage = "No data transferred for saving." % _t,
        })
        return
    end
    
    -- Load current settings
    GateSettingsServer._uploadSettings()
    
    -- Update settings (add/update new params)
    -- Use Configs:set to ensure validation and correct type handling
    for k, v in pairs(settings) do
        local ok, err = Configs:set(k, v)
        if not ok then
            Logger:Error("Failed to set config '%s': %s", tostring(k), tostring(err))
        end
    end
    
    -- Save to file
    GateSettingsServer._saveSettings()
    
    -- Notify client of success
    invokeClientFunction(player, "saveSettingsInServer", {isSave = true})
end

--[[
    Get current settings for secure/restore
    
    Called by Avorion's secure() callback.
    Returns current settings for saving with entity.
    
    @return table - Current settings
--]]
function GateSettingsServer.secure()
    Logger:RunFunc("secure()")
    return GateSettingsServer._uploadSettings()
end

--[[
    Restore settings from secure data
    
    Called by Avorion's restore() callback.
    Currently not implemented - settings are loaded from file instead.
    
    @param values table - Restored values
--]]
function GateSettingsServer.restore(values)
    Logger:RunFunc("restore([values]:%s)", values)
    -- Currently not used - settings loaded from file
end

return GateSettingsServer

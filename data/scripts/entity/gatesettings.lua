--[[
    Gate Settings - Admin Configuration UI
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Provides in-game UI for administrators to configure gate settings.
    Settings are synchronized between client and server.
    
    FEATURES:
    - Main tab: MaxDistance, MaxGatesPerFaction
    - Access tab: AlliancesOnly, ShouldOwnOriginSector
    - Price tab: (TODO) Pricing parameters
    - Additional tab: (TODO) Game rules
    
    ARCHITECTURE:
    - gatesettings.lua: Entry point, Avorion callbacks, client UI
    - gatesettings/server.lua: Server-side data management
    
    USAGE:
    1. Add script to any entity: /run Entity():addScript("data/scripts/entity/gatesettings.lua")
    2. Press F → "Gate Settings"
    3. Modify settings
    4. Click "Save Settings"
    
    PERMISSIONS:
    Only server administrators can access and modify settings.
    
    CLIENT-SERVER FLOW:
    1. Client opens UI → Requests settings from server
    2. Server checks admin privileges → Sends settings
    3. Client modifies settings → Sends to server
    4. Server validates → Saves → Notifies client
--]]
local entity = Entity()
if not entity or not (entity.isDrone or entity.isShip or entity.isStation) or entity.aiOwned then
	return
end

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

include("callable")
include("closurecolors")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace GateSettings
GateSettings = {}

-- Load libraries first (needed by modules)
local Logger = include("logger"):new("GateSettings")
local cUI = include("ui")

local TableShow = include ('tableshow')

-- Load modules
local GateSettingsServer = include("gatesettings/server")
local GateSettingsClient = include("gatesettings/client")

Logger:Debug("Modules loaded: Server=%s, Client=%s", tostring(GateSettingsServer ~= nil), tostring(GateSettingsClient ~= nil))

-- ============================================================================
-- STATE AND CONFIGURATION
-- ============================================================================

-- Admin status (set by server)
local isAdmin = false

-- Loaded settings data
local _loadedData = nil

-- UI elements
local tabbedWindow = nil
local allTabs = nil


-- ============================================================================
-- AVORION CALLBACKS
-- ============================================================================

--[[
    Initialize script
    
    Called by Avorion when script is added to entity.
    Requests settings from server if on client.
--]]
function GateSettings.initialize()
	if onClient() then
		Logger:Debug("Send request to Server - updateSettings()")
	
		invokeServerFunction("updateSettings")
		if onClient() and GateSettingsClient ~= nil then
			GateSettingsClient.parent = GateSettings
		elseif onServer() and GateSettingsServer ~= nil then
			GateSettingsServer.parent = GateSettings
		end
	end
end

--[[
    Check if interaction is possible
    
    Called by Avorion to determine if player can interact with entity.
    Only admins can access gate settings.
    
    @param playerIndex number - Player attempting interaction
    @param option number - Interaction option
    @return boolean - true if interaction allowed
--]]
function GateSettings.interactionPossible(playerIndex, option)
	Logger:RunFunc("interactionPossible([playerIndex]:%s, [option]:%s)", playerIndex, option)
	return playerIndex == Player().index and isAdmin or false
end

--[[
    Called when settings window is shown
--]]
function GateSettings.onShowWindow()
	Logger:RunFunc("onShowWindow()")
end

--[[
    Called when settings window is closed
--]]
function GateSettings.onCloseWindow()
	Logger:RunFunc("onCloseWindow()")
end

--[[
    Initialize UI
    
    Called by Avorion to create the settings window.
    Delegates to client module for UI creation.
--]]
function GateSettings.initUI()
	Logger:RunFunc("initUI()")
	if onClient() then
		Logger:Debug("Send request to Server - updateSettings()")
		invokeServerFunction("updateSettings")
	end
	
	-- Create UI via client module
	GateSettingsClient.initUI()
end

--[[
    Get icon for interaction menu
    
    @return string - Path to icon texture
--]]
function GateSettings.getIcon()
	Logger:RunFunc("getIcon()")
	return "data/textures/icons/gate.png"
end

--[[
    Secure settings for entity save
    
    Called by Avorion when entity is saved.
    @return table - Settings data to save
--]]
function GateSettings.secure()
	Logger:RunFunc("secure()")
	return GateSettingsServer.secure()
end

--[[
    Restore settings from entity load
    
    Called by Avorion when entity is loaded.
    @param values table - Restored settings data
--]]
function GateSettings.restore(values)
	Logger:RunFunc("restore([values]:%s)", values)
	GateSettingsServer.restore(values)
end

-- ============================================================================
-- SERVER CALLBACKS
-- ============================================================================

--[[
    Update settings (Server → Client)
    
    Called from client via invokeServerFunction("updateSettings")
    Delegates to server module.
--]]
if onServer() then
	function GateSettings.updateSettings()
		Logger:RunFunc("updateSettings()")
		GateSettingsServer.updateSettings(callingPlayer)
	end
	callable(GateSettings, "updateSettings")
end

-- ============================================================================
-- CLIENT CALLBACKS
-- ============================================================================

--[[
    Update client data (Server → Client)
    
    Called from server via invokeClientFunction(player, "updateClientData", ...)
    Updates local settings and UI with data from server.
    
    @param settings table - Settings data from server
    @param youIsAdmin boolean - Whether player is admin
--]]
if onClient() then
	function GateSettings.updateClientData(settings, youIsAdmin)
		Logger:RunFunc("updateClientData([settings]:%s, [youIsAdmin]:%s)", TableShow(settings), youIsAdmin)
		isAdmin = youIsAdmin

		if not settings then
			return
		end

		if settings.Settings ~= nil then
			_loadedData = settings.Settings
			
			-- Update UI via client module
			GateSettingsClient.updateUI(_loadedData)
		end
	end
	callable(GateSettings, "updateClientData")
end

-- ============================================================================
-- SAVE SETTINGS (CLIENT ↔ SERVER)
-- ============================================================================

--[[
    Save settings to server
    
    Called from both client and server:
    - Client: Sends settings to server for saving
    - Server: Validates and saves settings, notifies client of result
    
    Client call: invokeServerFunction("saveSettingsInServer", _loadedData)
    Server response: invokeClientFunction(player, "saveSettingsInServer", {isSave=true/false, errorMessage=...})
    
    @param firstParam table - Settings to save (from client) OR result (from server)
--]]
function GateSettings.saveSettingsInServer(firstParam)
	Logger:RunFunc("saveSettingsInServer([firstParam]:%t)", firstParam)
	if onClient() then
		-- Client: Handle server response
		if firstParam == nil then
			ScriptUI():interactShowDialog({ text = "Error! Don't save settings" % _t })
		elseif not firstParam.isSave then
			if firstParam.errorMessage then
				ScriptUI():interactShowDialog({ text = "Error! " % _t .. tostring(firstParam.errorMessage) })
			else
				ScriptUI():interactShowDialog({ text = "Error! Don't save settings" % _t })
			end
		else
			ScriptUI():interactShowDialog({ text = "Success! Settings saved" % _t })
		end
	else
		-- Server: Delegate to server module
		GateSettingsServer.saveSettingsInServer(callingPlayer, firstParam)
	end
end
callable(GateSettings, "saveSettingsInServer")

-- ============================================================================
-- UI EVENT HANDLERS
-- ============================================================================

--[[
    All UI event handlers delegate to the client module.
    The handlers must be in GateSettings namespace for Avorion callbacks to work.
--]]

function GateSettings.onMaxDistanceSliderChanged(slider)
	Logger:RunFunc("onMaxDistanceSliderChanged([slider]:%s)", slider)
	GateSettingsClient.onMaxDistanceChanged(tostring(math.floor(slider.value)))
	_loadedData = GateSettingsClient.getSettingsSet()
end

function GateSettings.onMaxDistanceBoxChanged(textbox)
	Logger:RunFunc("onMaxDistanceBoxChanged([textbox]:%s)", textbox)
	local val = string.match(textbox.text, "([0-9]+[.]?[0-9]*)")
	if val ~= nil then
		val = tostring(val)
	end
	GateSettingsClient.onMaxDistanceChanged(val)
	_loadedData = GateSettingsClient.getSettingsSet()
end

function GateSettings.onClickDistanceButtonMinus()
	Logger:RunFunc("onClickDistanceButtonMinus()")
	local currentSettings = GateSettingsClient.getSettingsSet()
	GateSettingsClient.onMaxDistanceChanged(currentSettings.MaxDistance - 1)
	_loadedData = GateSettingsClient.getSettingsSet()
end

function GateSettings.onClickDistanceButtonPlus()
	Logger:RunFunc("onClickDistanceButtonPlus()")
	local currentSettings = GateSettingsClient.getSettingsSet()
	GateSettingsClient.onMaxDistanceChanged(currentSettings.MaxDistance + 1)
	_loadedData = GateSettingsClient.getSettingsSet()
end

function GateSettings.onClickMaxGatesButtonMinus()
	Logger:RunFunc("onClickMaxGatesButtonMinus()")
	local activeMenuItems = GateSettingsClient.getActiveMenuItems()
	local currentSettings = GateSettingsClient.getSettingsSet()
	
	if currentSettings.MaxGatesPerFaction >= 2 then
		currentSettings.MaxGatesPerFaction = currentSettings.MaxGatesPerFaction - 1
	else
		currentSettings.MaxGatesPerFaction = 1
	end
	
	if activeMenuItems.main.maxGatesBox then
		activeMenuItems.main.maxGatesBox.text = currentSettings.MaxGatesPerFaction
	end
	_loadedData = currentSettings
end

function GateSettings.onClickMaxGatesButtonPlus()
	Logger:RunFunc("onClickMaxGatesButtonPlus()")
	local activeMenuItems = GateSettingsClient.getActiveMenuItems()
	local currentSettings = GateSettingsClient.getSettingsSet()
	
	currentSettings.MaxGatesPerFaction = currentSettings.MaxGatesPerFaction + 1
	
	if activeMenuItems.main.maxGatesBox then
		activeMenuItems.main.maxGatesBox.text = currentSettings.MaxGatesPerFaction
	end
	_loadedData = currentSettings
end

function GateSettings.onMaxGatesChanged(textbox)
	Logger:RunFunc("onMaxGatesChanged([textbox]:%s)", textbox)
	local activeMenuItems = GateSettingsClient.getActiveMenuItems()
	local currentSettings = GateSettingsClient.getSettingsSet()
	
	if textbox.text ~= "" then
		currentSettings.MaxGatesPerFaction = tonumber(textbox.text) or currentSettings.MaxGatesPerFaction
	else
		currentSettings.MaxGatesPerFaction = 1
	end
	
	if activeMenuItems.main.maxGatesBox then
		activeMenuItems.main.maxGatesBox.text = currentSettings.MaxGatesPerFaction
	end
	_loadedData = currentSettings
end

function GateSettings.onAlliancesOnlyChanged(checkbox)
	Logger:RunFunc("onAlliancesOnlyChanged([checkbox]:%s)", checkbox)
	local currentSettings = GateSettingsClient.getSettingsSet()
	currentSettings.AlliancesOnly = checkbox.checked
	_loadedData = currentSettings
end

function GateSettings.onSectorOwnerChanged(checkbox)
	Logger:RunFunc("onSectorOwnerChanged([checkbox]:%s)", checkbox)
	local currentSettings = GateSettingsClient.getSettingsSet()
	currentSettings.ShouldOwnDestinationSector = checkbox.checked
	_loadedData = currentSettings
end

function GateSettings.onClickSaveButton()
	Logger:RunFunc("onClickSaveButton()")
	invokeServerFunction("saveSettingsInServer", _loadedData)
	GateSettingsClient.hideWindow()
end

function GateSettings.updateSettingsFromServer()
	Logger:Debug("updateSettingsFromServer()")
	invokeServerFunction("updateSettings")
end

-- ============================================================================
-- NOTE: UI private methods have been moved to gatesettings/client.lua module.
-- Server private methods have been moved to gatesettings/server.lua module.
-- ============================================================================


local entity = Entity()
if not entity or not ((entity.isDrone or entity.isShip or entity.isStation) and not entity.aiOwned) then
	return
end

package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/gatesettings/?.lua"
local Logger = include("logger"):new("GateSettings:Server")

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

include("callable")
include("closurecolors")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace GateSettings
GateSettings = {}

-- Load libraries first (needed by modules)
local Configs = include("configs"):new("GateSettings")
local Logger = include("logger"):new("GateSettings")
local cUI = include("ui")

-- Load modules
local GateSettingsServer = include("gatesettingsserver")
local GateSettingsClient = include("gatesettingsclient")

Logger:Debug("Modules loaded: Server=%s, Client=%s", tostring(GateSettingsServer ~= nil), tostring(GateSettingsClient ~= nil))

-- ============================================================================
-- STATE AND CONFIGURATION
-- ============================================================================

-- Admin status (set by server)
local isAdmin = false

-- Loaded settings data
local _loadedData = nil

-- UI elements
local settingsWindow = nil
local tabbedWindow = nil
local allTabs = nil

-- Default UI settings
local defaultSettings = {
	paddingInWindow = 10,
	heightRow = 40,
	widthNumberBox = 60,
	sizeWindow = vec2(1200, 650),
	distance = { min = 1, max = math.floor(1000 * math.sqrt(2)), step = 15 },
}

-- Current settings values (synchronized with server)
local settingsSet = {
	MaxDistance = 45,
	MaxGatesPerFaction = 5,
	AlliancesOnly = false,
	ShouldOwnOriginSector = false,
}

-- Active UI menu items (references to UI elements)
local activeMenuItems = {
	main = {},
	access = {},
	price = {},
	additional = {},
}

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
	
	-- Sync settings with client module
	GateSettingsClient.setSettingsSet(settingsSet)
	
	-- Create UI via client module
	settingsWindow = GateSettingsClient.initUI(_loadedData)
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
		Logger:RunFunc("updateClientData([settings]:%s, [youIsAdmin]:%s)", settings, youIsAdmin)
		isAdmin = youIsAdmin

		if not settings then
			return
		end
		_loadedData = settings

		if settings.Settings ~= nil then
			settingsSet = settings.Settings
			
			-- Update UI via client module
			GateSettingsClient.updateUI(settingsSet)
			
			Entity():addScript("gatesettings.lua") -- this recall interactionPossible() with update data
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
    
    Client call: invokeServerFunction("saveSettingsInServer", settingsSet)
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
	settingsSet = GateSettingsClient.getSettingsSet()
end

function GateSettings.onMaxDistanceBoxChanged(textbox)
	Logger:RunFunc("onMaxDistanceBoxChanged([textbox]:%s)", textbox)
	local val = string.match(textbox.text, "([0-9]+[.]?[0-9]*)")
	if val ~= nil then
		val = tostring(val)
	end
	GateSettingsClient.onMaxDistanceChanged(val)
	settingsSet = GateSettingsClient.getSettingsSet()
end

function GateSettings.onClickDistanceButtonMinus()
	Logger:RunFunc("onClickDistanceButtonMinus()")
	local currentSettings = GateSettingsClient.getSettingsSet()
	GateSettingsClient.onMaxDistanceChanged(currentSettings.MaxDistance - 1)
	settingsSet = GateSettingsClient.getSettingsSet()
end

function GateSettings.onClickDistanceButtonPlus()
	Logger:RunFunc("onClickDistanceButtonPlus()")
	local currentSettings = GateSettingsClient.getSettingsSet()
	GateSettingsClient.onMaxDistanceChanged(currentSettings.MaxDistance + 1)
	settingsSet = GateSettingsClient.getSettingsSet()
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
	settingsSet = currentSettings
end

function GateSettings.onClickMaxGatesButtonPlus()
	Logger:RunFunc("onClickMaxGatesButtonPlus()")
	local activeMenuItems = GateSettingsClient.getActiveMenuItems()
	local currentSettings = GateSettingsClient.getSettingsSet()
	
	currentSettings.MaxGatesPerFaction = currentSettings.MaxGatesPerFaction + 1
	
	if activeMenuItems.main.maxGatesBox then
		activeMenuItems.main.maxGatesBox.text = currentSettings.MaxGatesPerFaction
	end
	settingsSet = currentSettings
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
	settingsSet = currentSettings
end

function GateSettings.onOwnershipChanged(checkbox)
	Logger:RunFunc("onOwnershipChanged([checkbox]:%s)", checkbox)
	local currentSettings = GateSettingsClient.getSettingsSet()
	currentSettings.AlliancesOnly = checkbox.checked
	settingsSet = currentSettings
end

function GateSettings.onSectorOwnerChanged(checkbox)
	Logger:RunFunc("onSectorOwnerChanged([checkbox]:%s)", checkbox)
	local currentSettings = GateSettingsClient.getSettingsSet()
	currentSettings.ShouldOwnDestinationSector = checkbox.checked
	settingsSet = currentSettings
end

function GateSettings.onClickSaveButton()
	Logger:RunFunc("onClickSaveButton()")
	invokeServerFunction("saveSettingsInServer", settingsSet)
	GateSettingsClient.hideWindow()
end
-- End Events --

-- ============================================================================
-- NOTE: UI private methods have been moved to gatesettings/client.lua module.
-- Server private methods have been moved to gatesettings/server.lua module.
-- ============================================================================

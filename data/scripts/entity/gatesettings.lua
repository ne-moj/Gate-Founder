local entity = Entity()
if not entity or not ((entity.isDrone or entity.isShip or entity.isStation) and not entity.aiOwned) then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

include ("callable")
include ('closurecolors')

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace GateSettings
GateSettings = {}


-- Load --
--local TableShow = include ("tableshow")
local Configs = include ('configs'):new('GateSettings')
local Logger  = include('logger'):new('GateSettings')
local cUI     = include('ui')

local isAdmin = false
-- Data --
local _loadedData = nil

-- UI --
local settingsWindow = nil
local tabbedWindow = nil
local allTabs = nil
local defaultSettings = {
   paddingInWindow = 10,
   heightRow = 40,
   widthNumberBox = 60,
   sizeWindow = vec2(1200, 650),
   distance = {min = 1, max = math.floor(1000 * math.sqrt(2)), step = 15},
}
local settingsSet = {
	MaxDistance = 45,
	MaxGatesPerFaction = 5,
	AlliancesOnly = false,
	ShouldOwnOriginSector = false
}
local activeMenuItems = {
	main = {},
	access = {},
	price = {},
	additional = {}
}

function GateSettings.initialize()
	if onClient() then
		Logger:Debug("Send request to Server - updateSettings()")
        invokeServerFunction("updateSettings")
	end
end

function GateSettings.interactionPossible(playerIndex, option)
    Logger:RunFunc("interactionPossible([playerIndex]:%s, [option]:%s)", playerIndex, option)
    return playerIndex == Player().index and isAdmin or false
end

function GateSettings.onShowWindow()
	Logger:RunFunc("onShowWindow()")
end

function GateSettings.onCloseWindow()
	Logger:RunFunc("onCloseWindow()")
end

function GateSettings.initUI()
    Logger:RunFunc("initUI()")
    local player = Player(callingPlayer)
    
    local res = getResolution()

    local gateUI = ScriptUI()
    local x1y1 = res * 0.5 - defaultSettings.sizeWindow * 0.5
    local x2y2 = res * 0.5 + defaultSettings.sizeWindow * 0.5
    
    settingsWindow = gateUI:createWindow(Rect(x1y1, x2y2))

    settingsWindow.caption = "Gete Settings"..(_loadedData ~= nil and _loadedData.Settings ~= nil and '. Version: '..tostring(_loadedData.Settings._version) or '')
    settingsWindow.showCloseButton = 1
    settingsWindow.moveable = 1
    gateUI:registerWindow(settingsWindow, "GateSettings");
    
    -- create a tabbed window inside the main window
    tabbedWindow = settingsWindow:createTabbedWindow(Rect(vec2(defaultSettings.paddingInWindow, defaultSettings.paddingInWindow), defaultSettings.sizeWindow - defaultSettings.paddingInWindow))
    
    allTabs = GateSettings._createTabs()
    
--    local mainTabWindow = allTabs.main:createTabbedWindow(Rect(allTabs.main.rect.size))
    GateSettings:_populateMainTab()
    
--    local accessTabWindow = allTabs.access:createTabbedWindow(Rect(allTabs.access.rect.size))
    GateSettings:_populateAccessTab()
    
--    local priceTabWindow = allTabs.price:createTabbedWindow(Rect(allTabs.price.rect.size))
end

function GateSettings.getIcon()
    Logger:RunFunc("getIcon()")
	return "data/textures/icons/gate.png"
end

function GateSettings.secure ()
    Logger:RunFunc("secure()")
	return GateSettings:_uploadSettings()
end

function GateSettings.restore (values)
    Logger:RunFunc("restore([values]:%s)", values)
	--GateSettings.updateSettings ()
end

-- My callback --
if onServer() then
	function GateSettings.updateSettings ()
		Logger:RunFunc("updateSettings()")
		local player = Player(callingPlayer)
		local data = GateSettings:_uploadSettings()
		if player == nil then
			-- call Admin from server --
			local allPlayers = {Sector():getPlayers()} -- Получаем всех игроков в секторе
			for _, player in pairs(allPlayers) do
				if Server():hasAdminPrivileges(player) then
					invokeClientFunction(player, "updateClientData", data, Server():hasAdminPrivileges(player))
				end
			end
		elseif Server():hasAdminPrivileges(player) then
			-- call from client and player is admin
			invokeClientFunction(player, "updateClientData", data, Server():hasAdminPrivileges(player))
		end
	end
	callable(GateSettings, "updateSettings")
end

if onClient() then
	function GateSettings.updateClientData (settings, youIsAdmin)
		Logger:RunFunc("updateClientData([settings]:%s, [youIsAdmin]:%s)", settings, youIsAdmin)
		isAdmin = youIsAdmin
		
		if not settings then return end
		_loadedData = settings
		
		if settings.Settings ~= nil then
			settingsSet = settings.Settings
			
			GateSettings._updateUI()
			Entity():addScript('gatesettings.lua') -- this recall interactionPossible() with update data
		end
	end
	callable(GateSettings, "updateClientData")
end

-- The function is called on the Server and the result comes to the Client
-- Server: firstParam - settings
-- Client: firstParam - table with response {isSave, [errorMessage]}
function GateSettings.saveSettingsInServer(firstParam)
	Logger:RunFunc("saveSettingsInServer([firstParam]:%s)", firstParam)
    if onClient() then
        -- Client --
        if firstParam == nil then
            ScriptUI():interactShowDialog({ text = "Error! Don't save settings"%_t })
        elseif not firstParam.isSave then
            if firstParam.errorMessage then
                ScriptUI():interactShowDialog({ text = 'Error! '%_t..tostring(firstParam.errorMessage) })
            else
                ScriptUI():interactShowDialog({ text = "Error! Don't save settings"%_t })
            end
        else
            ScriptUI():interactShowDialog({ text = 'Success! Settings saved'%_t })
        end
    else
        -- Server --
        local player = Player(callingPlayer)
        
        if not Server():hasAdminPrivileges(player) then
            invokeClientFunction(player, "saveSettingsInServer", {
                isSave = false,
                errorMessage = "You do not have permission to perform this operation."%_t
            })
            return
        end
        
        if not firstParam then
            invokeClientFunction(player, "saveSettingsInServer", {
                isSave = false,
                errorMessage = "No data transferred for saving."%_t
            })
            return
        end
        
        GateSettings:_uploadSettings()
        
        _loadedData = _loadedData ~= nil and _loadedData or {}
        _loadedData.Settings = _loadedData.Settings ~= nil and _loadedData.Settings or {}
        
        -- Update Settings (add/update new params)
        for k, v in pairs(firstParam) do
            _loadedData.Settings[k] = v
        end
        
        GateSettings._saveSettings()
        
        invokeClientFunction(player, "saveSettingsInServer", {isSave = true})
    end
end
callable(GateSettings, "saveSettingsInServer")
-- End My callback --

-- Events --
function GateSettings.onMaxDistanceSliderChanged (slider)
	Logger:RunFunc("onMaxDistanceSliderChanged([slider]:%s)", slider)
	GateSettings._onMaxDistanceChanged(tostring(math.floor(slider.value)))
end

function GateSettings.onMaxDistanceBoxChanged (textbox)
	Logger:RunFunc("onMaxDistanceBoxChanged([textbox]:%s)", textbox)
	local val = string.match(textbox.text, '([0-9]+[.]?[0-9]*)')
	if val ~= nil then
		val = tostring(val)
	end
    GateSettings._onMaxDistanceChanged(val)
end

function GateSettings.onClickDistanceButtonMinus ()
	Logger:RunFunc("onClickDistanceButtonMinus()")
    GateSettings._onMaxDistanceChanged(settingsSet.MaxDistance - 1)
end

function GateSettings.onClickDistanceButtonPlus ()
	Logger:RunFunc("onClickDistanceButtonPlus()")
    GateSettings._onMaxDistanceChanged(settingsSet.MaxDistance + 1)
end

function GateSettings.onClickMaxGatesButtonMinus ()
	Logger:RunFunc("onClickMaxGatesButtonMinus()")
	if settingsSet.MaxGatesPerFaction >= 2 then
		settingsSet.MaxGatesPerFaction = settingsSet.MaxGatesPerFaction - 1
	else
		settingsSet.MaxGatesPerFaction = 1
	end
    activeMenuItems.main.maxGatesBox.text = settingsSet.MaxGatesPerFaction
end

function GateSettings.onClickMaxGatesButtonPlus ()
	Logger:RunFunc("onClickMaxGatesButtonPlus()")
    settingsSet.MaxGatesPerFaction = settingsSet.MaxGatesPerFaction + 1
    activeMenuItems.main.maxGatesBox.text = settingsSet.MaxGatesPerFaction
end

function GateSettings.onMaxGatesChanged (textbox)
	Logger:RunFunc("onMaxGatesChanged([textbox]:%s)", textbox)
	if textbox.text ~= '' then
		settingsSet.MaxGatesPerFaction = tonumber(textbox.text) or settingsSet.MaxGatesPerFaction
		activeMenuItems.main.maxGatesBox.text = settingsSet.MaxGatesPerFaction
    else
    	settingsSet.MaxGatesPerFaction = 1
		activeMenuItems.main.maxGatesBox.text = settingsSet.MaxGatesPerFaction
    end
end

function GateSettings.onAllianceOwnershipChanged (checkbox)
	Logger:RunFunc("onAllianceOwnershipChanged([checkbox]:%s)", checkbox)
    settingsSet.AlliancesOnly = checkbox.checked
end

function GateSettings.onSectorOwnerChanged (checkbox)
	Logger:RunFunc("onSectorOwnerChanged([checkbox]:%s)", checkbox)
    settingsSet.ShouldOwnDestinationSector = checkbox.checked
end

function GateSettings.onClickSaveButton()
	Logger:RunFunc("onClickSaveButton()")
	invokeServerFunction("saveSettingsInServer", settingsSet)
	settingsWindow:hide()
end
-- End Events --

-- Private methods --
if onClient() then
	-- Client --
	function GateSettings._onMaxDistanceChanged (value)
		Logger:RunFunc("_onMaxDistanceChanged([value]:%s)", value)
		if value == nil or tonumber(value) == nil then
			settingsSet.MaxDistance = defaultSettings.distance.min
		elseif tonumber(value) < defaultSettings.distance.min then
			settingsSet.MaxDistance = defaultSettings.distance.min
			value = tostring(defaultSettings.distance.min)
		elseif tonumber(value) > defaultSettings.distance.max then
			settingsSet.MaxDistance = defaultSettings.distance.max
			value = tostring(defaultSettings.distance.max)
		else
			settingsSet.MaxDistance = tonumber(value)
		end
		
		if activeMenuItems.main.distanceSlider then
			local colorSlider = activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance)
			activeMenuItems.main.distanceSlider:setValueNoCallback(settingsSet.MaxDistance)
			activeMenuItems.main.distanceSlider.color = colorSlider
			activeMenuItems.main.distanceSlider.glowColor = colorSlider
		end
		
		if activeMenuItems.main.distanceBox then
			activeMenuItems.main.distanceBox.text = (value ~= nil and value or '')
		end
	end

	function GateSettings._createTabs ()
		Logger:RunFunc("_createTabs()")
		local outputTable = {}
		
		if tabbedWindow == nil then
			Logger:Warning('The tabbedWindow obj is nil')
		end
		
		outputTable.main       = tabbedWindow:createTab('Main'%_t,       'data/textures/icons/map-fragment.png',    'Main Settings'%_t)
		outputTable.access     = tabbedWindow:createTab('Access'%_t,     'data/textures/icons/hacking-tool.png',    'Access and Ownership'%_t)
		outputTable.price      = tabbedWindow:createTab('Price'%_t,      'data/textures/icons/sell.png',            'Price'%_t)
		outputTable.additional = tabbedWindow:createTab('Additional'%_t, 'data/textures/icons/procure-command.png', 'Additional Settings'%_t)
		
		return outputTable
	end

	function GateSettings._populateMainTab()
		Logger:RunFunc("_populateMainTab()")
		
		-- DISTANCE --
		local distanceIconUI     = cUI:new('distanceIcon')
		local distanceTextBoxUI  = cUI:new('distanceTextBox')
		local distanceSliderUI   = cUI:new('distanceSlider')
		local distanceBGSliderUI = cUI:new('distanceBackgroundIconSlider')
		local distanceButtonMinusUI = cUI:new('distanceButtonMinus')
		local distanceBoxUI         = cUI:new('distanceBox')
		local distanceButtonPlusUI  = cUI:new('distanceButtonPlus')
		
		distanceIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
		distanceIconUI:updatePadding(defaultSettings.paddingInWindow)
		distanceIconUI:updatePosition(vec2(0, 0), nil)
		
		local additionalPaddingForText = (defaultSettings.heightRow - 14) / 2
		distanceTextBoxUI:updateSize(100, defaultSettings.heightRow)
		distanceTextBoxUI:updatePadding({left = 0, top = defaultSettings.paddingInWindow + additionalPaddingForText, bottom = defaultSettings.paddingInWindow + additionalPaddingForText, right = 0})
		distanceTextBoxUI:updatePosition(distanceIconUI:getPositions().topRight, nil)
		
		
		-- Minus button --
		distanceButtonMinusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
		distanceButtonMinusUI:updatePadding({left = defaultSettings.paddingInWindow, top = defaultSettings.paddingInWindow + 5, bottom = defaultSettings.paddingInWindow + 5, right = 5})
		distanceButtonMinusUI:updatePosition(distanceTextBoxUI:getPositions().topRight)
		
		-- box --
		distanceBoxUI:updateSize(defaultSettings.widthNumberBox, defaultSettings.heightRow)
		distanceBoxUI:updatePadding({left = 5, top = defaultSettings.paddingInWindow, bottom = defaultSettings.paddingInWindow, right = 5})
		distanceBoxUI:updatePosition(distanceButtonMinusUI:getPositions().topRight)
		
		-- Plus button --
		distanceButtonPlusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
		distanceButtonPlusUI:updatePadding({left = 5, top = defaultSettings.paddingInWindow + 5, bottom = defaultSettings.paddingInWindow + 5, right = defaultSettings.paddingInWindow})
		distanceButtonPlusUI:updatePosition(distanceBoxUI:getPositions().topRight)
		
		local postionBox = distanceButtonPlusUI:getPositions()
		distanceSliderUI:updatePosition(postionBox.topRight, vec2(allTabs.main.rect.size.x, distanceBoxUI:getPositions().bottomRight.y))
		distanceSliderUI:updatePadding(defaultSettings.paddingInWindow)
		distanceBGSliderUI:updatePosition(postionBox.topRight, vec2(allTabs.main.rect.size.x, distanceBoxUI:getPositions().bottomRight.y))
		distanceSliderUI:updatePadding(0)
		
		-- create Icon --
		activeMenuItems.main.distanceIcon = allTabs.main:createPicture(distanceIconUI:getRect(), "data/textures/icons/horizontal-flip.png")
		activeMenuItems.main.distanceIcon.isIcon = true
		activeMenuItems.main.distanceIcon.tooltip = "Distance"%_t
		
		-- create TextBox --
		activeMenuItems.main.distanceTextBox = allTabs.main:createTextField(distanceTextBoxUI:getRect(), "Distance"%_t..':')
		activeMenuItems.main.distanceTextBox.padding = 0
		activeMenuItems.main.distanceTextBox.outlined = true
		activeMenuItems.main.distanceTextBox.scrollable = false
		activeMenuItems.main.distanceTextBox.bold = true
		activeMenuItems.main.distanceTextBox.fontSize = 14
		
		-- create Plus, Minus buttons --
		activeMenuItems.main.maxGatesButtonMinus = allTabs.main:createButton(distanceButtonMinusUI:getRect(), '-', 'onClickDistanceButtonMinus')
		activeMenuItems.main.maxGatesButtonPlus = allTabs.main:createButton(distanceButtonPlusUI:getRect(), '+', 'onClickDistanceButtonPlus')
		
		-- create Box --
		activeMenuItems.main.distanceBox = allTabs.main:createTextBox(distanceBoxUI:getRect(), "onMaxDistanceBoxChanged")
		activeMenuItems.main.distanceBox.text = tostring(settingsSet.MaxDistance)
		activeMenuItems.main.distanceBox.tooltip = "Set the maximum distance between the gates"%_t
		
		-- create Slider --
		activeMenuItems.main.distanceBackgroundSliderIcon = allTabs.main:createPicture(distanceSliderUI:getRect(), "data/textures/icons/story-mission.png")
		activeMenuItems.main.distanceBackgroundSliderIcon.color = ColorARGB(0.1, 1, 1, 1)
		activeMenuItems.main.distanceBackgroundSliderIcon.isIcon = true
		activeMenuItems.main.distanceBackgroundSliderIcon.layer = 1
		
		activeMenuItems.main.distanceSliderColorFunction = ClosureColorsByDistantion({'magenta', 'cyan', 'yellow'}, defaultSettings.distance.min, defaultSettings.distance.max, true)
		local colorSlider = activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance)
		
		activeMenuItems.main.distanceSlider = allTabs.main:createSlider(distanceSliderUI:getRect(), defaultSettings.distance.min, defaultSettings.distance.max, math.floor(defaultSettings.distance.max / defaultSettings.distance.step), "Max Distance"%_t, "onMaxDistanceSliderChanged")
		activeMenuItems.main.distanceSlider.value = settingsSet.MaxDistance
		activeMenuItems.main.distanceSlider.color = colorSlider
		activeMenuItems.main.distanceSlider.glowColor = colorSlider
		activeMenuItems.main.distanceSlider.tooltip = "Set the maximum distance between the gates"%_t
		activeMenuItems.main.distanceSlider.showCaption = false
		activeMenuItems.main.distanceSlider.showValue = false
		activeMenuItems.main.distanceSlider.layer = 2
		
		
		-- END DISTANCE --
		
		-- MAX GATES --
		local maxGatesIconUI        = cUI:new('maxGatesIcon')
		local maxGatesTextBoxUI     = cUI:new('maxGatesTextBox')
		local maxGatesButtonMinusUI = cUI:new('maxGatesButtonMinus')
		local maxGatesBoxUI         = cUI:new('maxGatesBox')
		local maxGatesButtonPlusUI  = cUI:new('maxGatesButtonPlus')
		
		-- Icon --
		maxGatesIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
		maxGatesIconUI:updatePadding(defaultSettings.paddingInWindow)
		maxGatesIconUI:updatePosition(distanceIconUI:getPositions().bottomLeft, nil)
		
		-- TextBox --
		local additionalPaddingForText = (defaultSettings.heightRow - 14) / 2
		maxGatesTextBoxUI:updateSize(120, defaultSettings.heightRow)
		maxGatesTextBoxUI:updatePadding({left = 0, top = defaultSettings.paddingInWindow + additionalPaddingForText, bottom = defaultSettings.paddingInWindow + additionalPaddingForText, right = 0})
		maxGatesTextBoxUI:updatePosition(maxGatesIconUI:getPositions().topRight, nil)
		
		-- Minus button --
		maxGatesButtonMinusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
		maxGatesButtonMinusUI:updatePadding({left = defaultSettings.paddingInWindow, top = defaultSettings.paddingInWindow + 5, bottom = defaultSettings.paddingInWindow + 5, right = 5})
		maxGatesButtonMinusUI:updatePosition(distanceButtonMinusUI:getPositions().bottomLeft)
		
		-- box --
		maxGatesBoxUI:updateSize(defaultSettings.widthNumberBox, defaultSettings.heightRow)
		maxGatesBoxUI:updatePadding({left = 5, top = defaultSettings.paddingInWindow, bottom = defaultSettings.paddingInWindow, right = 5})
		maxGatesBoxUI:updatePosition(maxGatesButtonMinusUI:getPositions().topRight)
		
		-- Plus button --
		maxGatesButtonPlusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
		maxGatesButtonPlusUI:updatePadding({left = 5, top = defaultSettings.paddingInWindow + 5, bottom = defaultSettings.paddingInWindow + 5, right = defaultSettings.paddingInWindow})
		maxGatesButtonPlusUI:updatePosition(maxGatesBoxUI:getPositions().topRight)
		
		-- create Icon --
		activeMenuItems.main.maxGatesIcon = allTabs.main:createPicture(maxGatesIconUI:getRect(), "data/textures/icons/show-gate.png")
		activeMenuItems.main.maxGatesIcon.isIcon = true
		activeMenuItems.main.maxGatesIcon.tooltip = "Max gates"%_t
		
		-- create TextBox --
		activeMenuItems.main.maxGatesTextBox = allTabs.main:createTextField(maxGatesTextBoxUI:getRect(), "Max gates"%_t..':')
		activeMenuItems.main.maxGatesTextBox.padding = 0
		activeMenuItems.main.maxGatesTextBox.outlined = true
		activeMenuItems.main.maxGatesTextBox.scrollable = false
		activeMenuItems.main.maxGatesTextBox.bold = true
		activeMenuItems.main.maxGatesTextBox.fontSize = 14
		
		-- create Plus, Minus buttons --
		activeMenuItems.main.maxGatesButtonMinus = allTabs.main:createButton(maxGatesButtonMinusUI:getRect(), '-', 'onClickMaxGatesButtonMinus')
		activeMenuItems.main.maxGatesButtonPlus = allTabs.main:createButton(maxGatesButtonPlusUI:getRect(), '+', 'onClickMaxGatesButtonPlus')
		
		-- create Box --
		activeMenuItems.main.maxGatesBox = allTabs.main:createTextBox(maxGatesBoxUI:getRect(), "onMaxGatesChanged")
		activeMenuItems.main.maxGatesBox.text = tostring(settingsSet.MaxGatesPerFaction)
		activeMenuItems.main.maxGatesBox.tooltip = "Set the maximum number of gates"%_t
		-- END MAX GATES --
		
		activeMenuItems.main.buttonSave = GateSettings._buttonSaveConfigs('main')
	end

	function GateSettings._populateAccessTab()
		Logger:RunFunc("_populateAccessTab()")
		activeMenuItems.access.ownershipCheck = allTabs.access:createCheckBox(Rect(vec2(defaultSettings.paddingInWindow, 10), vec2(400, 30)), "Alliance Ownership Only"%_t, "onAllianceOwnershipChanged")
		activeMenuItems.access.ownershipCheck.captionLeft = false
		activeMenuItems.access.ownershipCheck.checked = settingsSet.AlliancesOnly

		activeMenuItems.access.sectorOwnershipCheck = allTabs.access:createCheckBox(Rect(vec2(defaultSettings.paddingInWindow, 50), vec2(400, 70)), "Sector Owner Can Build"%_t, "onSectorOwnerChanged")
		activeMenuItems.access.sectorOwnershipCheck.captionLeft = false
		activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector
		
		activeMenuItems.access.buttonSave = GateSettings._buttonSaveConfigs('access')
	end

	function GateSettings._buttonSaveConfigs(kTab)
		Logger:RunFunc("_buttonSaveConfigs([kTab]:%s)", kTab)
		if activeMenuItems[kTab] == nil or allTabs[kTab] == nil then
			return nil
		end
		
		local buttonSaveUI = cUI:new('buttonSave')
		
		buttonSaveUI:updateSize(400, defaultSettings.heightRow)
		buttonSaveUI:updatePadding(defaultSettings.paddingInWindow)
		buttonSaveUI:updatePosition(nil, allTabs[kTab].rect.size)
		
		return allTabs[kTab]:createButton(buttonSaveUI:getRect(), 'Save Settings'%_t, 'onClickSaveButton')
	end
	
	function GateSettings._updateUI ()
		Logger:RunFunc("_updateUI()")
		if settingsWindow ~= nil then
			settingsWindow.caption = "Gete Settings"..(settingsSet.version ~= nil and '. Version: '..tostring(settingsSet.version) or '')
			activeMenuItems.main.distanceSlider:setValueNoCallback(settingsSet.MaxDistance)
			activeMenuItems.main.distanceSlider.color = activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance)
			activeMenuItems.main.distanceBox.text = tostring(settingsSet.MaxDistance)
			activeMenuItems.main.maxGatesBox.text = tostring(settingsSet.MaxGatesPerFaction)
			activeMenuItems.access.ownershipCheck.checked = settingsSet.AlliancesOnly
			activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector
		end
	end
else
	-- Server --
	function GateSettings._uploadSettings()
		Logger:RunFunc("_uploadSettings()")
		if _loadedData == nil then
			_loadedData = Configs:load()
		end
		return _loadedData
	end
	
	function GateSettings._saveSettings()
		Logger:RunFunc("_saveSettings()")
		return _loadedData and Configs:save(_loadedData) or ''
	end
end 
-- End Private methods --


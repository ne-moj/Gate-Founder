--[[
    Gate Settings - Client Module
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Handles all client-side UI for gate settings.
    Creates tabbed interface with Main, Access, Price, Additional tabs.
    
    TABS:
    - Main: MaxDistance, MaxGatesPerFaction
    - Access: AlliancesOnly, ShouldOwnOriginSector
    - Price: (TODO) Pricing parameters
    - Additional: (TODO) Game rules
    
    UI LIBRARY:
    Uses cUI (lib/ui.lua) for positioning and sizing UI elements.
    
    EVENTS:
    All events are routed back to main GateSettings namespace
    for proper Avorion callback handling.
--]]

if not onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local Logger = include("logger"):new("GateSettings:Client")
local GateConfig = include("gate/config")
local cUI = include("ui")

local ClosureColors = include("closurecolors")

local GateSettingsClient = {}
-- Link to parent module
GateSettingsClient.parent = nil

-- ============================================================================
-- STATE
-- ============================================================================

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
    fontSize = 14,
    textBoxWidth = 100,
    plusMinusButtonMargin = 5,
    sliderMargin = 5,
    checkBoxMargin = 5,
    distance = {
        name = "Max Distance" % _t,
        icon = "data/textures/icons/horizontal-flip.png",
        min = 1,
        max = math.floor(1000 * math.sqrt(2))
    },
    distanceSlider = {
        colors = {"green", "yellow", "red"},
        step = 15,
        offIntermediateColor = true,
        icon = "data/textures/icons/story-mission.png"
    },
    maxGates = {
        name = "Max Gates" % _t,
        icon = "data/textures/icons/show-gate.png"
    },
    alliancesOnly = {
        name = "Alliances only can found gates" % _t,
        icon = "data/textures/icons/alliance.png"
    },
    sectorOwnership = {
        name = "Player should have claim sector at destination" % _t,
        icon = "data/textures/icons/station.png"
    }
}

-- Current settings values (synchronized with main module)
local settingsSet = GateConfig:load()

-- Active UI menu items (references to UI elements)
local activeMenuItems = {
    main = {},
    access = {},
    price = {},
    additional = {},
}

-- ============================================================================
-- GETTERS/SETTERS
-- ============================================================================

--[[
    Get default settings
    @return table - Default settings
--]]
function GateSettingsClient.getDefaultSettings()
    return defaultSettings
end

--[[
    Get current settings
    @return table - Current settings
--]]
function GateSettingsClient.getSettingsSet()
    return settingsSet
end

--[[
    Set current settings
    @param newSettings table - New settings
--]]
function GateSettingsClient.setSettingsSet(newSettings)
    if not newSettings then
        return
    end
    settingsSet = newSettings
end

--[[
    Get settings window
    @return UIWindow - Settings window
--]]
function GateSettingsClient.getSettingsWindow()
    return settingsWindow
end

--[[
    Get active menu items
    @return table - Active menu items
--]]
function GateSettingsClient.getActiveMenuItems()
    return activeMenuItems
end

-- ============================================================================
-- UI CREATION
-- ============================================================================

--[[
    Initialize UI
    
    Creates main settings window with tabbed interface.
    Called from GateSettings.initUI()
    
    @return UIWindow - Created settings window
--]]
function GateSettingsClient.initUI()
    Logger:Debug("initUI()")
    
    local res = getResolution()
    local gateUI = ScriptUI()
    local x1y1 = res * 0.5 - defaultSettings.sizeWindow * 0.5
    local x2y2 = res * 0.5 + defaultSettings.sizeWindow * 0.5
    
    GateSettingsClient.parent:updateSettingsFromServer()
    
    settingsWindow = gateUI:createWindow(Rect(x1y1, x2y2))
    
    settingsWindow.caption = "Gate Settings" % _t
    settingsWindow.showCloseButton = 1
    settingsWindow.moveable = 1
    gateUI:registerWindow(settingsWindow, "GateSettings")
    
    -- Create tabbed window
    tabbedWindow = settingsWindow:createTabbedWindow(
        Rect(
            vec2(defaultSettings.paddingInWindow, defaultSettings.paddingInWindow),
            defaultSettings.sizeWindow - defaultSettings.paddingInWindow
        )
    )
    
    -- Create tabs
    allTabs = GateSettingsClient._createTabs()
    
    -- Populate tabs
    GateSettingsClient._populateMainTab()
    GateSettingsClient._populateAccessTab()
    -- TODO: GateSettingsClient._populatePriceTab()
    -- TODO: GateSettingsClient._populateAdditionalTab()
    
    return settingsWindow
end

-- ============================================================================
-- UI UPDATE
-- ============================================================================

--[[
    Update UI with current settings
    Called when settings are received from server
    
    @param newSettingsSet table - New settings values
--]]
function GateSettingsClient.updateUI(newSettingsSet)
    Logger:Debug("updateUI()")
    
    if not newSettingsSet then
        return
    end
    
    settingsSet = newSettingsSet
    
    if settingsWindow ~= nil then
        settingsWindow.caption = "Gate Settings"
            .. (settingsSet.version ~= nil and ". Version: " .. tostring(settingsSet.version) or "")
        
        if activeMenuItems.main.distanceSlider then
            activeMenuItems.main.distanceSlider:setValueNoCallback(settingsSet.MaxDistance)
            activeMenuItems.main.distanceSlider.color =
                activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance)
        end
        
        if activeMenuItems.main.distanceBox then
            activeMenuItems.main.distanceBox.text = tostring(settingsSet.MaxDistance)
        end
        
        if activeMenuItems.main.maxGatesBox then
            activeMenuItems.main.maxGatesBox.text = tostring(settingsSet.MaxGatesPerFaction)
        end
        
        if activeMenuItems.access.alliancesOnlyCheck then
            activeMenuItems.access.alliancesOnlyCheck.checked = settingsSet.AlliancesOnly
        end
        
        if activeMenuItems.access.sectorOwnershipCheck then
            activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector
        end
    end
end

-- ============================================================================
-- TAB CREATION
-- ============================================================================

--[[
    Create all tabs
    @return table - Table with all tab references
--]]
function GateSettingsClient._createTabs()
    Logger:RunFunc("_createTabs()")
    local outputTable = {}
    
    if tabbedWindow == nil then
        Logger:Warning("The tabbedWindow obj is nil")
    end
    
    outputTable.main = tabbedWindow:createTab(
        "Main" % _t,
        "data/textures/icons/map-fragment.png",
        "Main Settings" % _t
    )
    outputTable.access = tabbedWindow:createTab(
        "Access" % _t,
        "data/textures/icons/hacking-tool.png",
        "Access and Ownership" % _t
    )
    outputTable.price = tabbedWindow:createTab(
        "Price" % _t,
        "data/textures/icons/sell.png",
        "Price" % _t
    )
    outputTable.additional = tabbedWindow:createTab(
        "Additional" % _t,
        "data/textures/icons/procure-command.png",
        "Additional Settings" % _t
    )
    
    return outputTable
end

-- ============================================================================
-- MAIN TAB
-- ============================================================================

--[[
    Populate Main tab with distance and max gates controls
--]]
function GateSettingsClient._populateMainTab()
    Logger:RunFunc("_populateMainTab()")
    
    -- DISTANCE --
    local distanceIconUI = GateSettingsClient.createIconUI("distanceIcon", vec2(0, 0))
    local distanceTextBoxUI = GateSettingsClient.createTextBoxUI("distanceTextBox", distanceIconUI:getPositions().topRight)

    local distanceButtonMinusUI = GateSettingsClient.createButtonMinusPlusUI("distanceButtonMinus", distanceTextBoxUI:getPositions().topRight, false)
    local distanceBoxUI = GateSettingsClient.createNumberBoxUI("distanceBox", distanceButtonMinusUI:getPositions().topRight)
    local distanceButtonPlusUI = GateSettingsClient.createButtonMinusPlusUI("distanceButtonPlus", distanceBoxUI:getPositions().topRight, true)

    local sizeSlider = defaultSettings.sizeWindow.x
        - distanceButtonPlusUI:getPositions().topRight.x
        - defaultSettings.paddingInWindow * 3
    
    local distanceSliderUI = GateSettingsClient.createSliderUI("distanceSlider", distanceButtonPlusUI:getPositions().topRight, sizeSlider)
    local distanceSliderBGUI = GateSettingsClient.createSliderUI("distanceSliderBG", distanceButtonPlusUI:getPositions().topRight, sizeSlider)
    
    -- Create UI elements
    allTabs.main:createPicture(distanceIconUI:getRect(), defaultSettings.distance.icon)
    allTabs.main:createLabel(distanceTextBoxUI:getRect(), defaultSettings.distance.name, defaultSettings.fontSize)
    
    activeMenuItems.main.distanceButtonMinus           = allTabs.main:createButton(distanceButtonMinusUI:getRect(), "-", "onClickDistanceButtonMinus")
    activeMenuItems.main.distanceButtonPlus            = allTabs.main:createButton(distanceButtonPlusUI:getRect(), "+", "onClickDistanceButtonPlus")
    activeMenuItems.main.distanceBox                   = allTabs.main:createTextBox(distanceBoxUI:getRect(), "onMaxDistanceBoxChanged")
    activeMenuItems.main.distanceBox.text              = tostring(settingsSet.MaxDistance or GateConfig:get("MaxDistance"))
    activeMenuItems.main.distanceBox.allowedCharacters = "0123456789"
    
    activeMenuItems.main.distanceBackgroundSliderIcon = allTabs.main:createPicture(distanceSliderBGUI:getRect(), defaultSettings.distanceSlider.icon)
    activeMenuItems.main.distanceBackgroundSliderIcon.color = ColorARGB(0.1, 1, 1, 1)
    activeMenuItems.main.distanceBackgroundSliderIcon.isIcon = true
    activeMenuItems.main.distanceBackgroundSliderIcon.layer = 1

    activeMenuItems.main.distanceSliderColorFunction = ClosureColors.byDistance(defaultSettings.distanceSlider.colors, defaultSettings.distance.min, defaultSettings.distance.max, defaultSettings.distanceSlider.offIntermediateColor)
    
    local colorSlider = activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance or GateConfig:get("MaxDistance"))

    activeMenuItems.main.distanceSlider = allTabs.main:createSlider(
        distanceSliderUI:getRect(),
        defaultSettings.distance.min,
        defaultSettings.distance.max,
        math.floor(defaultSettings.distance.max / defaultSettings.distanceSlider.step),
        defaultSettings.distance.name,
        "onMaxDistanceSliderChanged"
    )
    
    activeMenuItems.main.distanceSlider.color = colorSlider
    activeMenuItems.main.distanceSlider.glowColor = colorSlider
    activeMenuItems.main.distanceSlider.tooltip = "Set the maximum distance between the gates" % _t
    activeMenuItems.main.distanceSlider:setValueNoCallback(settingsSet.MaxDistance or GateConfig:get("MaxDistance"))
    activeMenuItems.main.distanceSlider.showCaption = false
    activeMenuItems.main.distanceSlider.showValue = false
    activeMenuItems.main.distanceSlider.layer = 2

    
    -- MAX GATES --
    local maxGatesIconUI = GateSettingsClient.createIconUI("maxGatesIcon", distanceIconUI:getPositions().bottomLeft)
    local maxGatesTextBoxUI = GateSettingsClient.createTextBoxUI("maxGatesTextBox", maxGatesIconUI:getPositions().topRight)
    local maxGatesButtonMinusUI = GateSettingsClient.createButtonMinusPlusUI("maxGatesButtonMinus", maxGatesTextBoxUI:getPositions().topRight, false)
    local maxGatesBoxUI = GateSettingsClient.createNumberBoxUI("maxGatesBox", maxGatesButtonMinusUI:getPositions().topRight)
    local maxGatesButtonPlusUI = GateSettingsClient.createButtonMinusPlusUI("maxGatesButtonPlus", maxGatesBoxUI:getPositions().topRight, true)
    
    -- Create UI elements
    allTabs.main:createPicture(maxGatesIconUI:getRect(), defaultSettings.maxGates.icon)
    allTabs.main:createLabel(maxGatesTextBoxUI:getRect(), defaultSettings.maxGates.name, defaultSettings.fontSize)
    
    activeMenuItems.main.maxGatesButtonMinus           = allTabs.main:createButton(maxGatesButtonMinusUI:getRect(), "-", "onClickMaxGatesButtonMinus")
    activeMenuItems.main.maxGatesButtonPlus            = allTabs.main:createButton(maxGatesButtonPlusUI:getRect(), "+", "onClickMaxGatesButtonPlus")
    activeMenuItems.main.maxGatesBox                   = allTabs.main:createTextBox(maxGatesBoxUI:getRect(), "onMaxGatesChanged")
    activeMenuItems.main.maxGatesBox.text              = tostring(settingsSet.MaxGatesPerFaction or GateConfig:get("MaxGatesPerFaction"))
    activeMenuItems.main.maxGatesBox.allowedCharacters = "0123456789"
    
    -- Create Save button
    GateSettingsClient._createSaveButton("main")
end

-- ============================================================================
-- ACCESS TAB
-- ============================================================================

--[[
    Populate Access tab with alliance and sector ownership checkboxes
--]]
function GateSettingsClient._populateAccessTab()
    Logger:RunFunc("_populateAccessTab()")
    
    -- ALLIANCES ONLY --
    local alliancesOnlyIconUI = GateSettingsClient.createIconUI("alliancesOnlyIcon", vec2(0, 0))
    local alliancesOnlyTextBoxUI = GateSettingsClient.createTextBoxUI("alliancesOnlyTextBox", alliancesOnlyIconUI:getPositions().topRight, 300)
    local alliancesOnlyCheckUI = GateSettingsClient.createCheckBoxUI("alliancesOnlyCheck", alliancesOnlyTextBoxUI:getPositions().topRight)
    
    allTabs.access:createPicture(alliancesOnlyIconUI:getRect(), defaultSettings.alliancesOnly.icon)
    allTabs.access:createLabel(alliancesOnlyTextBoxUI:getRect(), defaultSettings.alliancesOnly.name, defaultSettings.fontSize)
    
    activeMenuItems.access.alliancesOnlyCheck = allTabs.access:createCheckBox(alliancesOnlyCheckUI:getRect(), "", "onAlliancesOnlyChanged")
    activeMenuItems.access.alliancesOnlyCheck.checked = settingsSet.AlliancesOnly or GateConfig:get("AlliancesOnly")
    
    -- SECTOR OWNERSHIP --
    local sectorOwnershipIconUI = GateSettingsClient.createIconUI("sectorOwnershipIcon", alliancesOnlyIconUI:getPositions().bottomLeft)
    local sectorOwnershipTextBoxUI = GateSettingsClient.createTextBoxUI("sectorOwnershipTextBox", sectorOwnershipIconUI:getPositions().topRight, 300)
    local sectorOwnershipCheckUI = GateSettingsClient.createCheckBoxUI("sectorOwnershipCheck", sectorOwnershipTextBoxUI:getPositions().topRight)
    
    allTabs.access:createPicture(sectorOwnershipIconUI:getRect(), defaultSettings.sectorOwnership.icon)
    allTabs.access:createLabel(sectorOwnershipTextBoxUI:getRect(), defaultSettings.sectorOwnership.name, defaultSettings.fontSize)
    activeMenuItems.access.sectorOwnershipCheck = allTabs.access:createCheckBox(sectorOwnershipCheckUI:getRect(), "", "onSectorOwnerChanged")
    activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector or GateConfig:get("ShouldOwnDestinationSector")
    
    -- Create Save button
    GateSettingsClient._createSaveButton("access")
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
    Create Save button in specified tab
    @param kTab string - Tab key ("main", "access", etc.)
    @return UIButton - Created button
--]]
function GateSettingsClient._createSaveButton(kTab)
    Logger:RunFunc("_createSaveButton([kTab]:%s)", kTab)
    
    if not allTabs[kTab] then
        Logger:Warning("Tab not found: %s", kTab)
        return nil
    end
    
    local buttonSaveUI = cUI:new("buttonSave")
    buttonSaveUI:updateSize(400, defaultSettings.heightRow)
    buttonSaveUI:updatePadding(defaultSettings.paddingInWindow)
    buttonSaveUI:updatePosition(nil, allTabs[kTab].rect.size)
    
    return allTabs[kTab]:createButton(buttonSaveUI:getRect(), "Save Settings" % _t, "onClickSaveButton")
end

-- ============================================================================
-- EVENT HANDLERS (called from main module)
-- ============================================================================

--[[
    Handle max distance change
    @param value number|string - New distance value
--]]
function GateSettingsClient.onMaxDistanceChanged(value)
    Logger:RunFunc("onMaxDistanceChanged([value]:%s)", value)
    
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
        activeMenuItems.main.distanceBox.text = (value ~= nil and value or "")
    end
end

--[[
    Hide settings window
--]]
function GateSettingsClient.hideWindow()
    if settingsWindow then
        settingsWindow:hide()
    end
end

--[[
    Create icon UI
    @param iconName string - Icon name
    @param position vec2 - Icon position
    @return UIButton - Created icon UI
    @example
    local iconUI = GateSettingsClient.createIconUI("distanceIcon", position)
--]]
function GateSettingsClient.createIconUI(iconName, position)
    local iconUI = cUI:new(iconName)
    iconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
    iconUI:updatePadding(defaultSettings.paddingInWindow)
    iconUI:updatePosition(position)

    return iconUI
end

--[[
    Create text box UI
    @param textBoxName string - Text box name
    @param position vec2 - Text box position
    @param defaultSize number - Default text box size
    @return UIButton - Created text box UI
    @example
    local textBoxUI = GateSettingsClient.createTextBoxUI("distanceTextBox", position, defaultSize)
--]]
function GateSettingsClient.createTextBoxUI(textBoxName, position, defaultSize)
    local textBoxUI = cUI:new(textBoxName)

    local additionalPaddingForText = (defaultSettings.heightRow - defaultSettings.fontSize) / 2
    textBoxUI:updateSize(defaultSize or defaultSettings.textBoxWidth, defaultSettings.heightRow)
    textBoxUI:updatePadding({
        left = 0,
        top = defaultSettings.paddingInWindow + additionalPaddingForText,
        bottom = defaultSettings.paddingInWindow + additionalPaddingForText,
        right = 0,
    })
    textBoxUI:updatePosition(position)

    return textBoxUI
end

--[[
    Create button minus/plus UI
    @param buttonName string - Button name
    @param position vec2 - Button position
    @param isPlus boolean - Is plus button
    @return UIButton - Created button UI
    @example
    local buttonUI = GateSettingsClient.createButtonMinusPlusUI("distanceButtonMinus", position, false)
--]]
function GateSettingsClient.createButtonMinusPlusUI(buttonName, position, isPlus)
    local buttonUI = cUI:new(buttonName)
    -- Minus button
    buttonUI:updateSize(defaultSettings.heightRow - defaultSettings.plusMinusButtonMargin * 2, defaultSettings.heightRow - defaultSettings.plusMinusButtonMargin * 2)
    buttonUI:updatePadding({
        left = isPlus and defaultSettings.paddingInWindow or defaultSettings.plusMinusButtonMargin,
        top = defaultSettings.paddingInWindow + defaultSettings.plusMinusButtonMargin,
        bottom = defaultSettings.paddingInWindow + defaultSettings.plusMinusButtonMargin,
        right = isPlus and defaultSettings.plusMinusButtonMargin or defaultSettings.paddingInWindow,
    })
    buttonUI:updatePosition(position)

    return buttonUI
end

--[[
    Create number box UI
    @param numberBoxName string - Number box name
    @param position vec2 - Number box position
    @return UIButton - Created number box UI
    @example
    local numberBoxUI = GateSettingsClient.createNumberBoxUI("distanceNumberBox", position)
--]]
function GateSettingsClient.createNumberBoxUI(numberBoxName, position)
    local numberBoxUI = cUI:new(numberBoxName)
    numberBoxUI:updateSize(defaultSettings.widthNumberBox, defaultSettings.heightRow)
    numberBoxUI:updatePadding({
        left = defaultSettings.plusMinusButtonMargin,
        top = defaultSettings.paddingInWindow,
        bottom = defaultSettings.paddingInWindow,
        right = defaultSettings.plusMinusButtonMargin,
    })
    numberBoxUI:updatePosition(position)

    return numberBoxUI
end

function GateSettingsClient.createSliderUI(sliderName, position, sizeSlider)
    local sliderUI = cUI:new(sliderName)

    sliderUI:updateSize(sizeSlider, defaultSettings.heightRow - defaultSettings.sliderMargin * 2)
    sliderUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + defaultSettings.sliderMargin,
        bottom = defaultSettings.paddingInWindow + defaultSettings.sliderMargin,
        right = defaultSettings.paddingInWindow,
    })
    sliderUI:updatePosition(position) 

    return sliderUI
end

--[[
    Create check box UI
    @param checkBoxName string - Check box name
    @param position vec2 - Check box position
    @return UIButton - Created check box UI
    @example
    local checkBoxUI = GateSettingsClient.createCheckBoxUI("alliancesOnlyCheck", position)
--]]
function GateSettingsClient.createCheckBoxUI(checkBoxName, position)
    local checkBoxUI = cUI:new(checkBoxName)
    checkBoxUI:updateSize(defaultSettings.heightRow - defaultSettings.checkBoxMargin * 2, defaultSettings.heightRow - defaultSettings.checkBoxMargin)
    checkBoxUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + defaultSettings.checkBoxMargin,
        bottom = defaultSettings.paddingInWindow + defaultSettings.checkBoxMargin,
        right = 0,
    })
    checkBoxUI:updatePosition(position)

    return checkBoxUI
end
-- End Events --

return GateSettingsClient
package.path = package.path .. ";data/scripts/lib/?.lua"

local Logger = include("logger"):new("GateSettings:Client")
local cUI = include("ui")

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

include("closurecolors")

local GateSettingsClient = {}

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
    distance = { min = 1, max = math.floor(1000 * math.sqrt(2)), step = 15 },
}

-- Current settings values (synchronized with main module)
local settingsSet = {}

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
    
    @param loadedData table - Loaded settings data
    @return UIWindow - Created settings window
--]]
function GateSettingsClient.initUI(loadedData)
    Logger:RunFunc("initUI()")
    
    local res = getResolution()
    local gateUI = ScriptUI()
    local x1y1 = res * 0.5 - defaultSettings.sizeWindow * 0.5
    local x2y2 = res * 0.5 + defaultSettings.sizeWindow * 0.5
    
    settingsWindow = gateUI:createWindow(Rect(x1y1, x2y2))
    
    settingsWindow.caption = "Gate Settings"
        .. (
            loadedData ~= nil
                and loadedData.Settings ~= nil
                and ". Version: " .. tostring(loadedData.Settings._version)
            or ""
        )
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
    local distanceIconUI = cUI:new("distanceIcon")
    local distanceTextBoxUI = cUI:new("distanceTextBox")
    local distanceSliderUI = cUI:new("distanceSlider")
    local distanceBGSliderUI = cUI:new("distanceBackgroundIconSlider")
    local distanceButtonMinusUI = cUI:new("distanceButtonMinus")
    local distanceBoxUI = cUI:new("distanceBox")
    local distanceButtonPlusUI = cUI:new("distanceButtonPlus")
    
    distanceIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
    distanceIconUI:updatePadding(defaultSettings.paddingInWindow)
    distanceIconUI:updatePosition(vec2(0, 0), nil)
    
    local additionalPaddingForText = (defaultSettings.heightRow - 14) / 2
    distanceTextBoxUI:updateSize(100, defaultSettings.heightRow)
    distanceTextBoxUI:updatePadding({
        left = 0,
        top = defaultSettings.paddingInWindow + additionalPaddingForText,
        bottom = defaultSettings.paddingInWindow + additionalPaddingForText,
        right = 0,
    })
    distanceTextBoxUI:updatePosition(distanceIconUI:getPositions().topRight, nil)
    
    -- Minus button
    distanceButtonMinusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    distanceButtonMinusUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = 5,
    })
    distanceButtonMinusUI:updatePosition(distanceTextBoxUI:getPositions().topRight)
    
    -- Box
    distanceBoxUI:updateSize(defaultSettings.widthNumberBox, defaultSettings.heightRow)
    distanceBoxUI:updatePadding({
        left = 5,
        top = defaultSettings.paddingInWindow,
        bottom = defaultSettings.paddingInWindow,
        right = 5,
    })
    distanceBoxUI:updatePosition(distanceButtonMinusUI:getPositions().topRight)
    
    -- Plus button
    distanceButtonPlusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    distanceButtonPlusUI:updatePadding({
        left = 5,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = defaultSettings.paddingInWindow,
    })
    distanceButtonPlusUI:updatePosition(distanceBoxUI:getPositions().topRight)
    
    -- Slider and background
    local sizeSlider = defaultSettings.sizeWindow.x
        - distanceButtonPlusUI:getPositions().topRight.x
        - defaultSettings.paddingInWindow * 3
    
    distanceSliderUI:updateSize(sizeSlider, defaultSettings.heightRow - 10)
    distanceSliderUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = defaultSettings.paddingInWindow,
    })
    distanceSliderUI:updatePosition(distanceButtonPlusUI:getPositions().topRight) 

    activeMenuItems.main.distanceSliderColorFunction = ClosureColorsByDistantion({'magenta', 'cyan', 'yellow'}, defaultSettings.distance.min, defaultSettings.distance.max, true)
    distanceBGSliderUI:updateSize(sizeSlider, defaultSettings.heightRow - 10)
    distanceBGSliderUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = defaultSettings.paddingInWindow,
    })
    distanceBGSliderUI:updatePosition(distanceButtonPlusUI:getPositions().topRight)
    
    -- Create UI elements
    allTabs.main:createPicture(distanceIconUI:getRect(), "data/textures/icons/horizontal-flip.png")
    allTabs.main:createLabel(distanceTextBoxUI:getRect(), "Max Distance" % _t, 14)
    
    activeMenuItems.main.distanceButtonMinus = allTabs.main:createButton(
        distanceButtonMinusUI:getRect(),
        "-",
        "onClickDistanceButtonMinus"
    )
    
    activeMenuItems.main.distanceBox = allTabs.main:createTextBox(
        distanceBoxUI:getRect(),
        "onMaxDistanceBoxChanged"
    )
    activeMenuItems.main.distanceBox.text = tostring(settingsSet.MaxDistance or 45)
    activeMenuItems.main.distanceBox.allowedCharacters = "0123456789"
    
    activeMenuItems.main.distanceButtonPlus = allTabs.main:createButton(
        distanceButtonPlusUI:getRect(),
        "+",
        "onClickDistanceButtonPlus"
    )
    
    activeMenuItems.main.distanceBackgroundSliderIcon = allTabs.main:createPicture(distanceSliderUI:getRect(), "data/textures/icons/story-mission.png")
    activeMenuItems.main.distanceBackgroundSliderIcon.color = ColorARGB(0.1, 1, 1, 1)
    activeMenuItems.main.distanceBackgroundSliderIcon.isIcon = true
    activeMenuItems.main.distanceBackgroundSliderIcon.layer = 1

    activeMenuItems.main.distanceSliderColorFunction = ClosureColorsByDistantion(
        {"green", "yellow", "red"},
        defaultSettings.distance.min,
        defaultSettings.distance.max,
        true
    )
    
    local colorSlider = activeMenuItems.main.distanceSliderColorFunction(settingsSet.MaxDistance or 45)

    activeMenuItems.main.distanceSlider = allTabs.main:createSlider(
        distanceSliderUI:getRect(),
        defaultSettings.distance.min,
        defaultSettings.distance.max,
        math.floor(defaultSettings.distance.max / defaultSettings.distance.step),
        "Max Distance"%_t,
        "onMaxDistanceSliderChanged"
    )
    
    activeMenuItems.main.distanceSlider.color = colorSlider
    activeMenuItems.main.distanceSlider.glowColor = colorSlider
    activeMenuItems.main.distanceSlider.tooltip = "Set the maximum distance between the gates"%_t
    activeMenuItems.main.distanceSlider:setValueNoCallback(settingsSet.MaxDistance or 45)
    activeMenuItems.main.distanceSlider.showCaption = false
    activeMenuItems.main.distanceSlider.showValue = false
    activeMenuItems.main.distanceSlider.layer = 2

    
    -- MAX GATES --
    local maxGatesIconUI = cUI:new("maxGatesIcon")
    local maxGatesTextBoxUI = cUI:new("maxGatesTextBox")
    local maxGatesButtonMinusUI = cUI:new("maxGatesButtonMinus")
    local maxGatesBoxUI = cUI:new("maxGatesBox")
    local maxGatesButtonPlusUI = cUI:new("maxGatesButtonPlus")
    
    maxGatesIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
    maxGatesIconUI:updatePadding(defaultSettings.paddingInWindow)
    maxGatesIconUI:updatePosition(distanceIconUI:getPositions().bottomLeft, nil)
    
    maxGatesTextBoxUI:updateSize(100, defaultSettings.heightRow)
    maxGatesTextBoxUI:updatePadding({
        left = 0,
        top = defaultSettings.paddingInWindow + additionalPaddingForText,
        bottom = defaultSettings.paddingInWindow + additionalPaddingForText,
        right = 0,
    })
    maxGatesTextBoxUI:updatePosition(maxGatesIconUI:getPositions().topRight, nil)
    
    maxGatesButtonMinusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    maxGatesButtonMinusUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = 5,
    })
    maxGatesButtonMinusUI:updatePosition(maxGatesTextBoxUI:getPositions().topRight)
    
    maxGatesBoxUI:updateSize(defaultSettings.widthNumberBox, defaultSettings.heightRow)
    maxGatesBoxUI:updatePadding({
        left = 5,
        top = defaultSettings.paddingInWindow,
        bottom = defaultSettings.paddingInWindow,
        right = 5,
    })
    maxGatesBoxUI:updatePosition(maxGatesButtonMinusUI:getPositions().topRight)
    
    maxGatesButtonPlusUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    maxGatesButtonPlusUI:updatePadding({
        left = 5,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = defaultSettings.paddingInWindow,
    })
    maxGatesButtonPlusUI:updatePosition(maxGatesBoxUI:getPositions().topRight)
    
    -- Create UI elements
    allTabs.main:createPicture(maxGatesIconUI:getRect(), "data/textures/icons/show-gate.png")
    allTabs.main:createLabel(maxGatesTextBoxUI:getRect(), "Max Gates" % _t, 14)
    
    activeMenuItems.main.maxGatesButtonMinus = allTabs.main:createButton(
        maxGatesButtonMinusUI:getRect(),
        "-",
        "onClickMaxGatesButtonMinus"
    )
    
    activeMenuItems.main.maxGatesBox = allTabs.main:createTextBox(
        maxGatesBoxUI:getRect(),
        "onMaxGatesChanged"
    )
    activeMenuItems.main.maxGatesBox.text = tostring(settingsSet.MaxGatesPerFaction or 5)
    activeMenuItems.main.maxGatesBox.allowedCharacters = "0123456789"
    
    activeMenuItems.main.maxGatesButtonPlus = allTabs.main:createButton(
        maxGatesButtonPlusUI:getRect(),
        "+",
        "onClickMaxGatesButtonPlus"
    )
    
    -- Create Save button
    GateSettingsClient._createSaveButton("main")
end

-- ============================================================================
-- ACCESS TAB
-- ============================================================================

--[[
    Populate Access tab with ownership and alliance checkboxes
--]]
function GateSettingsClient._populateAccessTab()
    Logger:RunFunc("_populateAccessTab()")
    
    -- ALLIANCES ONLY --
    local ownershipIconUI = cUI:new("ownershipIcon")
    local ownershipTextBoxUI = cUI:new("ownershipTextBox")
    local ownershipCheckUI = cUI:new("ownershipCheck")
    
    ownershipIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
    ownershipIconUI:updatePadding(defaultSettings.paddingInWindow)
    ownershipIconUI:updatePosition(vec2(0, 0), nil)
    
    local additionalPaddingForText = (defaultSettings.heightRow - 14) / 2
    ownershipTextBoxUI:updateSize(300, defaultSettings.heightRow)
    ownershipTextBoxUI:updatePadding({
        left = 0,
        top = defaultSettings.paddingInWindow + additionalPaddingForText,
        bottom = defaultSettings.paddingInWindow + additionalPaddingForText,
        right = 0,
    })
    ownershipTextBoxUI:updatePosition(ownershipIconUI:getPositions().topRight, nil)
    
    ownershipCheckUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    ownershipCheckUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = 0,
    })
    ownershipCheckUI:updatePosition(ownershipTextBoxUI:getPositions().topRight, nil)
    
    allTabs.access:createPicture(ownershipIconUI:getRect(), "data/textures/icons/alliance.png")
    allTabs.access:createLabel(ownershipTextBoxUI:getRect(), "Alliances only can found gates" % _t, 14)
    
    activeMenuItems.access.ownershipCheck = allTabs.access:createCheckBox(
        ownershipCheckUI:getRect(),
        "",
        "onOwnershipChanged"
    )
    activeMenuItems.access.ownershipCheck.checked = settingsSet.AlliancesOnly or false
    
    -- SECTOR OWNERSHIP --
    local sectorOwnershipIconUI = cUI:new("sectorOwnershipIcon")
    local sectorOwnershipTextBoxUI = cUI:new("sectorOwnershipTextBox")
    local sectorOwnershipCheckUI = cUI:new("sectorOwnershipCheck")
    
    sectorOwnershipIconUI:updateSize(defaultSettings.heightRow, defaultSettings.heightRow)
    sectorOwnershipIconUI:updatePadding(defaultSettings.paddingInWindow)
    sectorOwnershipIconUI:updatePosition(ownershipIconUI:getPositions().bottomLeft, nil)
    
    sectorOwnershipTextBoxUI:updateSize(300, defaultSettings.heightRow)
    sectorOwnershipTextBoxUI:updatePadding({
        left = 0,
        top = defaultSettings.paddingInWindow + additionalPaddingForText,
        bottom = defaultSettings.paddingInWindow + additionalPaddingForText,
        right = 0,
    })
    sectorOwnershipTextBoxUI:updatePosition(sectorOwnershipIconUI:getPositions().topRight, nil)
    
    sectorOwnershipCheckUI:updateSize(defaultSettings.heightRow - 10, defaultSettings.heightRow - 10)
    sectorOwnershipCheckUI:updatePadding({
        left = defaultSettings.paddingInWindow,
        top = defaultSettings.paddingInWindow + 5,
        bottom = defaultSettings.paddingInWindow + 5,
        right = 0,
    })
    sectorOwnershipCheckUI:updatePosition(sectorOwnershipTextBoxUI:getPositions().topRight, nil)
    
    allTabs.access:createPicture(sectorOwnershipIconUI:getRect(), "data/textures/icons/station.png")
    allTabs.access:createLabel(
        sectorOwnershipTextBoxUI:getRect(),
        "Player should have claim sector at destination" % _t,
        14
    )
    
    activeMenuItems.access.sectorOwnershipCheck = allTabs.access:createCheckBox(
        sectorOwnershipCheckUI:getRect(),
        "",
        "onSectorOwnerChanged"
    )
    activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector or false
    
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
-- UI UPDATE
-- ============================================================================

--[[
    Update UI with current settings
    Called when settings are received from server
    
    @param newSettingsSet table - New settings values
--]]
function GateSettingsClient.updateUI(newSettingsSet)
    Logger:RunFunc("updateUI()")
    
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
        
        if activeMenuItems.access.ownershipCheck then
            activeMenuItems.access.ownershipCheck.checked = settingsSet.AlliancesOnly
        end
        
        if activeMenuItems.access.sectorOwnershipCheck then
            activeMenuItems.access.sectorOwnershipCheck.checked = settingsSet.ShouldOwnDestinationSector
        end
    end
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

return GateSettingsClient

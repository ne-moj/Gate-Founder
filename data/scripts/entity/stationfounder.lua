local PassageMap, Azimuth -- includes
local gateFounder_window, gateFounder_xBox, gateFounder_yBox, gateFounder_coordsLabel, gateFounder_distanceLabel, gateFounder_maxDistanceLabel, gateFounder_priceLabel, gateFounder_foundGateBtn -- UI
local gateFounder_x, gateFounder_y, gateFounder_passageMap -- client
local GateFounderConfig -- client/server
local gateFounder_initUI -- overriden functions


StationFounder.stations[#StationFounder.stations+1] = {
  isGateFounder = true,
  name = "Gate"%_t,
  tooltip = "Create a gate that will allow ships to travel to a paired gate in another sector. You pay only for the first gate in a pair. Second gate will be created automatically."%_t,
  price = 0
}

if onClient() then


PassageMap = include("passagemap")
include("azimuthlib-uiproportionalsplitter")

gateFounder_passageMap = PassageMap(Seed(GameSettings().seed))

gateFounder_initUI = StationFounder.initUI
function StationFounder.initUI()
    gateFounder_initUI()

    local res = getResolution()
    local menu = ScriptUI()
    local size = vec2(500, 190)
    gateFounder_window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    gateFounder_window.caption = "Transform to Gate"%_t
    gateFounder_window.showCloseButton = 1
    gateFounder_window.moveable = 1
    gateFounder_window.visible = false

    local lister = UIVerticalLister(Rect(size), 7, 10)
    -- Coordinates
    gateFounder_window:createLabel(lister:placeCenter(vec2(lister.inner.width, 20)), "Second gate coordinates"%_t, 14)
    local partitions = UIVerticalProportionalSplitter(lister:placeCenter(vec2(lister.inner.width, 25)), 10, 0, { 0.05, 0.2, 0.05, 0.2, 5, 0.2 })
    gateFounder_window:createLabel(partitions[1].lower + vec2(0, 4), "X:", 14)
    gateFounder_xBox = gateFounder_window:createTextBox(partitions[2], "gateFounder_onCoordinatesChanged")
    gateFounder_xBox.allowedCharacters = "-0123456789"
    gateFounder_window:createLabel(partitions[3].lower + vec2(0, 4), "Y:", 14)
    gateFounder_yBox = gateFounder_window:createTextBox(partitions[4], "gateFounder_onCoordinatesChanged")
    gateFounder_yBox.allowedCharacters = "-0123456789"
    gateFounder_coordsLabel = gateFounder_window:createLabel(Rect(partitions[6].lower + vec2(0, 3), partitions[6].upper), "", 14)
    gateFounder_coordsLabel.centered = true
    gateFounder_coordsLabel.mouseDownFunction = "gateFounder_onCoordinatesPressed"
    -- Current distance / max distance
    local splitter = UIVerticalSplitter(lister:placeCenter(vec2(lister.inner.width, 20)), 10, 0, 0.5)
    gateFounder_distanceLabel = gateFounder_window:createLabel(splitter.left, "Distance: "%_t, 14)
    gateFounder_maxDistanceLabel = gateFounder_window:createLabel(splitter.right, "Max distance: "%_t, 14)
    -- Price
    gateFounder_priceLabel = gateFounder_window:createLabel(lister:placeCenter(vec2(lister.inner.width, 40)), "", 14)
    gateFounder_priceLabel.wordBreak = true
    gateFounder_priceLabel.centered = true
    -- Found
    gateFounder_foundGateBtn = gateFounder_window:createButton(lister:placeCenter(vec2(200, 30)), "Transform"%_t, "gateFounder_onFoundButtonPressed")
    gateFounder_foundGateBtn.active = false
end

local gateFounder_onShowWindow = StationFounder.onShowWindow
function StationFounder.onShowWindow(optionIndex)
    if gateFounder_onShowWindow then gateFounder_onShowWindow(optionIndex) end
    invokeServerFunction("gateFounder_sendSettings")
end

local gateFounder_onFoundStationButtonPress = StationFounder.onFoundStationButtonPress
function StationFounder.onFoundStationButtonPress(button)
    local selectedStation = StationFounder.stationsByButton[button.index]
    local template = StationFounder.stations[selectedStation]

    if not template.isGateFounder then
        gateFounder_onFoundStationButtonPress(button) -- continue vanilla behavior
        return
    end

    gateFounder_window:show()
end

function StationFounder.gateFounder_onCoordinatesChanged()
    if GateFounderConfig.gateCount < 0 then return end

    local tx = tonumber(gateFounder_xBox.text) or 0
    local ty = tonumber(gateFounder_yBox.text) or 0
    gateFounder_x = tx
    gateFounder_y = ty
    gateFounder_coordsLabel.caption = string.format("(%i:%i)", tx, ty)

    local x, y = Sector():getCoordinates()
    local d = distance(vec2(x, y), vec2(tx, ty))
    gateFounder_distanceLabel.caption = "Distance: "%_t .. tonumber(string.format("%.4f", d))
    
    local isError = false
    if x == tx and y == ty then
        gateFounder_priceLabel.caption = "Gates can't lead in the same sector!"%_t
        isError = true
    elseif d > GateFounderConfig.MaxDistance then
        gateFounder_priceLabel.caption = "Distance between gates is too big!"%_t
        isError = true
    elseif not gateFounder_passageMap:passable(tx, ty) then
        gateFounder_priceLabel.caption = "Gates can't lead into rifts!"%_t
        isError = true
    else
        local xyInsideRing = gateFounder_passageMap:insideRing(x, y)
        if xyInsideRing ~= gateFounder_passageMap:insideRing(tx, ty) then
            if not GateFounderConfig.AllowToPassBarrier then
                gateFounder_priceLabel.caption = "Gates can't cross barrier!"%_t
                isError = true
            elseif not xyInsideRing then
                gateFounder_priceLabel.caption = "Gates that cross barrier need to be built from the inner ring!"%_t
                isError = true
            end
        end
    end
    if not isError then
        -- check if sector already has a gate that leads to that sector
        --local gates = {Sector():getEntitiesByScript("data/scripts/entity/gate.lua")}
        local gates = {Sector():getEntitiesByScript("gate.lua")}
        local wormhole, wx, wy
        for i = 1, #gates do
            wormhole = WormHole(gates[i].index)
            wx, wy = wormhole:getTargetCoordinates()
            if wx == tx and wy == ty then
                gateFounder_priceLabel.caption = string.gsub("This sector already has gate that leads in \\s(%i:%i)!"%_t, "\\s", ""):format(tx, ty)
                isError = true
                break
            end
        end
    end
    if not isError then
        local price = math.ceil(d * 30 * Balancing_GetSectorRichnessFactor((x + tx) / 2, (y + ty) / 2))
        price = price * GateFounderConfig.BasePriceMultiplier
        price = price * math.pow(GateFounderConfig.SubsequentGatePriceMultiplier, GateFounderConfig.gateCount)
        price = math.pow(price, math.pow(GateFounderConfig.SubsequentGatePricePower, GateFounderConfig.gateCount))
        price = math.ceil(price)
        gateFounder_priceLabel.caption = createMonetaryString(price) .. " Cr"%_t
    end
    gateFounder_priceLabel.color = isError and ColorRGB(1, 0, 0) or ColorRGB(1, 1, 1)
    gateFounder_foundGateBtn.active = not isError
end

function StationFounder.gateFounder_onCoordinatesPressed()
    GalaxyMap():show(gateFounder_x, gateFounder_y)
end

function StationFounder.gateFounder_onFoundButtonPressed()
    invokeServerFunction("gateFounder_foundGate", gateFounder_x, gateFounder_y)
end

function StationFounder.gateFounder_receiveSettings(data, gateCount)
    data.gateCount = gateCount
    GateFounderConfig = data
    gateFounder_maxDistanceLabel.caption = "Max distance: "%_t .. data.MaxDistance
    
    local isError = false
    if Entity().playerOwned and data.AlliancesOnly then
        gateFounder_priceLabel.caption = "Only alliances can found gates!"%_t
        isError = true
    elseif gateCount == -1 then
        gateFounder_priceLabel.caption = "You don't have permissions to found gates for your alliance."%_t
        isError = true
    elseif gateCount == -2 then
        gateFounder_priceLabel.caption = "Only faction that controls the sector can found gates!"%_t
        isError = true
    elseif gateCount >= data.MaxGatesPerFaction then
        gateFounder_priceLabel.caption = "Reached the maximum amount of founded gates!"%_t
        isError = true
    end
    gateFounder_priceLabel.color = isError and ColorRGB(1, 0, 0) or ColorRGB(1, 1, 1)
    gateFounder_foundGateBtn.active = false
end


else -- onServer


Azimuth, GateFounderConfig = unpack(include("gatefounderinit"))

function StationFounder.gateFounder_sendSettings()
    local buyer, _, player, alliance = getInteractingFaction(callingPlayer)
    if alliance and not alliance:hasPrivilege(callingPlayer, AlliancePrivilege.FoundStations) then
        invokeClientFunction(player, "gateFounder_receiveSettings", GateFounderConfig, -1)
        return
    end
    if GateFounderConfig.ShouldOwnOriginSector then
        local x, y = Sector():getCoordinates()
        local owner = Galaxy():getControllingFaction(x, y)
        if not owner or owner.index ~= buyer.index then
            invokeClientFunction(player, "gateFounder_receiveSettings", GateFounderConfig, -2)
            return
        end
    end
    invokeClientFunction(player, "gateFounder_receiveSettings", GateFounderConfig, buyer:getValue("gates_founded") or 0)
end
callable(StationFounder, "gateFounder_sendSettings")

function StationFounder.gateFounder_foundGate(tx, ty)
    local buyer, _, player = getInteractingFaction(callingPlayer, AlliancePrivilege.FoundStations)
    if not buyer then return end
  
    local status, success = player:invokeFunction("gatefounder.lua", "found", tx, ty, "confirm")
    if status ~= 0 then
        player:sendChatMessage("", 1, "GateFounder: An error has occured, status: " .. status)
        return
    end
    if success then -- remove ship
        player.craftIndex = Uuid()
        local ship = Entity()
        ship.name = ""
        ship:setPlan(BlockPlan())
        buyer:setShipDestroyed("", true)
        buyer:removeDestroyedShipInfo("")
        removeReconstructionTokens(buyer, name)
    end
end
callable(StationFounder, "gateFounder_foundGate")


end
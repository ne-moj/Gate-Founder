if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

local GateRegistry = include("gate/registry")

local function list(playerIndex, args)
    local player = Player(playerIndex)
    if not player then return 1, "", "Player not found" end
    
    local showNearest = false
    local showCurrentSector = false
    local filterRadius = nil
    
    -- Argument Parsing
    for i, arg in ipairs(args) do
        if arg == "help" or arg == "?" then
            return 0, "", [[
Usage: /gate list [options]

Options:
  --nearest           : Sort gates by distance to current sector.
  --radius <dist>     : Show gates within <dist> sectors.
  --sector            : Show only gates in the current sector.
            ]]
        elseif arg == "--nearest" then
            showNearest = true
        elseif arg == "--sector" then
            showCurrentSector = true
        elseif arg == "--radius" then
             local val = args[i+1]
             if val then filterRadius = tonumber(val) end
        end
    end
    
    local x, y = player:getSectorCoordinates()
    if not x or not y then return 1, "", "Could not determine your location." end

    local gates = {}
    local header = ""
    
    if showCurrentSector then
        gates = GateRegistry.getInSector(x, y)
        -- Filter by owner (User can only see their own gates in this view generally, unless we want to show public ones? keeping to own for now)
        local owned = {}
        for _, g in ipairs(gates) do
            if g.owner == player.index then table.insert(owned, g) end
        end
        gates = owned
        header = string.format("[Your Gates in Sector (%d, %d)]:\n", x, y)
    elseif showNearest or filterRadius then
        -- Default radius to infinite if not specified (just sorting by distance)
        -- GateRegistry.getNearest(x, y, count, ownerIndex, maxDist)
        gates = GateRegistry.getNearest(x, y, 20, player.index, filterRadius)
        
        if showNearest then
            header = string.format("[Your Nearest Gates to (%d, %d)]:\n", x, y)
        else
            header = string.format("[Your Gates within %s radius of (%d, %d)]:\n", tostring(filterRadius), x, y)
        end
    else
        -- List ALL user gates
        gates = GateRegistry.getByOwner(player.index)
        -- Sort by creation time (default usually) or explicit sort?
        -- Let's sort all lists by distance from current sector simply for better UX
        table.sort(gates, function(a, b) 
            local da = (a.x - x)^2 + (a.y - y)^2
            local db = (b.x - x)^2 + (b.y - y)^2
            return da < db 
        end)
        header = string.format("[All Your Gates (Sorted by Distance)]:\n")
    end
    
    if #gates == 0 then
        return 0, "", header .. "No gates found matching criteria."
    end
    
    local msg = header
    for _, item in ipairs(gates) do
        -- Handle both raw gate objects and {gate=g, distSq=d} wrappers from getNearest
        local gate = item
        if item.gate then gate = item.gate end
        
        local dist = math.sqrt((gate.x - x)^2 + (gate.y - y)^2)
        local status = gate.status or "active"
        local fee = gate.baseFee or 0 -- Placeholder if we add fees later
        
        -- Format: [X:Y -> TX:TY] (Dist: N) - Active
        msg = msg .. string.format("- [%d : %d] -> [%d : %d] (Dist: %d) - %s\n", 
            gate.x, gate.y, gate.linkedTo.x, gate.linkedTo.y, math.floor(dist), status)
    end
    
    return 0, "", msg
end

return list

package.path = package.path .. ";data/scripts/lib/?.lua"

local GateRegistry = include("gateregistry")

local function list(playerIndex, args)
    local player = Player(playerIndex)
    if not player then return 1, "", "Player not found" end
    
    local showNearest = false
    local showCurrentSector = false
    local filterRadius = nil
    
    -- Argument Parsing
    for i, arg in ipairs(args) do
        if arg == "--nearest" then
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
        header = string.format("**Your Gates in Sector (%d, %d):**\n", x, y)
    elseif showNearest or filterRadius then
        -- Default radius if not specified but --nearest used, or infinite if just sorting?
        -- If filterRadius is set, we use it. If not, default to 50 for nearest? 
        -- Let's say --nearest implies a sort. --radius implies a filter.
        -- GateRegistry.getNearest handles both sort and filter.
        gates = GateRegistry.getNearest(x, y, 10, player.index, filterRadius)
        header = string.format("**Your Nearest Gates to (%d, %d):**\n", x, y)
    else
        -- List ALL user gates
        gates = GateRegistry.getByOwner(player.index)
        header = string.format("**All Your Gates:**\n")
    end
    
    if #gates == 0 then
        return 0, "", header .. "No gates found matching criteria."
    end
    
    local msg = header
    for _, gate in ipairs(gates) do
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

if onClient() then return end

package.path = package.path .. ";data/scripts/lib/?.lua"

local GateRegistry = include("gate/registry")
local GateFounderLog = include("logger"):new("GateFounder:Commands:Admin")

local function admin(playerIndex, args)
    local player = Player(playerIndex)
    
    -- Check admin privileges
    if playerIndex ~= nil and not Server():hasAdminPrivileges(player) then
        return 1, "", "You don't have admin privileges"
    end
    
    local adminCmd = args[1]
    local adminArgs = {}
    for i = 2, #args do
        table.insert(adminArgs, args[i])
    end
    
    if not adminCmd then
        return 0, "", [[
[Admin Commands]:
  /gate admin list [filter]     - List all gates
  /gate admin tp <x> <y>        - Teleport to gate
  /gate admin destroy <x> <y>   - Force destroy gate
  /gate admin transfer <x> <y> <owner> - Transfer ownership
  /gate admin help              - Show help
]]
    end
    
    if adminCmd == "list" then
        if adminArgs[1] == "help" or adminArgs[1] == "--help" then
            return 0, "", [[
[Usage]: /gate admin list [options]

[Options]:
  --owner or -o <index>    : Filter gates by specific faction/player index.
  --nearest or -n          : Sort by distance to your current location.
  --radius or -r <value>   : Filter gates within radius.
  --sector or -s           : Filter gates in current sector.
  --help or -h             : Show help
  
[Examples]:
  /gate admin list                      : List all gates (truncated)
  /gate admin list --sector             : List gates in this sector
  /gate admin list -o 2001              : List gates owned by Alliance 2001
  /gate admin list -r 50 --nearest      : List nearest gates within radius
]]
        end

        local filterOwner = nil
        local showNearest = false
        local showSector = false
        local radius = nil
        
        for i, arg in ipairs(adminArgs) do
            if arg == "--owner"   or arg == "-o" then filterOwner = tonumber(adminArgs[i+1]) end
            if arg == "--nearest" or arg == "-n" then showNearest = true end
            if arg == "--sector"  or arg == "-s" then showSector = true end
            if arg == "--radius"  or arg == "-r" then radius = tonumber(adminArgs[i+1]) end
        end
        
        local px, py = player:getSectorCoordinates()
        local results = {}
        local title = "[All Gates on Server (Truncated)]:\n"
        
        if showSector then
            results = GateRegistry.getInSector(px, py)
            title = string.format("[All Gates in Sector (%d, %d)]:\n", px, py)
        elseif showNearest or radius then
            local nearest = GateRegistry.getNearest(px, py, 20, filterOwner, radius)
            -- flatten nearest
            for _, n in ipairs(nearest) do table.insert(results, n.gate) end
            title = string.format("[Nearest Gates (%s)]:\n", radius and ("Radius "..radius) or "Unlimited")
        else
            -- Plain dump or owner filter
            if filterOwner then
                 results = GateRegistry.getByOwner(filterOwner)
                 title = string.format("[Gates for Owner %d]:\n", filterOwner)
            else
                 local all = GateRegistry.getAll()
                 for k, v in pairs(all) do 
                    -- reconstruct coords
                    local gx, gy, tx, ty = k:match("^(-?%d+)_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
                    if gx then
                        v.x = tonumber(gx)
                        v.y = tonumber(gy)
                        table.insert(results, v)
                    end
                 end
            end
        end
        
        if #results == 0 then
            return 0, "", title .. "No gates found."
        end
        
        local msg = title
        local limit = 30
        for i, gate in ipairs(results) do
            if i > limit then
                 msg = msg .. "... (output truncated)"
                 break
            end
            msg = msg .. string.format("- (%d : %d) -> (%d : %d) [Owner: %d]\n", 
                gate.x, gate.y, gate.linkedTo.x, gate.linkedTo.y, gate.owner)
        end
        return 0, "", msg
    elseif adminCmd == "tp" then
        local x = tonumber(adminArgs[1])
        local y = tonumber(adminArgs[2])
        if not x or not y then
            return 1, "", "Usage: /gate admin tp <x> <y>"
        end
        Sector():transferEntity(player.craft, x, y, SectorChangeType.Jump)
        -- player.craft.hyperspaceJumpReached = true
        return 0, "", string.format("Teleporting to (%d, %d)... Please wait", x, y)
    elseif adminCmd == "destroy" then
        local x = tonumber(adminArgs[1])
        local y = tonumber(adminArgs[2])
        if not x or not y then
            return 1, "", "Usage: /gate admin destroy <x> <y>"
        end
        -- TODO: Implement force destroy
        return 0, "", string.format("Force destroying gate at (%d, %d) - Not implemented yet", x, y)
    elseif adminCmd == "transfer" then
        return 0, "", "Transfer ownership - Not implemented yet"
    else
        return 1, "", "Unknown admin command: " .. adminCmd
    end
end

return admin

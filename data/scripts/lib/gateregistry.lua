package.path = package.path .. ";data/scripts/lib/?.lua"

local Logger = include("logger")
local GateRegistry = {}

--[[
    Gate Registry System
    
    Centralized system for tracking all player-made gates in the galaxy.
    Used for:
    - Lists of gates (/gate list)
    - Teleportation logic
    - Usage statistics
    - Limiting gates per faction
    
    Storage:
    - Data is stored in Server().values["GateRegistry"] as a serialized table.
    - Format:
      {
          ["50_ -30"] = { -- Key: "x_y" string
              owner = 12345,        -- Faction index
              linkedTo = {x=60, y=-40}, -- Destination coords 
              status = "active",    -- "active", "disabled", "broken"
              created = 1234567890, -- Timestamp
              usageCount = 0,
              originalOwner = 12345, -- Who built it
              name = "Alpha Gate"   -- Optional custom name
          }
      }
--]]

local Log = Logger:new("GateRegistry")

-- Internal cache
local _gates = nil
local _isLoaded = false

-- ============================================================================
-- PRIVATE HELPERS
-- ============================================================================

local function _getKey(x, y)
    return string.format("%d_%d", x, y)
end

-- ============================================================================
-- SERIALIZATION HELPER
-- ============================================================================

local function _isList(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true, i
end

local function _serialize(o, minify)
    if type(o) ~= "table" then
        return type(o) == "string" and '"'..o:gsub("([\"\\])", "\\%1")..'"' or tostring(o)
    end

    local s = "{"
    local isList, length = _isList(o)
    
    if isList then
        for k = 1, length do
            s = s .. (k > 1 and "," or "") .. _serialize(o[k], minify)
        end
    else
        local i = 0
        for k, v in pairs(o) do
            i = i + 1
            if type(k) ~= 'number' then
                k = '"'..tostring(k):gsub("([\"\\])", "\\%1")..'"'
            else
                k = "["..k.."]"
            end
            
            s = s .. (i > 1 and "," or "") .. (minify and "" or "") .. k .. "=" .. _serialize(v, minify)
        end
    end
    s = s .. "}"
    return s
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
    Initialize registry (load from server)
--]]
function GateRegistry.initialize()
    if onClient() then return end
    
    GateRegistry.load()
end

--[[
    Load registry from Server storage
--]]
function GateRegistry.load()
    if not onServer() then return end
    
    local serialized = Server():getValue("GateRegistry")
    if serialized then
        -- Deserialize (serialized string is "{...}")
        -- wrap in return to make it a chunk that returns data
        local func = loadstring("return " .. serialized)
        if func then
            -- Provide safe environment (setfenv unavailable in this context, assuming trusted data)
            -- local env = {}
            -- setfenv(func, env)
            local success, data = pcall(func)
            if success and data then
                _gates = data
            else
                 Log:Error("Failed to execute Gate Registry chunk!")
                 _gates = {}
            end
        else
             Log:Error("Failed to deserialize Gate Registry!")
             _gates = {}
        end
    else
        _gates = {}
    end
    _isLoaded = true
end

--[[
    Save registry to Server storage
--]]
function GateRegistry.save()
    if not onServer() then return end
    if not _gates then return end
    
    local serialized = _serialize(_gates, true) 
    Server():setValue("GateRegistry", serialized)
end

--[[
    Register a new gate
    @param x number
    @param y number
    @param ownerIndex number - Faction index
    @param targetX number
    @param targetY number
    @return boolean success
--]]
function GateRegistry.add(x, y, ownerIndex, targetX, targetY)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y)
    if _gates[key] then
        Log:Warning("Gate at %d:%d already registered!", x, y)
        return false -- Already exists
    end
    
    _gates[key] = {
        owner = ownerIndex,
        linkedTo = {x=targetX, y=targetY},
        status = "active",
        created = Server().time,
        usageCount = 0,
        originalOwner = ownerIndex
    }
    
    GateRegistry.save()
    Log:Info("Registered new gate at %d:%d owned by %s", x, y, tostring(ownerIndex))
    return true
end

--[[
    Unregister a gate
    @param x number
    @param y number
    @return boolean success
--]]
function GateRegistry.remove(x, y)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y)
    if _gates[key] then
        _gates[key] = nil
        GateRegistry.save()
        Log:Info("Unregistered gate at %d:%d", x, y)
        return true
    end
    return false
end

--[[
    Update a gate's data
    @param x number
    @param y number
    @param data table - Partial data to update
    @return boolean success
--]]
function GateRegistry.update(x, y, data)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y)
    local gate = _gates[key]
    
    if gate then
        for k, v in pairs(data) do
            gate[k] = v
        end
        GateRegistry.save()
        return true
    end
    return false
end

--[[
    Get gate data
    @param x number
    @param y number
    @return table|nil
--]]
function GateRegistry.get(x, y)
    if not _gates then GateRegistry.load() end
    return _gates[_getKey(x, y)]
end

--[[
    Get all gates for a specific owner
    @param ownerIndex number
    @return table - List of gate entries
--]]
function GateRegistry.getByOwner(ownerIndex)
    if not _gates then GateRegistry.load() end
    
    local result = {}
    for key, gate in pairs(_gates) do
        if gate.owner == ownerIndex then
            -- Parse key to get x,y back if needed, or just include data
            local x, y = key:match("^(-?%d+)_(%-?%d+)$")
            if x and y then
                gate.x = tonumber(x)
                gate.y = tonumber(y)
            end
            table.insert(result, gate)
        end
    end
    return result
end

--[[
    Get nearest gates to coordinates
    @param x number
    @param y number
    @param count number - Max results
    @param ownerIndex number - (Optional) Filter by owner
    @param maxDist number - (Optional) Max distance (radius) to search
    @return table - Sorted list of gates { {gate=..., distance=...}, ... }
--]]
function GateRegistry.getNearest(x, y, count, ownerIndex, maxDist)
    if not _gates then GateRegistry.load() end
    
    local results = {}
    local maxDistSq = maxDist and (maxDist * maxDist) or nil

    for key, gate in pairs(_gates) do
        -- Filter by owner if specified
        if not ownerIndex or gate.owner == ownerIndex then
            local gx, gy = key:match("^(-?%d+)_(%-?%d+)$")
            if gx and gy then
                gx, gy = tonumber(gx), tonumber(gy)
                -- DistanceSquared for sorting
                local distSq = (gx - x)^2 + (gy - y)^2
                
                -- Check radius if specified
                if not maxDistSq or distSq <= maxDistSq then
                    -- Reconstruct coords if needed (gate object might not have them explicitly if serialized compactly)
                    -- Our add() stores key but gate data doesn't have x/y fields usually unless added manually.
                    -- Let's ensure returned object has x,y
                    local resultGate = {}
                    for k,v in pairs(gate) do resultGate[k] = v end
                    resultGate.x = gx
                    resultGate.y = gy
                    
                    table.insert(results, {gate = resultGate, distSq = distSq})
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(results, function(a, b) return a.distSq < b.distSq end)
    
    -- Truncate to count
    local truncated = {}
    for i = 1, math.min(#results, count or 10) do
        table.insert(truncated, results[i])
    end
    
    return truncated
end

--[[
    Get all gates (Admin only ideally)
--]]
function GateRegistry.getAll()
    if not _gates then GateRegistry.load() end
    return _gates
end

return GateRegistry

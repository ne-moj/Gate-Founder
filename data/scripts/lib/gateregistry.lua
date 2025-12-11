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

local function _getKey(x, y, tx, ty)
    return string.format("%d_%d_%d_%d", x, y, tx, ty)
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
            -- Provide safe environment
            local success, data = pcall(func)
            if success and data then
                _gates = data
                
                -- Migration: Convert old x_y keys to x_y_tx_ty
                local migrated = false
                local newGates = {}
                for k, v in pairs(_gates) do
                    -- Check if key is old format (x_y)
                    if k:match("^(-?%d+)_(%-?%d+)$") then
                        local x, y = k:match("^(-?%d+)_(%-?%d+)$")
                        x, y = tonumber(x), tonumber(y)
                        if v.linkedTo and v.linkedTo.x and v.linkedTo.y then
                            local newKey = _getKey(x, y, v.linkedTo.x, v.linkedTo.y)
                            newGates[newKey] = v
                            migrated = true
                            Log:Info("Migrated gate %s to %s", k, newKey)
                        else
                            Log:Error("Cannot migrate gate %s: missing linkedTo data", k)
                        end
                    else
                        newGates[k] = v
                    end
                end
                
                if migrated then
                    _gates = newGates
                    GateRegistry.save()
                    Log:Info("Migration complete: Saved updated registry.")
                end
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
    
    local key = _getKey(x, y, targetX, targetY)
    if _gates[key] then
        Log:Warning("Gate path %s already registered!", key)
        return false -- Already exists
    end
    
    _gates[key] = {
        owner = ownerIndex,
        linkedTo = {x=targetX, y=targetY},
        status = "active",
        created = os.time(),
        usageCount = 0,
        originalOwner = ownerIndex
    }
    
    GateRegistry.save()
    Log:Info("Registered new gate route %s owned by %s", key, tostring(ownerIndex))
    return true
end

--[[
    Unregister a gate
    @param x number
    @param y number
    @param targetX number
    @param targetY number
    @return boolean success
--]]
function GateRegistry.remove(x, y, targetX, targetY)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y, targetX, targetY)
    if _gates[key] then
        _gates[key] = nil
        GateRegistry.save()
        Log:Info("Unregistered gate path %s", key)
        return true
    end
    return false
end

--[[
    Update a gate's data
    @param x number
    @param y number
    @param targetX number
    @param targetY number
    @param data table - Partial data to update
    @return boolean success
--]]
function GateRegistry.update(x, y, targetX, targetY, data)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y, targetX, targetY)
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
    @param targetX number
    @param targetY number
    @return table|nil
--]]
function GateRegistry.get(x, y, targetX, targetY)
    if not _gates then GateRegistry.load() end
    return _gates[_getKey(x, y, targetX, targetY)]
end

--[[
     Get all gates in a sector
     @param x number
     @param y number
     @return table - List of gates in this sector
--]]
function GateRegistry.getInSector(x, y)
     if not _gates then GateRegistry.load() end
     
     local prefix = string.format("%d_%d_", x, y)
     local result = {}
     for k, v in pairs(_gates) do
         if k:find("^" .. prefix) then
            -- Reconstruct x/y data safely
            local gx, gy, tx, ty = k:match("^(-?%d+)_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                v.x = tonumber(gx)
                v.y = tonumber(gy)
                -- We already have linkedTo inside usually, but lets ensure consistency
            end
            table.insert(result, v)
         end
     end
     return result
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
            local gx, gy, tx, ty = key:match("^(-?%d+)_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                gate.x = tonumber(gx)
                gate.y = tonumber(gy)
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
        if not ownerIndex or gate.owner == ownerIndex then
            local gx, gy, tx, ty = key:match("^(-?%d+)_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                gx, gy = tonumber(gx), tonumber(gy)
                local distSq = (gx - x)^2 + (gy - y)^2
                
                if not maxDistSq or distSq <= maxDistSq then
                    local resultGate = {}
                    for k,v in pairs(gate) do resultGate[k] = v end
                    resultGate.x = gx
                    resultGate.y = gy
                    
                    table.insert(results, {gate = resultGate, distSq = distSq})
                end
            end
        end
    end
    
    table.sort(results, function(a, b) return a.distSq < b.distSq end)
    
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

--[[
    Gate Registry v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This module is responsible for managing the registry of gates within the game world.
      It handles the loading, saving, and updating of gate data, including their positions, linked gates, and other properties.
    
    FEATURES:
       - Loads the current state of the registry from the server.
       - Saves the current state of the registry to the server.
       - Updates the registry when a new gate is created or an existing gate is modified.
       - Provides a method to retrieve the current state of the registry.
    
    USAGE:
        To load the current state of the registry, call the `GateRegistry.load` function:
        `GateRegistry.load()`
        
        To save the current state of the registry, call the `GateRegistry.save` function:
        `GateRegistry.save()`
        
        To retrieve the current state of the registry, call the `GateRegistry.get` function:
        `GateRegistry.get()`
--]]

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local Logger = include("logger")
local GateRegistry = {}

local Log = Logger:new("GateRegistry")

-- Internal cache
local _gates = nil
local _isLoaded = false

-- ============================================================================
-- PRIVATE HELPERS
-- ============================================================================

--[[
    Generates a unique key for a gate based on its coordinates and linked gate coordinates.
    @param x The x-coordinate of the gate.
    @param y The y-coordinate of the gate.
    @param tx The x-coordinate of the linked gate.
    @param ty The y-coordinate of the linked gate.
    @return A string representing the unique key for the gate.
--]]
local function _getKey(x, y, tx, ty)
    return string.format("%d_%d_%d_%d", x, y, tx, ty)
end

-- ============================================================================
-- SERIALIZATION HELPER
-- ============================================================================

--[[
    Checks if a table can be considered a list (i.e., all keys are sequential numbers starting from 1).
    @param t The table to check.
    @return boolean True if the table is a list, false otherwise.
    @return number The number of elements if it's a list, or 0 if not.
--]]
local function _isList(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true, i
end

--[[
    Serializes a Lua table or value into a string representation.
    This function handles nested tables, strings, numbers, and booleans.
    It can serialize tables as lists (if all keys are sequential numbers starting from 1)
    or as dictionaries (with string or number keys).
    @param o The value to serialize (table, string, number, boolean, nil).
    @param minify (boolean, optional) If true, the output will be minified (e.g., no extra spaces for table keys).
    @return A string representation of the serialized value.
    @usage
        _serialize({a = 1, b = "hello", c = {1, 2, 3}}) -- Returns '{["a"]=1,["b"]="hello",["c"]={1,2,3}}'
        _serialize({1, 2, "three"}) -- Returns '{1,2,"three"}'
        _serialize("test string") -- Returns '"test string"'
        _serialize(123) -- Returns '123'
        _serialize(true) -- Returns 'true'
--]]
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
                -- Wrap string keys in brackets ["key"]
                k = '["'..tostring(k):gsub("([\"\\])", "\\%1")..'"]'
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
    Loads the current state of the registry from the server.
]]--
function GateRegistry.load()
    Log:RunFunc("GateRegistry:load()")
    local serialized = Server():getValue("GateRegistry")
    if serialized then
        local func, err = loadstring("return " .. serialized)
        if not func then
             -- Attempt auto-repair for legacy format: "key"=val -> ["key"]=val
             Log:Warning("Corrupted Gate Registry detected, attempting repair...")
             local repaired = serialized:gsub('(["\'])([%w_]+)%1%s*=', '["%2"]=')
             func, err = loadstring("return " .. repaired)
             if func then
                 Log:Info("Repair successful!")
                 serialized = repaired -- Mark for save
             end
        end
        
        if func then
            local success, data = pcall(func)
            if success and data then
                _gates = data
                -- Migration logic omitted for brevity as it was already run or not needed if clean
                -- If migration is critical it should be kept. Assuming keeping it for safety.
                local migrated = false
                local newGates = {}
                for k, v in pairs(_gates) do
                    if k:match("^(-?%d+)_(%-?%d+)$") then
                        local x, y = k:match("^(-?%d+)_(%-?%d+)$")
                        x, y = tonumber(x), tonumber(y)
                        if v.linkedTo and v.linkedTo.x and v.linkedTo.y then
                            local newKey = _getKey(x, y, v.linkedTo.x, v.linkedTo.y)
                            newGates[newKey] = v
                            migrated = true
                            Log:Info("Migrated gate %s to %s", k, newKey)
                        end
                    else
                        newGates[k] = v
                    end
                end
                
                if migrated or serialized ~= Server():getValue("GateRegistry") then
                    _gates = newGates
                    GateRegistry.save()
                    Log:Info("Registry updated/migrated.")
                end
            else
                 Log:Error("Failed to execute Gate Registry chunk: %s", tostring(data))
                 _gates = {}
            end
        else
             Log:Error("Failed to deserialize Gate Registry: %s", tostring(err))
             _gates = {}
        end
    else
        _gates = {}
    end
    _isLoaded = true
end

--[[
    Saves the current state of the registry to the server.
]]--
function GateRegistry.save()
    Log:RunFunc("GateRegistry:save()")
    if not _gates then return end
    
    local serialized = _serialize(_gates, true) 
    Server():setValue("GateRegistry", serialized)
end

--[[
    Adds a new gate to the registry.
    @param x The x-coordinate of the gate.
    @param y The y-coordinate of the gate.
    @param ownerIndex The index of the faction that owns the gate.
    @param targetX The x-coordinate of the target sector.
    @param targetY The y-coordinate of the target sector.
    @return true if the gate was added, false otherwise.
]]--
function GateRegistry.add(x, y, ownerIndex, targetX, targetY)
    Log:RunFunc("GateRegistry:add(%s, %s, %s, %s, %s)", x, y, ownerIndex, targetX, targetY)
    if not _gates then GateRegistry.load() end
    
    local key = _getKey(x, y, targetX, targetY)
    if _gates[key] then
        Log:Warning("Gate path %s already registered!", key)
        return false
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
    Removes a specific gate by its coordinates.
    @param x The x-coordinate of the gate.
    @param y The y-coordinate of the gate.
    @param targetX The x-coordinate of the target sector.
    @param targetY The y-coordinate of the target sector.
    @return true if the gate was removed, false otherwise.
]]--
function GateRegistry.remove(x, y, targetX, targetY)
    Log:RunFunc("GateRegistry:remove(%s, %s, %s, %s)", x, y, targetX, targetY)
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
    Updates a specific gate by its coordinates.
    @param x The x-coordinate of the gate.
    @param y The y-coordinate of the gate.
    @param targetX The x-coordinate of the target sector.
    @param targetY The y-coordinate of the target sector.
    @param data A table containing the new data to update.
    @return true if the gate was updated, false otherwise.
]]--
function GateRegistry.update(x, y, targetX, targetY, data)
    Log:RunFunc("GateRegistry:update(%s, %s, %s, %s, %s)", x, y, targetX, targetY, data)
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
    Gets a specific gate by its coordinates.
    @param x The x-coordinate of the gate.
    @param y The y-coordinate of the gate.
    @param targetX The x-coordinate of the target sector.
    @param targetY The y-coordinate of the target sector.
    @return The gate data if found, otherwise nil.
]]--
function GateRegistry.get(x, y, targetX, targetY)
    Log:RunFunc("GateRegistry:get(%s, %s, %s, %s)", x, y, targetX, targetY)
    if not _gates then GateRegistry.load() end
    return _gates[_getKey(x, y, targetX, targetY)]
end

--[[
    Gets all gates in a specific sector.
    @param x The x-coordinate of the sector.
    @param y The y-coordinate of the sector.
    @return A table containing all gates in the specified sector, keyed by their unique string identifier.
]]--
function GateRegistry.getInSector(x, y)
    Log:RunFunc("GateRegistry:getInSector(%s, %s)", x, y)
    if not _gates then GateRegistry.load() end
    -- NOTE: This implementation relies on string matching which is not ideal but simple
    local prefix = string.format("%d_%d_", x, y)
    local result = {}
    for k, v in pairs(_gates) do
        if k:find("^" .. prefix) then
            local gx, gy, tx, ty = k:match("^(-?%d+)_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
            if gx then
                v.x = tonumber(gx)
                v.y = tonumber(gy)
            end
            table.insert(result, v)
         end
     end
     return result
end

--[[
    Gets all gates owned by a specific faction.
    @param ownerIndex The index of the faction to filter by.
    @return A table containing all gates owned by the specified faction, keyed by their unique string identifier.
]]--
function GateRegistry.getByOwner(ownerIndex)
    Log:RunFunc("GateRegistry:getByOwner(%s)", ownerIndex)
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
    Gets the nearest gates to a given coordinate.
    @param x The x-coordinate to search from.
    @param y The y-coordinate to search from.
    @param count The maximum number of gates to return (defaults to 10).
    @param ownerIndex Optional. If provided, only gates owned by this index will be considered.
    @param maxDist Optional. If provided, only gates within this distance will be considered.
    @return A table of nearest gates, sorted by distance, with their 'gate' data and 'distSq' (squared distance).
]]--
function GateRegistry.getNearest(x, y, count, ownerIndex, maxDist)
    Log:RunFunc("GateRegistry:getNearest(%s, %s, %s, %s, %s)", x, y, count, ownerIndex, maxDist)
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
    Gets all registered gates.
    @return A table containing all registered gates, keyed by their unique string identifier.
]]--
function GateRegistry.getAll()
    Log:RunFunc("GateRegistry:getAll()")
    if not _gates then GateRegistry.load() end
    return _gates
end

return GateRegistry

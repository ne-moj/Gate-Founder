package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    Configs Library
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Manages mod configuration storage using Lua table serialization.
    Saves/loads config data to/from files in the moddata directory.
    
    FILE FORMAT:
        Configs are saved as Lua code that can be loaded with loadstring().
        Example file content:
            configs = {
                Settings = {
                    MaxDistance = 45,
                    MaxGatesPerFaction = 5
                }
            };
    
    FILE LOCATION:
        Server: <server_folder>/moddata/<ModuleName>.lua
        Client: moddata/<ModuleName><seed>.lua (seed-dependent)
    
    USAGE:
        local Configs = include("configs"):new("MyModule")
        
        -- Save config
        local data = {
            Settings = {
                param1 = "value1",
                param2 = 123
            }
        }
        Configs:save(data)
        
        -- Load config
        local data = Configs:load()
        if data and data.Settings then
            print(data.Settings.param1)
        end
    
    SEED-DEPENDENT CONFIGS:
        On client, configs can be seed-dependent (different per galaxy).
        Set in constructor: self.isSeedDependant = onClient()
        
        Example:
            Client file: moddata/MyModule1234567890.lua
            Server file: server/moddata/MyModule.lua
    
    WORKFLOW:
        1. Create Configs instance
        2. Load existing config (or use defaults)
        3. Modify data
        4. Save config
        5. Config persists across game restarts
--]]

local TableShow = include ('tableshow')
local Logger = include('logger'):new('Configs')
local Configs = {}

--[[
    Create a new Configs instance
    
    @param moduleName string - Name of the module (used for filename)
    @return Configs instance
    
    Example:
        local Configs = include("configs"):new("GateSettings")
--]]
function Configs:new (moduleName)
	--Logger:Debug('Create new Configs object %s', moduleName)
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    self.moduleName = moduleName or "Unknown"
    
    self:resetSettings()
    return instance
end

function Configs:resetSettings ()
    self.nameParam = 'configs'
	self.nameBaseDir = 'moddata'
	self.isSeedDependant = onClient()
	self.seed = self.isSeedDependant and GameSettings().seed or ''
    self.defaultConfigs = {}
end

--[[
    Set default config values
    
    @param data table - Default configuration data
    @return boolean - true on success
    
    Example:
        Configs:setConfigs({MaxDistance = 45, MaxGates = 5})
--]]
function Configs:setConfigs (data)
	Logger:Debug('Set configs: %s', TableShow(data, 'configs'))
	self.defaultConfigs = data
	
	return true
end

--[[
    Update default config values (merge with existing)
    
    @param data table - Config data to merge
    @return boolean - true on success
    
    Example:
        Configs:updateConfigs({NewParam = "value"})
--]]
function Configs:updateConfigs (data)
	for k,v in pairs(data) do self.defaultConfigs[k] = v end
	
	return true
end

--[[
    Save config data to file
    
    @param data table - Config data to save
    @return boolean, string - success status and error message if failed
    
    File location: <server_folder>/moddata/<ModuleName>.lua
    
    Example:
        local success, err = Configs:save({Settings = {param = "value"}})
        if not success then
            print("Save failed:", err)
        end
--]]
function Configs:save(data)
	Logger:Debug('save configs: %s', TableShow(data, 'configs'))
	data = data or {}
	for k,v in pairs(self.defaultConfigs) do data[k] = v end
	
    local filename = self:getPathToConfigFile()
    
    local file, err = io.open(filename, "wb")
    if err then
        eprint("[ERROR][%s]: Failed to save config file '%s': %s", self.moduleName, filename, err)
        return false, err
    end
    
    file:write(self:serialize(data))
    file:close()
    
	self:updateConfigs(data)

	return true
end

--[[
    Load config data from file
    
    @return table, string - config data and error message if failed
    
    Example:
        local data, err = Configs:load()
        if err then
            print("Load failed:", err)
        elseif data and data.Settings then
            print("Loaded:", data.Settings.param)
        end
--]]
function Configs:load()
	Logger:Debug('load configs', TableShow(data, 'configs'))
    local filename = self:getPathToConfigFile()
    
    local file, err = io.open(filename, "rb")
    if err then
        eprint("[ERROR][%s]: Failed to load config file '%s': %s", self.moduleName, filename, err)
        return nil, err
    end
    
    local fileContents = file:read("*all")
    file:close()
    
    local data = self:deserialize(fileContents)
    self.configs = data
    
    return data
end

function Configs:serialize (data, name) 
	return TableShow(data, name or self.nameParam)
end

function Configs:deserialize (dataFromFile)
	local tempFunc, err = dataFromFile and loadstring(dataFromFile.."; return "..self.nameParam) or nil
	
    if err then
        eprint("[ERROR][%s]: Failed to load config file '%s': %s; File contents: %s", self.moduleName, filename, err, dataFromFile)
        return nil
    end
    
	local data = tempFunc and tempFunc() or nil
    
    return data
end

function Configs:getPathToConfigFile ()
	local dir = self.nameBaseDir
	
    if onServer() then
        dir = Server().folder.."/"..self.nameBaseDir
    end
    
    return dir.."/"..self.moduleName..self.seed..".lua"
end

return Configs

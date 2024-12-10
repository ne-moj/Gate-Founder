package.path = package.path .. ";data/scripts/lib/?.lua"

local TableShow = include ('tableshow')
local Logger = include('logger'):new('Configs')
local Configs = {}

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

function Configs:setConfigs (data)
	Logger:Debug('Set configs: %s', TableShow(data, 'configs'))
	self.defaultConfigs = data
	
	return true
end

function Configs:updataConfigs (data)
	for k,v in pairs(data) do self.defaultConfigs[k] = v end
	
	return true
end

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
    
	self:updataConfigs(data)
    
    return true
end

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

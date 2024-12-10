package.path = package.path .. ";data/scripts/lib/?.lua"

local TableShow = include ('tableshow')
local Logger = {
    enumTypes = {
        ERROR   = 0x1,  -- 0000 0001
        WARNING = 0x2,  -- 0000 0010
        INFO    = 0x4,  -- 0000 0100
        DEBUG   = 0x8,  -- 0000 1000
        RUN_FUN = 0x10  -- 0001 0000
    },
    printMask = 0,
    saveMask = 0
}

function Logger:new(moduleName)
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    self.moduleName = moduleName or "Unknown"
	
    --self.printMask = self:_prepareMask({'ERROR', 'WARNING', 'INFO'})
    self.printMask = self:_prepareMask({'ERROR', 'WARNING', 'INFO', 'DEBUG'})
    --self:setSaveMask({'ERROR', 'WARNING'})
    self.saveMask = self:_prepareMask({'ERROR', 'WARNING', 'INFO', 'DEBUG'})
    
    return instance
end

function Logger:Error(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.ERROR) > 0 then
        eprint(string.format("[ERROR][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.ERROR) > 0 then
        printlog(string.format("[ERROR][%s]: "..msg, self.moduleName, ...))
    end
end

function Logger:Warning(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.WARNING) > 0 then
        print(string.format("[WARNING][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.WARNING) > 0 then
        printlog(string.format("[WARNING][%s]: "..msg, self.moduleName, ...))
    end
end

function Logger:Info(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.INFO) > 0 then
        print(string.format("[INFO][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.INFO) > 0 then
        printlog(string.format("[INFO][%s]: "..msg, self.moduleName, ...))
    end
end

function Logger:Debug(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.DEBUG) > 0 then
        print(string.format("[DEBUG][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.DEBUG) > 0 then
        printlog(string.format("[DEBUG][%s]: "..msg, self.moduleName, ...))
    end
end

function Logger:RunFunc(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.RUN_FUN) > 0 then
        print(string.format("[RUN_FUN][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.RUN_FUN) > 0 then
        printlog(string.format("[RUN_FUN][%s]: "..msg, self.moduleName, ...))
    end
end

function Logger:serialize (data, name) 
	return TableShow(data, name)
end

function Logger:_prepareMask (types)
	local mask = 0
	for _, v in pairs(types) do
		if self.enumTypes[v] then
			mask = bit32.bor(mask, self.enumTypes[v])
		end
	end
	
	return mask
end

return Logger

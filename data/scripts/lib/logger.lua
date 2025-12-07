package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    Logger Library
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Provides flexible logging with multiple log levels and output targets.
    Uses bit masks for efficient level filtering.
    
    LOG LEVELS:
        ERROR   (0x1)  - Critical errors that need immediate attention
        WARNING (0x2)  - Warnings about potential issues
        INFO    (0x4)  - Informational messages
        DEBUG   (0x8)  - Detailed debugging information
        RUN_FUN (0x10) - Function execution tracking
    
    OUTPUT TARGETS:
        printMask - Controls console output (print/eprint)
        saveMask  - Controls file output (printlog)
    
    USAGE:
        local Logger = include('logger'):new('MyModule')
        
        -- Log messages
        Logger:Error("Failed to load: %s", filename)
        Logger:Warning("Deprecated function called")
        Logger:Info("Processing %d items", count)
        Logger:Debug("Variable value: %s", tostring(value))
        Logger:RunFunc("myFunction([arg1]:%s, [arg2]:%s)", arg1, arg2)
        
        -- Serialize tables for logging
        local data = {a = 1, b = 2}
        Logger:Debug("Data: %s", Logger:serialize(data, "data"))
    
    CONFIGURING LOG LEVELS:
        -- Default: ERROR, WARNING, INFO, DEBUG enabled
        -- To change, modify lines 22-25 in logger.lua
        
        -- Example: Only errors and warnings
        self.printMask = self:_prepareMask({'ERROR', 'WARNING'})
        self.saveMask = self:_prepareMask({'ERROR'})
    
    BIT MASK SYSTEM:
        Uses bitwise operations for efficient level checking:
        - bit32.band(mask, level) > 0  -- Check if level is enabled
        - bit32.bor(mask1, mask2)      -- Combine masks
        
        Example:
            mask = ERROR | WARNING = 0x1 | 0x2 = 0x3 = 0b0011
            bit32.band(0x3, ERROR) = 0x1 > 0  -- TRUE, ERROR enabled
            bit32.band(0x3, DEBUG) = 0x0 = 0  -- FALSE, DEBUG disabled
--]]

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

--[[
    Create a new Logger instance
    
    @param moduleName string - Name of the module (appears in log messages)
    @return Logger instance
    
    Example:
        local Logger = include('logger'):new('GateFounder')
--]]
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

--[[
    Log an error message
    
    @param msg string - Message format string (supports %s, %d, %i, etc.)
    @param ... - Arguments for format string
    
    Output: Console (eprint) and log file (printlog)
    
    Example:
        Logger:Error("Failed to load file: %s", filename)
        Logger:Error("Invalid value: %d", value)
--]]
function Logger:Error(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.ERROR) > 0 then
        eprint(string.format("[ERROR][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.ERROR) > 0 then
        printlog(string.format("[ERROR][%s]: "..msg, self.moduleName, ...))
    end
end

--[[
    Log a warning message
    
    @param msg string - Message format string
    @param ... - Arguments for format string
    
    Example:
        Logger:Warning("Deprecated function called")
        Logger:Warning("Value %d exceeds recommended limit", value)
--]]
function Logger:Warning(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.WARNING) > 0 then
        print(string.format("[WARNING][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.WARNING) > 0 then
        printlog(string.format("[WARNING][%s]: "..msg, self.moduleName, ...))
    end
end

--[[
    Log an informational message
    
    @param msg string - Message format string
    @param ... - Arguments for format string
    
    Example:
        Logger:Info("Processing %d items", count)
        Logger:Info("Gate created at (%d:%d)", x, y)
--]]
function Logger:Info(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.INFO) > 0 then
        print(string.format("[INFO][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.INFO) > 0 then
        printlog(string.format("[INFO][%s]: "..msg, self.moduleName, ...))
    end
end

--[[
    Log a debug message
    
    @param msg string - Message format string
    @param ... - Arguments for format string
    
    Example:
        Logger:Debug("Variable value: %s", tostring(var))
        Logger:Debug("Coordinates: (%d, %d)", x, y)
--]]
function Logger:Debug(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.DEBUG) > 0 then
        print(string.format("[DEBUG][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.DEBUG) > 0 then
        printlog(string.format("[DEBUG][%s]: "..msg, self.moduleName, ...))
    end
end

--[[
    Log function execution (for tracing)
    
    @param msg string - Message format string
    @param ... - Arguments for format string
    
    Example:
        Logger:RunFunc("myFunction([arg1]:%s, [arg2]:%s)", arg1, arg2)
--]]
function Logger:RunFunc(msg, ...)
    if bit32.band(self.printMask, self.enumTypes.RUN_FUN) > 0 then
        print(string.format("[RUN_FUN][%s]: "..msg, self.moduleName, ...))
    end
    if bit32.band(self.saveMask, self.enumTypes.RUN_FUN) > 0 then
        printlog(string.format("[RUN_FUN][%s]: "..msg, self.moduleName, ...))
    end
end

--[[
    Serialize a table to string for logging
    
    @param data table - Table to serialize
    @param name string - Name for the table
    @return string - Serialized table as Lua code
    
    Example:
        local t = {a = 1, b = 2}
        Logger:Debug("Config: %s", Logger:serialize(t, "config"))
--]]
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

package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    Configs Library v2.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Advanced configuration management with validation, comments support,
    and separate client/server storage paths.
    
    FEATURES:
    - Class-based architecture
    - Validation rules (type, min, max, enum)
    - Comments support in config files
    - Separate client/server storage
    - Seed-dependent configs for client
    - Schema definition for config structure
    
    FILE LOCATION:
        Server: <server_folder>/moddata/<ModuleName>.lua
        Client: moddata/<ModuleName><seed>.lua (if seed-dependent)
    
    USAGE:
        -- Define schema with validation
        local schema = {
            MaxDistance = {
                default = 45,
                type = "number",
                min = 1,
                max = 1000,
                comment = "Maximum distance between gates"
            },
            EnableFeature = {
                default = true,
                type = "boolean",
                comment = "Enable or disable feature"
            },
            Mode = {
                default = "normal",
                type = "string",
                enum = {"normal", "advanced", "debug"},
                comment = "Operation mode"
            }
        }
        
        -- Create config instance
        local Configs = include("configs")
        local config = Configs("MyModule", {
            useSeed = true,        -- Use seed in filename (client)
            schema = schema        -- Validation schema
        })
        
        -- Get/Set values
        local value = config:get("MaxDistance")           -- Returns value only
        local valueWithMeta = config:get("MaxDistance", true)  -- Returns {value, comment}
        config:set("MaxDistance", 100)                    -- Validates and sets
        
        -- Save/Load
        config:save()
        config:load()
--]]

local TableShow = include('tableshow')

-- ============================================================================
-- CLASS DEFINITION
-- ============================================================================

local Configs = {}

--[[
    @brief Custom __index metamethod for the Configs class.
    
    This function allows accessing configuration values directly as properties of the Configs instance,
    e.g., `config.MaxDistance`. It first checks for class methods and then for values in the
    internal `_data` table.
    @param self The Configs instance.
    @param key The key (field name) being accessed.
    @return The value associated with the key, or nil if not found.
]]--
Configs.__index = function(self, key)
    -- First check class methods
    if Configs[key] then
        return Configs[key]
    end
    -- Then check data storage (allows Config.FieldName)
    -- Use rawget to avoid infinite recursion
    local data = rawget(self, "_data")
    if data and data[key] ~= nil then
        return data[key]
    end
    return nil
end

--[[
    @brief Custom __newindex to allow Config.FieldName = value syntax
    
    This function allows setting configuration values directly as properties of the Configs instance,
    e.g., `config.MaxDistance = 100`. It first checks for special internal fields and then sets the
    value in the internal `_data` table after validating it.
    @param self The Configs instance.
    @param key The key (field name) being set.
    @param value The value to set.
]]--
Configs.__newindex = function(self, key, value)
    -- Special internal fields
    if key:sub(1, 1) == "_" or key == "moduleName" or key == "baseDir" or 
       key == "useSeed" or key == "seed" or key == "schema" then
        rawset(self, key, value)
        return
    end
    -- Set via data storage with validation
    -- Use rawget to avoid triggering __index
    local data = rawget(self, "_data")
    if data then
        local ok, err = self:_validate(key, value)
        if not ok then
            error(err)
        end
        data[key] = value
    else
        rawset(self, key, value)
    end
end

--[[
    @brief Type validators
    
    This function list validates a configuration value based on the rules defined in the schema.
]]--
local validators = {
--[[
    @brief Validates a number value
    
    This function validates a configuration value based on the rules defined in the schema.
    @param value The value to validate.
    @param rules The validation rules for the value.
    @return A tuple (boolean, string) where the boolean indicates success and the string is an error message if validation fails.
]]--
    number = function(value, rules)
        if type(value) ~= "number" then
            return false, "Expected number, got " .. type(value)
        end
        if rules.min and value < rules.min then
            return false, string.format("Value %s is less than minimum %s", value, rules.min)
        end
        if rules.max and value > rules.max then
            return false, string.format("Value %s is greater than maximum %s", value, rules.max)
        end
        return true
    end,
    
--[[
    @brief Validates a string value
    
    This function validates a configuration value based on the rules defined in the schema.
    @param value The value to validate.
    @param rules The validation rules for the value.
    @return A tuple (boolean, string) where the boolean indicates success and the string is an error message if validation fails.
]]--
    string = function(value, rules)
        if type(value) ~= "string" then
            return false, "Expected string, got " .. type(value)
        end
        if rules.enum then
            local found = false
            for _, v in ipairs(rules.enum) do
                if v == value then found = true; break end
            end
            if not found then
                return false, string.format("Value '%s' not in allowed values: %s", 
                    value, table.concat(rules.enum, ", "))
            end
        end
        if rules.minLength and #value < rules.minLength then
            return false, string.format("String length %d is less than minimum %d", #value, rules.minLength)
        end
        if rules.maxLength and #value > rules.maxLength then
            return false, string.format("String length %d is greater than maximum %d", #value, rules.maxLength)
        end
        return true
    end,
    
--[[
    @brief Validates a boolean value
    
    This function validates a configuration value based on the rules defined in the schema.
    @param value The value to validate.
    @param rules The validation rules for the value.
    @return A tuple (boolean, string) where the boolean indicates success and the string is an error message if validation fails.
]]--
    boolean = function(value, rules)
        if type(value) ~= "boolean" then
            return false, "Expected boolean, got " .. type(value)
        end
        return true
    end,

--[[
    @brief Validates a table value
    
    This function validates a configuration value based on the rules defined in the schema.
    @param value The value to validate.
    @param rules The validation rules for the value.
    @return A tuple (boolean, string) where the boolean indicates success and the string is an error message if validation fails.
]]--
    table = function(value, rules)
        if type(value) ~= "table" then
            return false, "Expected table, got " .. type(value)
        end
        return true
    end
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

--[[
    Create a new Configs instance
    
    @param moduleName string - Name of the module (used for filename)
    @param options table - Configuration options:
        - useSeed boolean - Use galaxy seed in filename (default: onClient())
        - schema table - Validation schema for config values
        - baseDir string - Base directory (default: "moddata")
    @return Configs instance
    
    Example:
        local config = Configs:new("GateSettings", { ... })
--]]
function Configs:new(moduleName, options)
    -- Handle call variations (.new vs :new)
    -- If called with colon :new("Name"), self is Configs table
    -- If called with dot .new("Name"), self is "Name" (moduleName), and moduleName is options!
    
    -- Safety check: if user called Configs.new("Name"), 'self' will be "Name" string!
    if type(self) == "string" then
        -- Shift arguments
        options = moduleName
        moduleName = self
        self = Configs -- reset self to class
    end
    
    -- Initialize options after potential argument shifting
    options = options or {}

    local instance = setmetatable({}, Configs)
    
    -- Module identification
    instance.moduleName = moduleName or "Unknown"
    
    -- Storage options
    instance.baseDir = options.baseDir or "moddata"
    instance.useSeed = options.useSeed
    if instance.useSeed == nil then
        instance.useSeed = onClient()
    end
    instance.seed = instance.useSeed and tostring(GameSettings().seed) or ""
    
    -- Schema and validation
    instance.schema = options.schema or {}
    
    -- Config data storage
    instance._data = {}        -- Current values
    instance._comments = {}    -- Comments for values
    instance._loaded = false
    
    -- Initialize defaults from schema
    instance:_initDefaults()
    
    return instance
end

-- Callable syntax: Configs("Name", options)
setmetatable(Configs, {
    __call = function(_, ...)
        return Configs:new(...)
    end
})

-- ============================================================================
-- PRIVATE METHODS
-- ============================================================================

--[[
    Initialize default values from schema
--]]
function Configs:_initDefaults()
    for key, rules in pairs(self.schema) do
        if rules.default ~= nil then
            self._data[key] = rules.default
        end
        if rules.comment then
            self._comments[key] = rules.comment
        end
    end
end

--[[
    Validate a value against schema rules
    
    @param key string - Config key
    @param value any - Value to validate
    @return boolean, string - success and error message
--]]
function Configs:_validate(key, value)
    local rules = self.schema[key]
    if not rules then
        -- No schema for this key - allow any value
        return true
    end
    
    -- Check type
    if rules.type then
        local validator = validators[rules.type]
        if validator then
            local ok, err = validator(value, rules)
            if not ok then
                return false, string.format("[%s] %s: %s", self.moduleName, key, err)
            end
        end
    end
    
    -- Custom validator function
    if rules.validator and type(rules.validator) == "function" then
        local ok, err = rules.validator(value, rules)
        if not ok then
            return false, string.format("[%s] %s: %s", self.moduleName, key, err or "Custom validation failed")
        end
    end
    
    return true
end

--[[
    Get file path for config storage
    @return string - Full file path
--]]
function Configs:_getFilePath()
    local dir = self.baseDir
    
    if onServer() then
        dir = Server().folder .. "/" .. self.baseDir
    end
    
    return dir .. "/" .. self.moduleName .. self.seed .. ".lua"
end

-- ============================================================================
-- PUBLIC METHODS: GET/SET
-- ============================================================================

--[[
    Get a config value
    
    @param key string - Config key
    @param withMeta boolean - If true, return {value, comment} table
    @return any - Config value (or table with metadata if withMeta=true)
    
    Example:
        local distance = config:get("MaxDistance")
        local meta = config:get("MaxDistance", true)
        print(meta.value, meta.comment)
--]]
function Configs:get(key, withMeta)
    local value = self._data[key]
    
    if withMeta then
        return {
            value = value,
            comment = self._comments[key],
            schema = self.schema[key]
        }
    end
    
    return value
end

--[[
    Set a config value with validation
    
    @param key string - Config key
    @param value any - New value
    @param comment string - Optional comment
    @return boolean, string - success and error message
    
    Example:
        local ok, err = config:set("MaxDistance", 100)
        if not ok then
            print("Validation failed:", err)
        end
--]]
function Configs:set(key, value, comment)
    -- Validate
    local ok, err = self:_validate(key, value)
    if not ok then
        return false, err
    end
    
    -- Set value
    self._data[key] = value
    
    -- Set comment if provided
    if comment then
        self._comments[key] = comment
    end
    
    return true
end

--[[
    Get all config data
    
    @param withMeta boolean - Include metadata
    @return table - All config values
--]]
function Configs:getAll(withMeta)
    if withMeta then
        local result = {}
        for key, value in pairs(self._data) do
            result[key] = {
                value = value,
                comment = self._comments[key],
                schema = self.schema[key]
            }
        end
        return result
    end
    
    -- Return copy of data
    local result = {}
    for k, v in pairs(self._data) do
        result[k] = v
    end
    return result
end

--[[
    Set multiple values at once
    
    @param data table - Key-value pairs to set
    @return boolean, table - success and table of errors
--]]
function Configs:setAll(data)
    local errors = {}
    local allOk = true
    
    for key, value in pairs(data) do
        local ok, err = self:set(key, value)
        if not ok then
            errors[key] = err
            allOk = false
        end
    end
    
    return allOk, errors
end

-- ============================================================================
-- PUBLIC METHODS: SAVE/LOAD
-- ============================================================================

--[[
    Save config to file
    
    @return boolean, string - success and error message
--]]
function Configs:save()
    local filepath = self:_getFilePath()
    
    -- Build output with comments
    local output = "-- Config file for " .. self.moduleName .. "\n"
    output = output .. "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    
    -- Serialize data with comments
    output = output .. "configs = {\n"
    
    for key, value in pairs(self._data) do
        if type(value) ~= "function" then
            -- Format value based on type
            local formattedValue
            if type(value) == "string" then
                formattedValue = string.format("%q", value)
            elseif type(value) == "boolean" then
                formattedValue = tostring(value)
            elseif type(value) == "table" then
                formattedValue = TableShow(value, nil, "    ")
            else
                formattedValue = tostring(value)
            end

            local comment = self._comments[key]
            if comment ~= nil then
                output = output .. "    -- " .. comment .. "\n"
            end
            
            output = output .. string.format("    %s = %s,\n", key, formattedValue)
        end
    end
    
    output = output .. "}\n"
    
    -- Write file
    local file, err = io.open(filepath, "wb")
    if err then
        return false, string.format("Failed to save config '%s': %s", filepath, err)
    end
    
    file:write(output)
    file:close()
    
    return true
end

--[[
    Load config from file
    
    @return boolean, string - success and error message
--]]
function Configs:load()
    local filepath = self:_getFilePath()
    
    -- Read file
    local file, err = io.open(filepath, "rb")
    if err then
        -- File doesn't exist - use defaults
        self._loaded = true
        return self._data, nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Parse content
    -- Assuming TableShow saves as "configs = { ... }", wait.
    -- If it saves as "configs = { ... }", then we need to setfenv or access 'configs' global.
    -- But line 482 said: loadstring(content .. "; return configs").
    -- This implies the file creates a global named 'configs'.
    
    local func, err = loadstring(content .. "; return configs")
    if err then
        return self._data, string.format("Failed to parse config '%s': %s", filepath, err)
    end
    
    local data = func()
    if not data then
        return self._data, "Config file returned nil"
    end
    
    -- Load values with validation
    for key, value in pairs(data) do
        local ok, err = self:set(key, value)
        if not ok then
            -- Log warning but continue loading
            print(string.format("[WARNING][%s] %s", self.moduleName, err))
        end
    end
    
    -- Extract comments from file content
    self:_parseComments(content)
    
    self._loaded = true
    return self._data, nil
end

--[[
    Parse comments from file content
--]]
function Configs:_parseComments(content)
    -- Simple pattern: "-- comment\n    key = value"
    for comment, key in content:gmatch("%-%-([^\n]+)\n%s*([%w_]+)%s*=") do
        if not self._comments[key] then
            self._comments[key] = comment:match("^%s*(.-)%s*$") -- trim
        end
    end
end

--[[
    Check if config has been loaded
    @return boolean
--]]
function Configs:isLoaded()
    return self._loaded
end

--[[
    Reset to default values
--]]
function Configs:reset()
    self._data = {}
    self:_initDefaults()
end

-- ============================================================================
-- SCHEMA HELPERS
-- ============================================================================

--[[
    Get schema for a key
    @param key string
    @return table or nil
--]]
function Configs:getSchema(key)
    return self.schema[key]
end

--[[
    Add or update schema for a key
    @param key string
    @param rules table - Schema rules
--]]
function Configs:setSchema(key, rules)
    self.schema[key] = rules
    
    -- Initialize default if not set
    if rules.default ~= nil and self._data[key] == nil then
        self._data[key] = rules.default
    end
    if rules.comment then
        self._comments[key] = rules.comment
    end
end

return Configs

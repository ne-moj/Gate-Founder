package.path = package.path .. ";data/scripts/lib/?.lua"

local ColorGradient = include("colorgradient")

--[[
    ClosureColorsByDistantion - DEPRECATED
    
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025 
    License: MIT
    
    DEPRECATION NOTICE:
    This file is kept for backward compatibility only.
    The functionality has been split into two modules for better maintainability:
    
    - colorutils.lua: Basic color definitions and utilities
    - colorgradient.lua: Gradient generation logic
    
    NEW CODE SHOULD USE:
        local ColorGradient = include("colorgradient")
        local gradient = ColorGradient.createGradient(colors, minValue, maxValue, options)
    
    MIGRATION GUIDE:
        Old code:
            local gradient = ClosureColorsByDistantion({"red", "blue"}, 0, 100, false)
            local color = gradient(50)
        
        New code:
            local ColorGradient = include("colorgradient")
            local gradient = ColorGradient.createGradient(
                {"red", "blue"}, 
                0, 100,
                {offIntermediateColor = false}
            )
            local color = gradient(50)
    
    ORIGINAL DOCUMENTATION:
    Arguments:
       (enum) colors is the table (colors - 'black', 'white', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta'). 
              Example: {'red', 'blue', 'yellow'}
       (number) minValue
       (number) maxValue
       (boolean) offIntermediateColor - If true, skip automatic intermediate colors
       
    Return: function (value) {...}
    
    Example:
        local gradient = ClosureColors.byDistance({"red", "yellow", "green"}, 0, 100)
        local color = gradient(50)  -- Returns ColorRGB for middle value
--]]

--[[
    Create a color gradient function (DEPRECATED - use colorgradient.lua)
    
    @param colors table - Array of color names
    @param minValue number - Minimum value
    @param maxValue number - Maximum value
    @param offIntermediateColor boolean - Skip intermediate colors
    @return function - Gradient function(value) or nil on error
--]]
local ClosureColors = {}

function ClosureColors.byDistance(colors, minValue, maxValue, offIntermediateColor)
    -- Wrapper around new ColorGradient module
    return ColorGradient.createGradient(colors, minValue, maxValue, {
        offIntermediateColor = offIntermediateColor
    })
end

-- Return the function for backward compatibility
return ClosureColors

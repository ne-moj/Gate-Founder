package.path = package.path .. ";data/scripts/lib/?.lua"

local ColorUtils = include("colorutils")
local Logger = include('logger'):new('ColorGradient')

--[[
    ColorGradient - Color Gradient Generator
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Creates smooth color gradients with automatic intermediate color calculation.
    Extracted from closurecolors.lua for better modularity.
    
    USAGE:
        local ColorGradient = include("colorgradient")
        
        -- Create gradient function
        local gradient = ColorGradient.createGradient(
            {"red", "yellow", "green"},  -- Color sequence
            0,                            -- Min value
            100                           -- Max value
        )
        
        -- Use gradient
        local color = gradient(50)  -- Returns ColorRGB for value 50
        
        -- With options
        local gradient = ColorGradient.createGradient(
            {"red", "blue"},
            0, 100,
            {offIntermediateColor = true}  -- Skip intermediate colors
        )
    
    HOW IT WORKS:
        1. Takes a sequence of colors
        2. Automatically inserts intermediate colors for smooth transitions
        3. Returns a function that interpolates color for any value
        
        Example: red → green
        - Without intermediate: red → green (abrupt change)
        - With intermediate: red → yellow → green (smooth)
    
    INTERMEDIATE COLOR LOGIC:
        When transitioning between colors, an intermediate color is added if:
        - Multiple channels need to change
        - The change is not just on/off of one channel
        
        Examples:
        - red → yellow: No intermediate (just add green channel)
        - red → green: Intermediate yellow (turn off red, turn on green)
        - red → cyan: Intermediate white (opposite colors)
--]]

local ColorGradient = {}

--[[
    Find intermediate color for smooth transition
    
    @param startColor table - {R, G, B}
    @param endColor table - {R, G, B}
    @return string|nil - Name of intermediate color, or nil if not needed
    
    Algorithm:
        1. Calculate which channels change (XOR)
        2. If only 1 channel changes → no intermediate needed
        3. If 2-3 channels change → find best intermediate color
        4. Prefer OR combination, fallback to AND if OR = white
    
    Example:
        getIntermediateColor({1,0,0}, {0,1,0})  -- "yellow"
        getIntermediateColor({1,0,0}, {1,1,0})  -- nil (no intermediate)
--]]
function ColorGradient.getIntermediateColor(startColor, endColor)
    local intermediateColor = nil
    
    -- Calculate XOR to find which channels change
    local colorXor = ColorUtils.colorXor(startColor, endColor)
    
    -- Convert to bit masks for easier manipulation
    local startColorMask  = ColorUtils.colorToMask(startColor)
    local endColorMask    = ColorUtils.colorToMask(endColor)
    local colorChangeMask = bit32.lshift(colorXor.red, 2) + 
                            bit32.lshift(colorXor.green, 1) + 
                            colorXor.blue
    
    -- Count how many channels change
    local countChanges = colorXor.red + colorXor.green + colorXor.blue
    
    if countChanges > 1 then
        -- Check if we need an intermediate color
        local changeInStartColor = bit32.bxor(startColorMask, colorChangeMask)
        
        if not (changeInStartColor == 0 or changeInStartColor == colorChangeMask) then
            -- Need an extra color for the transition
            
            if countChanges == 3 then
                -- All three channels change (opposite colors)
                -- Use white as intermediate unless start/end is black/white
                if not (startColorMask == 0 or startColorMask == 0x7) then
                    intermediateColor = 'white'
                end
            else
                -- 2 channels change
                -- Try OR combination first (add channels)
                local newColorOr  = bit32.bor(startColorMask, colorChangeMask)
                local newColorAnd = bit32.band(startColorMask, colorChangeMask)
                
                local intermediateMask
                if newColorOr ~= 0x7 then
                    -- OR doesn't give white, use it
                    intermediateMask = newColorOr
                else
                    -- OR gives white, use AND instead
                    intermediateMask = newColorAnd
                end
                
                -- Convert mask back to color and find name
                local intermediateRgb = ColorUtils.maskToColor(intermediateMask)
                intermediateColor = ColorUtils.findColorName(intermediateRgb)
            end
        end
    end
    
    return intermediateColor
end

--[[
    Build complete color list with intermediate colors
    
    @param colorNames table - Array of color names
    @param offIntermediateColor boolean - If true, skip intermediate colors
    @return table - Array of color names with intermediates inserted
    
    Example:
        buildColorList({"red", "green"}, false)
        -- Returns: {"red", "yellow", "green"}
--]]
function ColorGradient._buildColorList(colorNames, offIntermediateColor)
    local allColors = {}
    local beforeColor = nil
    
    for _, colorName in ipairs(colorNames) do
        if not offIntermediateColor and beforeColor ~= nil then
            -- Check if we need an intermediate color
            local startRgb = ColorUtils.getColor(beforeColor)
            local endRgb = ColorUtils.getColor(colorName)
            local intermediate = ColorGradient.getIntermediateColor(startRgb, endRgb)
            
            if intermediate then
                table.insert(allColors, intermediate)
            end
        end
        
        table.insert(allColors, colorName)
        beforeColor = colorName
    end
    
    return allColors
end

--[[
    Interpolate color at given value
    
    @param value number - Value to interpolate
    @param allColors table - Array of color names
    @param minValue number - Minimum value
    @param maxValue number - Maximum value
    @return ColorRGB - Interpolated color
    
    Algorithm:
        1. Normalize value to [0, 1]
        2. Find which two colors to interpolate between
        3. Calculate interpolation factor
        4. Interpolate each RGB channel
--]]
function ColorGradient._interpolateColor(value, allColors, minValue, maxValue)
    -- Clamp value to min
    value = (value == nil or value < minValue) and minValue or value
    
    -- Normalize to [0, 1]
    local destination = ((value - minValue) / (maxValue - minValue))
    
    -- Find color indices
    local countAllColor = #allColors
    local numberFromColor = math.floor(destination * (countAllColor - 1)) + 1
    local numberToColor = numberFromColor + 1
    
    -- Calculate interpolation factor for this color pair
    local destinationForThisColor = destination * (countAllColor - 1) - (numberFromColor - 1)
    
    -- Get color names and RGB values
    local fromColor = allColors[numberFromColor]
    local toColor = allColors[numberToColor] ~= nil and allColors[numberToColor] or fromColor
    
    local valueFromColor = ColorUtils.getColor(fromColor)
    local valueToColor = ColorUtils.getColor(toColor)
    
    -- Start with fromColor
    local red   = valueFromColor[1]
    local green = valueFromColor[2]
    local blue  = valueFromColor[3]
    
    -- Interpolate each channel that changes
    if valueFromColor[1] ~= valueToColor[1] then
        -- Red channel changes
        red = valueFromColor[1] == 0 and destinationForThisColor or 1 - destinationForThisColor
    end
    
    if valueFromColor[2] ~= valueToColor[2] then
        -- Green channel changes
        green = valueFromColor[2] == 0 and destinationForThisColor or 1 - destinationForThisColor
    end
    
    if valueFromColor[3] ~= valueToColor[3] then
        -- Blue channel changes
        blue = valueFromColor[3] == 0 and destinationForThisColor or 1 - destinationForThisColor
    end
    
    return ColorRGB(red, green, blue)
end

--[[
    Create a gradient function
    
    @param colorNames table - Array of color names (e.g. {"red", "yellow", "green"})
    @param minValue number - Minimum value for gradient
    @param maxValue number - Maximum value for gradient
    @param options table - Optional settings:
        - offIntermediateColor: boolean - Skip automatic intermediate colors
    @return function|nil - Gradient function(value) or nil on error
    
    Example:
        local gradient = ColorGradient.createGradient({"red", "green"}, 0, 100)
        local color = gradient(50)  -- Returns ColorRGB for middle value
        
        -- Skip intermediate colors
        local gradient = ColorGradient.createGradient(
            {"red", "blue"}, 0, 100,
            {offIntermediateColor = true}
        )
--]]
function ColorGradient.createGradient(colorNames, minValue, maxValue, options)
    options = options or {}
    local offIntermediateColor = options.offIntermediateColor or false
    
    -- Validate all colors
    for _, colorName in ipairs(colorNames) do
        if not ColorUtils.isValidColor(colorName) then
            Logger:Error("Invalid color: %s", colorName)
            
            -- List available colors
            local availableColors = {}
            for name, _ in pairs(ColorUtils.COLORS) do
                table.insert(availableColors, "'"..name.."'")
            end
            Logger:Warning("Available colors: %s", table.concat(availableColors, ", "))
            
            return nil
        end
    end
    
    -- Build color list with intermediates
    local allColors = ColorGradient._buildColorList(colorNames, offIntermediateColor)
    
    -- Return closure function
    return function(value)
        return ColorGradient._interpolateColor(value, allColors, minValue, maxValue)
    end
end

return ColorGradient

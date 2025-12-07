package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    ColorUtils - Basic Color Utilities
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
    Provides basic color definitions and utility functions for color manipulation.
    Extracted from closurecolors.lua for better modularity and reusability.
    
    USAGE:
        local ColorUtils = include("colorutils")
        
        -- Validate color name
        if ColorUtils.isValidColor("red") then
            print("Valid color")
        end
        
        -- Get color RGB values
        local rgb = ColorUtils.getColor("red")  -- {1, 0, 0}
        
        -- Convert to bit mask
        local mask = ColorUtils.colorToMask(rgb)  -- 0b100 = 4
        
        -- Count active channels
        local count = ColorUtils.countChannels(rgb)  -- 1
    
    COLOR FORMAT:
        Colors are represented as tables: {R, G, B}
        where R, G, B are 0 or 1 (binary colors only)
        
        Example: {1, 0, 0} = red
                 {1, 1, 0} = yellow
                 {0, 1, 1} = cyan
    
    BIT MASK FORMAT:
        Colors can be represented as 3-bit masks: 0b00000RGB
        - Bit 2 (0x4): Red channel
        - Bit 1 (0x2): Green channel
        - Bit 0 (0x1): Blue channel
        
        Example: red = 0b100 = 4
                 yellow = 0b110 = 6
                 cyan = 0b011 = 3
--]]

local ColorUtils = {}

-- Available color definitions (binary RGB)
ColorUtils.COLORS = {
    black   = {0, 0, 0},
    white   = {1, 1, 1},
    red     = {1, 0, 0},
    green   = {0, 1, 0},
    blue    = {0, 0, 1},
    yellow  = {1, 1, 0},
    cyan    = {0, 1, 1},
    magenta = {1, 0, 1}
}

--[[
    Validate if a color name exists
    
    @param colorName string - Name of the color
    @return boolean - true if color exists
    
    Example:
        ColorUtils.isValidColor("red")  -- true
        ColorUtils.isValidColor("orange")  -- false
--]]
function ColorUtils.isValidColor(colorName)
    return ColorUtils.COLORS[colorName] ~= nil
end

--[[
    Get RGB values for a color name
    
    @param colorName string - Name of the color
    @return table|nil - {R, G, B} or nil if not found
    
    Example:
        local rgb = ColorUtils.getColor("red")  -- {1, 0, 0}
--]]
function ColorUtils.getColor(colorName)
    return ColorUtils.COLORS[colorName]
end

--[[
    Convert color RGB to bit mask
    
    @param color table - {R, G, B} where R,G,B are 0 or 1
    @return number - Bit mask 0b00000RGB
    
    Example:
        ColorUtils.colorToMask({1, 0, 0})  -- 4 (0b100)
        ColorUtils.colorToMask({1, 1, 0})  -- 6 (0b110)
--]]
function ColorUtils.colorToMask(color)
    return bit32.lshift(color[1], 2) + bit32.lshift(color[2], 1) + color[3]
end

--[[
    Convert bit mask to color RGB
    
    @param mask number - Bit mask 0b00000RGB
    @return table - {R, G, B}
    
    Example:
        ColorUtils.maskToColor(4)  -- {1, 0, 0} (red)
        ColorUtils.maskToColor(6)  -- {1, 1, 0} (yellow)
--]]
function ColorUtils.maskToColor(mask)
    return {
        bit32.rshift(bit32.band(mask, 0x4), 2),  -- Red
        bit32.rshift(bit32.band(mask, 0x2), 1),  -- Green
        bit32.band(mask, 1)                       -- Blue
    }
end

--[[
    Count active channels in a color
    
    @param color table - {R, G, B}
    @return number - Number of active channels (0-3)
    
    Example:
        ColorUtils.countChannels({1, 0, 0})  -- 1 (red only)
        ColorUtils.countChannels({1, 1, 0})  -- 2 (red + green)
        ColorUtils.countChannels({1, 1, 1})  -- 3 (all channels)
--]]
function ColorUtils.countChannels(color)
    return color[1] + color[2] + color[3]
end

--[[
    Get XOR difference between two colors
    
    @param color1 table - {R, G, B}
    @param color2 table - {R, G, B}
    @return table - {red, green, blue} with 1 where channels differ
    
    Example:
        ColorUtils.colorXor({1,0,0}, {0,1,0})  -- {red=1, green=1, blue=0}
--]]
function ColorUtils.colorXor(color1, color2)
    return {
        red   = tonumber(bit32.bxor(color1[1], color2[1])),
        green = tonumber(bit32.bxor(color1[2], color2[2])),
        blue  = tonumber(bit32.bxor(color1[3], color2[3]))
    }
end

--[[
    Find color name by RGB values
    
    @param color table - {R, G, B}
    @return string|nil - Color name or nil if not found
    
    Example:
        ColorUtils.findColorName({1, 0, 0})  -- "red"
--]]
function ColorUtils.findColorName(color)
    for name, rgb in pairs(ColorUtils.COLORS) do
        if rgb[1] == color[1] and rgb[2] == color[2] and rgb[3] == color[3] then
            return name
        end
    end
    return nil
end

return ColorUtils

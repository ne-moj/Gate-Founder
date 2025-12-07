package.path = package.path .. ";data/scripts/lib/?.lua"

--[[
    UI Helper Library
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    
    PURPOSE:
    Simplifies positioning and sizing of UI elements in Avorion.
    Automatically calculates positions based on padding and size constraints.
    
    USAGE:
        local cUI = include("ui")
        
        -- Create a new UI element helper
        local myButton = cUI:new("myButton")
        
        -- Set size
        myButton:updateSize(200, 40)
        
        -- Set padding (can be number or table)
        myButton:updatePadding(10)  -- All sides
        myButton:updatePadding({left = 10, top = 5, right = 10, bottom = 5})
        
        -- Set position (topLeft, bottomRight)
        myButton:updatePosition(vec2(0, 0), nil)  -- Only topLeft, bottomRight calculated
        
        -- Get Rect for creating UI element
        local button = tab:createButton(myButton:getRect(), "Click Me", "onButtonClick")
        
        -- Get all corner positions for chaining elements
        local positions = myButton:getPositions()
        nextElement:updatePosition(positions.bottomLeft, nil)
    
    COORDINATE SYSTEM:
        - topLeft = (x_min, y_min)
        - bottomRight = (x_max, y_max)
        - Padding is added INSIDE the element bounds
        
    EXAMPLE - Vertical stacking:
        local button1 = cUI:new("button1")
        button1:updateSize(200, 40)
        button1:updatePadding(10)
        button1:updatePosition(vec2(0, 0), nil)
        
        local button2 = cUI:new("button2")
        button2:updateSize(200, 40)
        button2:updatePadding(10)
        button2:updatePosition(button1:getPositions().bottomLeft, nil)
--]]

-- namespace UI
local UI = {}
local Logger = nil

--[[
    Create a new UI element helper
    
    @param name string - Name of the UI element (used for logging)
    @return UI instance
    
    Example:
        local myButton = UI:new("myButton")
--]]
function UI:new(name)
    local instance = {
		height = nil,
		width = nil,
		padding = { left = 10, top = 10, right = 10, bottom = 10 },
		position = {topLeft = nil, bottomRight = nil}
    }
    setmetatable(instance, self)
    self.__index = self
    self.name = name or "Unknown"
    
	Logger = include('logger'):new(name..':UI')
	
    return instance
end

--[[
    Update the size of the UI element
    
    @param width number|nil - Width in pixels (nil to keep current)
    @param height number|nil - Height in pixels (nil to keep current)
    
    Example:
        myButton:updateSize(200, 40)
        myButton:updateSize(nil, 50)  -- Only change height
--]]
function UI:updateSize (width, height)
	self.width = width ~= nil and width or self.width
	self.height = height ~= nil and height or self.height
	self:calcPosition()
end

--[[
    Update the padding of the UI element
    
    @param padding number|table - Padding in pixels
        - number: Apply to all sides
        - table: {left, top, right, bottom}
    
    Example:
        myButton:updatePadding(10)  -- All sides = 10
        myButton:updatePadding({left = 5, top = 10, right = 5, bottom = 10})
--]]
function UI:updatePadding (padding)
	if type(padding) == 'number' or type(padding) == 'string' then
		for k, _ in pairs(self.padding) do self.padding[k] = tonumber(padding) end
	elseif type(padding) == 'table' then
		for k, _ in pairs(self.padding) do
			if padding[k] ~= nil then
				self.padding[k] = tonumber(padding[k])
			end
		end
	end
	self:calcSize()
end

--[[
    Update the position of the UI element
    
    @param topLeft vec2|nil - Top-left corner position
    @param bottomRight vec2|nil - Bottom-right corner position
    
    Note: You can provide one or both corners. The missing corner
          will be calculated based on size and padding.
    
    Example:
        myButton:updatePosition(vec2(0, 0), nil)  -- Set topLeft, calculate bottomRight
        myButton:updatePosition(nil, vec2(200, 100))  -- Set bottomRight, calculate topLeft
--]]
function UI:updatePosition (topLeft, bottomRight)
	self.position.topLeft = topLeft ~= nil and topLeft or self.position.topLeft
	self.position.bottomRight = bottomRight ~= nil and bottomRight or self.position.bottomRight
	self:calcSize()
	self:calcPosition()
end

function UI:calcPosition ()
	if self.height and self.width then
		if self.position.topLeft == nil and self.position.bottomRight ~= nil then
			self.position.topLeft = vec2(self.position.bottomRight.x - (self.width + self.padding.left + self.padding.right), self.position.bottomRight.y - (self.height + self.padding.top + self.padding.bottom))
		elseif self.position.bottomRight == nil and self.position.topLeft ~= nil then
			self.position.bottomRight = vec2(self.position.topLeft.x + self.width + self.padding.left + self.padding.right, self.position.topLeft.y + self.height + self.padding.top + self.padding.bottom)
		end
	end
end

function UI:calcSize ()
	if self.position.topLeft and self.position.bottomRight then
		self.width = self.position.bottomRight.x - self.position.topLeft.x - (self.padding.top + self.padding.bottom)
		self.height = self.position.bottomRight.y - self.position.topLeft.y - (self.padding.left + self.padding.right)
	end
end

--[[
    Get all corner positions of the UI element
    
    @return table - Table with all corner positions:
        - topLeft / leftTop
        - topRight / rightTop
        - bottomLeft / leftBottom
        - bottomRight / rightBottom
    
    Example:
        local pos = myButton:getPositions()
        nextButton:updatePosition(pos.bottomLeft, nil)
--]]
function UI:getPositions ()
	if self.position.topLeft == nil or self.position.bottomRight == nil then
		Logger:Warning("Not set all positions")
		return nil
	end
	
	local rightTop = vec2(self.position.bottomRight.x, self.position.topLeft.y)
	local leftBottom = vec2(self.position.topLeft.x, self.position.bottomRight.y)
	
	return {
		leftTop     = self.position.topLeft,
		topLeft     = self.position.topLeft,
		rightTop    = rightTop,
		topRight    = rightTop,
		leftBottom  = leftBottom,
		bottomLeft  = leftBottom,
		rightBottom = self.position.bottomRight,
		bottomRight = self.position.bottomRight
	}
end

--[[
    Get Rect for creating UI element
    
    @return Rect - Rect object with padding applied, ready for UI creation
    
    Example:
        local button = tab:createButton(myButton:getRect(), "Click", "callback")
--]]
function UI:getRect ()
	if self.position.topLeft == nil or self.position.bottomRight == nil then
		Logger:Warning("Not set all positions")
		return nil
	end
	
	-- Return Rect with padding applied
	return Rect(
		vec2(self.position.topLeft.x + self.padding.left, self.position.topLeft.y + self.padding.top),
		vec2(self.position.bottomRight.x - self.padding.right, self.position.bottomRight.y - self.padding.bottom)
	)
end

return UI

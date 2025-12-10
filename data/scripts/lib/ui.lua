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

--[[
    Layout Engine: Split a Rect into multiple Rects
    
    @param rect Rect - The area to split
    @param ratios table - List of sizes. 
           > 0 : Fixed pixels (e.g., 100, 250)
           == 0: Dynamic "rest" space (shared equally)
    @param padding number|table - Padding inside each new cell (default 0).
    @param spacing number - Gap between cells (default 0).
    
    @return table - List of Rects
--]]
function UI:getRects(rect, ratios, padding, spacing, isVertical)
    local rects = {}
    local count = #ratios
    if count == 0 then return rects end
    
    spacing = spacing or 0
    padding = padding or 0
    
    -- Normalize padding to table
    local p = {left=0, top=0, right=0, bottom=0}
    if type(padding) == "number" then
        p = {left=padding, top=padding, right=padding, bottom=padding}
    elseif type(padding) == "table" then
        p.left = padding.left or 0
        p.top = padding.top or 0
        p.right = padding.right or 0
        p.bottom = padding.bottom or 0
    end

    -- Calculate total available size
    local totalSize = isVertical and rect.height or rect.width
    
    -- Calculate fixed used space
    local fixedUsed = 0
    local dynamicCount = 0
    
    for _, r in ipairs(ratios) do
        if r > 0 then
            fixedUsed = fixedUsed + r
        else
            dynamicCount = dynamicCount + 1
        end
    end
    
    -- Add total spacing
    local totalSpacing = math.max(0, count - 1) * spacing
    fixedUsed = fixedUsed + totalSpacing
    
    -- Calculate dynamic unit size
    local dynamicUnit = 0
    if dynamicCount > 0 then
        local remaining = math.max(0, totalSize - fixedUsed)
        dynamicUnit = remaining / dynamicCount
    end
    
    -- Generate Rects
    local currentPos = isVertical and rect.lower.y or rect.lower.x
    
    for _, r in ipairs(ratios) do
        local cellSize = (r > 0) and r or dynamicUnit
        
        local cellLower, cellUpper
        
        if isVertical then
            -- Vertical split: width is constant, height changes
            -- Top-down approach (in Avorion Y increases downwards? No, Y increases UPWARDS usually in math, but UI often differs. 
            -- In Avorion Rect: lower is bottom-left, upper is top-right usually?
            -- Let's check Avorion coordinate system.
            -- ScriptUI: 0,0 is TOP-LEFT. Y increases DOWNWARDS.
            -- Rect(lower, upper): lower=top-left, upper=bottom-right usually in 2D UI libs?
            -- Wait, Avorion Rect is usually Rect(vec2(x, y), vec2(w, h))? Or Rect(lower, upper)?
            -- Avorion Documentation: Rect(lower, upper).
            -- If 0,0 is top-left, then lower is top-left (min x, min y). Upper is bottom-right (max x, max y).
            
            -- Vertical split means splitting efficient HEIGHT.
            -- Adding to Y.
            
            local y1 = currentPos
            local y2 = currentPos + cellSize
            
            -- Apply padding
            local finalX1 = rect.lower.x + p.left
            local finalY1 = y1 + p.top
            local finalX2 = rect.upper.x - p.right
            local finalY2 = y2 - p.bottom
            
            table.insert(rects, Rect(vec2(finalX1, finalY1), vec2(finalX2, finalY2)))
            
            currentPos = currentPos + cellSize + spacing
        else
            -- Horizontal split: height is constant, width changes
            -- Adding to X.
            
            local x1 = currentPos
            local x2 = currentPos + cellSize
            
            local finalX1 = x1 + p.left
            local finalY1 = rect.lower.y + p.top
            local finalX2 = x2 - p.right
            local finalY2 = rect.upper.y - p.bottom
            
            table.insert(rects, Rect(vec2(finalX1, finalY1), vec2(finalX2, finalY2)))
            
            currentPos = currentPos + cellSize + spacing
        end
    end
    
    return rects
end

function UI:horizontalSplit(rect, ratios, padding, spacing)
    return self:getRects(rect, ratios, padding, spacing, false)
end

function UI:verticalSplit(rect, ratios, padding, spacing)
    return self:getRects(rect, ratios, padding, spacing, true)
end

--[[
    Create a Grid of Rects
    @param rect Rect - Area to fill
    @param rows number - Number of rows
    @param cols number - Number of cols
    @return table - table of Rects (row-major: [row][col])
--]]
function UI:grid(rect, rows, cols, padding, spacing)
    local grid = {}
    
    -- Generate row ratios (all dynamic 0)
    local rowRatios = {}
    for i=1, rows do table.insert(rowRatios, 0) end
    
    -- Generate col ratios
    local colRatios = {}
    for i=1, cols do table.insert(colRatios, 0) end
    
    -- 1. Split vertically into rows
    -- Note: We don't apply padding here yet, we pass 0 padding and spacing
    -- Actually we need spacing between rows
    spacing = spacing or 0
    local rowRects = self:verticalSplit(rect, rowRatios, 0, spacing)
    
    for r, rowRect in ipairs(rowRects) do
        grid[r] = {}
        -- 2. Split each row horizontally into cols
        -- Apply padding here!
        local colRects = self:horizontalSplit(rowRect, colRatios, padding, spacing)
        for c, cellRect in ipairs(colRects) do
            grid[r][c] = cellRect
        end
    end
    
    return grid
end

return UI

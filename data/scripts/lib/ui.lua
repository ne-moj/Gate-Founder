package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace UI
local UI = {}
local Logger = nil

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

function UI:updateSize (width, height)
	self.width = width ~= nil and width or self.width
	self.height = height ~= nil and height or self.height
	self:calcPosition()
end

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

function UI:getRect ()
	if self.position.topLeft == nil or self.position.bottomRight == nil then
		Logger:Warning("Not set all positions")
		return nil
	end
	
	return Rect(vec2(self.position.topLeft.x + self.padding.left, self.position.topLeft.y + self.padding.top), vec2(self.position.bottomRight.x - self.padding.right, self.position.bottomRight.y - self.padding.bottom))
end

return UI

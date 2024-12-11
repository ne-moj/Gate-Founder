local Logger  = include('logger'):new('ClosureColorsByDistantion')

--[[
   Author: Sergey Krasovsky
   Date:   December 11, 2024
   License: MIT
   
   Arguments:
      (enum) colors is the table (colors - 'black', 'white', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta'). Example: {'red', 'blue', 'yellow'}
      (number) minValue
      (number) maxValue
      
   Return: function (value) {...}
   
--]]
function ClosureColorsByDistantion (colors, minValue, maxValue, offIntermediateColor)
	offIntermediateColor = offIntermediateColor ~= nil and offIntermediateColor or false
	local inputError = false
	local availableColors = {
		black   = {0, 0, 0},
		white   = {1, 1, 1},
		red     = {1, 0, 0},
		green   = {0, 1, 0},
		blue    = {0, 0, 1},
		yellow  = {1, 1, 0},
		cyan    = {0, 1, 1},
		magenta = {1, 0, 1}
	}
	
	for k, v in pairs(colors) do
		if availableColors[v] == nil then
			inputError = true
			-- print('The '..v..' color is not available!')
			Logger:Warning('The %s color is not available!', v)
		end
	end
	
	if inputError then
		local namesAvailableColors = ''
		for k, _ in pairs(availableColors) do namesAvailableColors = namesAvailableColors.."'"..namesAvailableColors.."' " end
		-- print('Available colors: '..nameAvailableColors)
		Logger:Warning('Available colors: %s:', namesAvailableColors)
		
		return nil
	end
	
	--[[
		Cначала словами опишу что я думаю.
		нужно сделать переходы цветов следующим образом:
		1) Если нужно только погасить/установить один (или несколько) каналов цвета, например из красного сделать желтый (красный канал остается, а к нему прибавляется зеленый) или пурпурный
		
		В таком случае переход занимает один цикл
		red --> yellow
		R (1):
		1 *****
		0 .....
		
		G (0 --> 1):
		1 ``/** 
		0 */...
		
		B (0):
		1 `````
		0 *****
		
		2) Если нужно одновременно погасить и установить несколько каналов цвета, например из красного в зеленый
		в таком случае будет промежуточный переход, главное чтобы переход не был через белый или черные цвета (исключение противоположные цвета, их буду вести через белый)
		
		red --> (yellow) --> green
		R (1 --> 0):
		1 ***\```
		0 ....\**
		
		G (0 --> 1):
		1 ``/**** 
		0 */.....
		
		B (0):
		1 ```````
		0 *******
		
		red --> (black) --> green
		R (1 --> 0):
		1 *\`````
		0 ..\****
		
		G (0 --> 1):
		1 ````/**
		0 ***/...
		
		B (0):
		1 ```````
		0 *******
	--]]
	local getIntermediateColor = function (startColor, endColor)
		local intermediateColor = nil
		local colorXor = {
			red   = tonumber(bit32.bxor(startColor[1], endColor[1])),
			green = tonumber(bit32.bxor(startColor[2], endColor[2])),
			blue  = tonumber(bit32.bxor(startColor[3], endColor[3]))
		}
		
		-- 0000 0xxx (x = 1 or 0)
		--       RGB
		local startColorMask  = bit32.lshift(startColor[1], 2) + bit32.lshift(startColor[2], 1) + startColor[3]
		local endColorMask    = bit32.lshift(endColor[1], 2) + bit32.lshift(endColor[2], 1) + endColor[3]
		local colorChangeMask = bit32.lshift(colorXor.red, 2) + bit32.lshift(colorXor.green, 1) + colorXor.blue
		
		local countStartChannels = startColor[1] + startColor[2] + startColor[3]
		local countEndChannels = endColor[1] + endColor[2] + endColor[3]
		local countChanges = colorXor.red + colorXor.green + colorXor.blue
		if countChanges > 1 then
			local changeInStartColor = bit32.bxor(startColorMask, colorChangeMask)
			if not (changeInStartColor == 0 or changeInStartColor == colorChangeMask) then
				-- need an extra color for the transition
				-- detected color for transition
				if countChanges == 3 then
					-- change all three channels R,G,B (opposite colors)
					if not(startColorMask == 0 or startColorMask == 0x7) then
						-- it isn't black --> white or white --> black
						intermediateColor = 'white'
					end
				else
					local newColorOr  = bit32.bor(startColorMask, colorChangeMask)
					local newColorAnd = bit32.band(startColorMask, colorChangeMask)
					local valueIntermediateColor = {}
					
					if newColorOr ~= 0x7 then 
						-- 0000 0xxx
						--       RGB
						valueIntermediateColor.red   = bit32.rshift(bit32.band(newColorOr, 0x4), 2)
						valueIntermediateColor.green = bit32.rshift(bit32.band(newColorOr, 0x2), 1)
						valueIntermediateColor.blue  = bit32.band(newColorOr, 1)
					else
						-- 0000 0xxx
						--       RGB
						valueIntermediateColor.red   = bit32.rshift(bit32.band(newColorAnd, 0x4), 2)
						valueIntermediateColor.green = bit32.rshift(bit32.band(newColorAnd, 0x2), 1)
						valueIntermediateColor.blue  = bit32.band(newColorAnd, 1)
					end
					
					for k, v in pairs(availableColors) do
						if valueIntermediateColor.red == v[1] and valueIntermediateColor.green == v[2] and valueIntermediateColor[3] == v.blue then intermediateColor = k end
					end
				end
			end
		end
		
		return intermediateColor
	end
	
	local countAllColor = #colors
	local allColors = {}
	local beforeColor = nil
	local intermediateColor = nil
	for _, color in pairs(colors) do
		if not offIntermediateColor and beforeColor ~= nil then
			intermediateColor = getIntermediateColor(availableColors[beforeColor], availableColors[color])
			if intermediateColor then
				countAllColor = countAllColor + 1
				table.insert(allColors, intermediateColor)
			end
		end
		table.insert(allColors, color)
		beforeColor = color
	end
	
	return function (value)
		value = (value == nil or value < minValue) and minValue or value
		
		local destination = ((value - minValue) / (maxValue - minValue))
		local numberFromColor = math.floor(destination * (countAllColor - 1)) + 1
		local numberToColor = numberFromColor + 1
		
		local destinationForThisColor = destination * (countAllColor - 1) - (numberFromColor - 1)
		
		local fromColor = allColors[numberFromColor]
		local toColor = allColors[numberToColor] ~= nil and allColors[numberToColor] or fromColor
		
		local valueFromColor = availableColors[fromColor]
		local valueToColor = availableColors[toColor]
		
		local red   = valueFromColor[1]
		local green = valueFromColor[2]
		local blue  = valueFromColor[3]
		
		if valueFromColor[1] ~= valueToColor[1] then 
			red = valueFromColor[1] == 0 and destinationForThisColor or 1 - destinationForThisColor
		end
		
		if valueFromColor[2] ~= valueToColor[2] then 
			green = valueFromColor[2] == 0 and destinationForThisColor or 1 - destinationForThisColor
		end
		
		if valueFromColor[3] ~= valueToColor[3] then 
			blue = valueFromColor[3] == 0 and destinationForThisColor or 1 - destinationForThisColor
		end
		
		return ColorRGB(red, green, blue)
	end
end

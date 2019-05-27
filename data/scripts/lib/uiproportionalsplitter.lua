--[[
UIVerticalProportionalSplitter(Rect rect, int padding, int margin, table proportions)
Example:
UIVerticalProportionalSplitter(Rect(0, 0, 600, 30), 10, 0, { 0.5, 0.3, 0.45 })
 -> Rect(0, 0, 232, 30)
 -> Rect(242, 0, 381.2, 30)
 -> Rect(391.2, 0, 600, 0)
UIVerticalProportionalSplitter(Rect(0, 0, 700, 30), 10, 0, { 0.4, 20, 40, 0.6 }) - values > 0 treated as pixels:
 -> Rect(0, 0, 244, 30)
 -> Rect(254, 0, 274, 30)
 -> Rect(284, 0, 324, 30)
 -> Rect(334, 0, 700, 30)
]]
function UIVerticalProportionalSplitter(rect, padding, margin, proportions)
    local count = #proportions
    local width = rect.width - (count - 1) * padding
    local totalWeight = 0
    local totalAbsolute = 0
    local weight
    for i = 1, count do
        weight = proportions[i]
        if weight < 1 then
            totalWeight = totalWeight + weight
        else
            totalAbsolute = totalAbsolute + weight
        end
    end

    width = width - totalAbsolute
    local part = width / totalWeight
    local result = {}
    local x = rect.lower.x
    local startY = rect.lower.y + margin
    local endY = rect.upper.y - margin
    for i = 1, count do
        weight = proportions[i]
        if weight < 1 then
            result[#result+1] = Rect(x, startY, x + part * weight, endY)
            x = x + part * weight
        else
            result[#result+1] = Rect(x, startY, x + weight, endY)
            x = x + weight
        end
        x = x + padding
    end
    return result
end

function UIHorizontalProportionalSplitter(rect, padding, margin, proportions)
    local count = #proportions
    local height = rect.height - (count - 1) * padding
    local totalWeight = 0
    local totalAbsolute = 0
    local weight
    for i = 1, count do
        weight = proportions[i]
        if weight < 1 then
            totalWeight = totalWeight + weight
        else
            totalAbsolute = totalAbsolute + weight
        end
    end

    height = height - totalAbsolute
    local part = height / totalWeight
    local result = {}
    local y = rect.lower.y
    local startX = rect.lower.x + margin
    local endX = rect.upper.x - margin
    for i = 1, count do
        weight = proportions[i]
        if weight < 1 then
            result[#result+1] = Rect(startX, y, endX, y + part * weight)
            y = y + part * weight
        else
            result[#result+1] = Rect(startX, y, endX, y + weight)
            y = y + weight
        end
        y = y + padding
    end
    return result
end
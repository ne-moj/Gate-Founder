-- using this file to make sure that everything is synced

-- namespace GateFounder
GateFounder = {}

-- 1 - Found
-- 2 - Claim
-- 3 - Toggle
-- 4 - Destroy
-- 5 - (Un)lock
function GateFounder.todo(action, targetX, targetY, factionIndex, fromX, fromY, isEnabled)
    local key = 'gateFounder_'..targetX..'_'..targetY
    local value = action..','..factionIndex..','..fromX..','..fromY
    if isEnabled ~= nil then
        value = value..','..(isEnabled and '1' or '0')
    end
    local server = Server()
    local curValue = server:getValue(key)
    if curValue then
        server:setValue(key, curValue..";"..value)
    else
        server:setValue(key, value)
    end
end
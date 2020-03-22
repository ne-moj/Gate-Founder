-- using this file to make sure that everything is synced

package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- namespace GateFounder
GateFounder = {}

-- 1 - Found
-- 2 - Claim
-- 3 - Toggle
-- 4 - Destroy
function GateFounder.todo(action, targetX, targetY, factionIndex, fromX, fromY, isEnabled)
    local key = 'gateFounder_'..targetX..'_'..targetY
    local value = action..','..factionIndex..','..fromX..','..fromY
    if isEnabled ~= nil then
        value = value..','..(isEnabled and '1' or '0')
    end
    local curValue = Server():getValue(key)
    if curValue then
        Server():setValue(key, curValue..";"..value)
    else
        Server():setValue(key, value)
    end
end
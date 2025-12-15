if onServer() then
    local player = Player()
    local craft = player.craft
    player:addScriptOnce("data/scripts/lib/gate/service.lua")

    if not craft then return end
    -- craft:addScriptOnce("data/scripts/player/gatefounder_hotkey.lua")
end

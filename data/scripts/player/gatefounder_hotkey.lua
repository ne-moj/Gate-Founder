package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")

GateFounderHotkey = {}

function GateFounderHotkey.initialize()
    -- Initialize function if needed in future
end

if onServer() then
    function GateFounderHotkey.addGateSettings()
        local player = Player(callingPlayer)
        local craft = player.craft
        if not craft then return end

        local MESSAGE_TYPE_ERROR = 1 -- Assuming 1 is a standard error message type/color
        local MESSAGE_TYPE_SUCCESS = 3 -- Assuming 3 is a standard success message type/color
        
        local isPlayerOwnedCraft = (craft.isDrone or craft.isShip or craft.isStation) and not craft.aiOwned

        if not isPlayerOwnedCraft then
            player:sendChatMessage("GateSettings", MESSAGE_TYPE_ERROR, "Cannot load Gate Settings on this entity.")
            return
        end
        
        craft:addScriptOnce("data/scripts/entity/gatesettings")
        player:sendChatMessage("GateSettings", MESSAGE_TYPE_SUCCESS, "Gate Settings loaded to " .. (craft.name or "craft") .. ".")
    end
    callable(GateFounderHotkey, "addGateSettings")
end

if onClient() then
    function GateFounderHotkey.onKeyboardEvent(key, pressed)
        print("GateFounderHotkey.onKeyboardEvent(key, pressed)")
        if not pressed then return end
        
        -- Ctrl + Shift + G
        if key == KeyboardKey.G then
            local k = Keyboard()
            if (k:keyPressed(KeyboardKey.LControl) or k:keyPressed(KeyboardKey.RControl)) and
               (k:keyPressed(KeyboardKey.LShift) or k:keyPressed(KeyboardKey.RShift)) then
                
                invokeServerFunction("addGateSettings")
                return true
            end
        end
    end
end

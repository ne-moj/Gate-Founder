if onServer() then
	local entity = Entity()
	
	-- Add gatesettings.lua to drones, ships, and stations
    if (entity.isDrone or entity.isShip or entity.isStation) and not entity.aiOwned then
        entity:addScriptOnce("data/scripts/entity/gatesettings.lua")
    end
end

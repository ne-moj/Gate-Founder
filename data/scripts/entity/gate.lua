-- gates can't travel through gates
local old_canTransfer = Gate.canTransfer
function Gate.canTransfer(index)
    local entity = Sector():getEntity(index)
    if entity.hasComponent and entity:hasComponent(ComponentType.WormHole) then
        return 0
    end
    return old_canTransfer(index)
end
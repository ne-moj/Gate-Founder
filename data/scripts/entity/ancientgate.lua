-- gates can't travel through gates
function AncientGate.canTransfer(index)
    local entity = Sector():getEntity(index)
    if entity.hasComponent and entity:hasComponent(ComponentType.WormHole) then
        return 0
    end
    return enabledTime > 0
end
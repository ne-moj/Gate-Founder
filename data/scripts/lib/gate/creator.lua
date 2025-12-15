--[[
    Gate Creator v1.0
    Author: Sergey Krasovsky, Antigravity
    Date: December 2025
    License: MIT
    
    PURPOSE:
      This module is responsible for creating and configuring gate entities within the game world.
      It handles the generation of gate plans, styling based on faction, and initial setup of components.
    
    FEATURES:
       - Generates unique gate plans using PlanGenerator.
       - Applies faction-specific styling (colors) to gates.
       - Configures a comprehensive set of components for gate functionality (e.g., physics, wormhole, energy system).
       - Sets initial position, direction, and ownership for the created gate.
       - Attaches the main gate script for runtime behavior.
    
    USAGE:
        To create a new gate entity, call the `GateCreator.createGate` function:
        `local newGate = GateCreator.createGate(faction, originX, originY, targetX, targetY)`
        
        - `faction`: The Faction object associated with the gate's creator.
        - `originX, originY`: The X and Y coordinates of the gate's origin sector.
        - `targetX, targetY`: The X and Y coordinates of the gate's target sector.
        
        The function returns the newly created gate Entity.
--]]

if onClient() then return end
package.path = package.path .. ";data/scripts/lib/?.lua"

local PlanGenerator = include("plangenerator")
local StyleGenerator = include("internal/stylegenerator")
local GateConfig = include("gate/config")
local Logger = include("logger"):new("GateCreator")

local GateCreator = {}

--[[
    Create a gate entity
    
    @param faction Faction - The faction creating the gate
    @param x, y number - Origin sector coordinates
    @param tx, ty number - Target sector coordinates
    @return Entity - The created gate entity
--]]
function GateCreator.createGate(faction, x, y, tx, ty)
  Logger:Debug("Creator:createGate - faction:%s, (%d:%d) -> (%d:%d)", faction.name, x, y, tx, ty)

  local desc = EntityDescriptor()
  desc:addComponents(
    ComponentType.Plan,
    ComponentType.BspTree,
    ComponentType.Intersection,
    ComponentType.Asleep,
    ComponentType.DamageContributors,
    ComponentType.BoundingSphere,
    ComponentType.PlanMaxDurability,
    ComponentType.Durability,
    ComponentType.BoundingBox,
    ComponentType.Velocity,
    ComponentType.Physics,
    ComponentType.Scripts,
    ComponentType.ScriptCallback,
    ComponentType.Title,
    ComponentType.Owner,
    ComponentType.FactionNotifier,
    ComponentType.WormHole,
    ComponentType.EnergySystem,
    ComponentType.EntityTransferrer
  )
  
  local styleGenerator = StyleGenerator(faction.index)
  local c1 = styleGenerator.factionDetails.baseColor
  local c2 = ColorRGB(0.25, 0.25, 0.25)
  local c3 = styleGenerator.factionDetails.paintColor
  c1 = ColorRGB(c1.r, c1.g, c1.b)
  c3 = ColorRGB(c3.r, c3.g, c3.b)
  
  local plan = PlanGenerator.makeGatePlan(Seed(faction.index) + Server().seed, c1, c2, c3)
  local dir = vec3(tx - x, 0, ty - y)
  normalize_ip(dir)

  local position = MatrixLookUp(dir, vec3(0, 1, 0))
  position.pos = dir * 2000.0

  desc:setMovePlan(plan)
  desc.position = position
  desc.factionIndex = faction.index
  desc.invincible = true
  desc:setValue("gateFounder_origFaction", faction.index)
  desc:addScript("data/scripts/entity/gate.lua")

  local wormhole = desc:getComponent(ComponentType.WormHole)
  wormhole:setTargetCoordinates(tx, ty)
  wormhole.visible = false
  wormhole.visualSize = 50
  wormhole.passageSize = 50
  wormhole.oneWay = true

  return Sector():createEntity(desc, EntityArrivalType.Default)
end

return GateCreator

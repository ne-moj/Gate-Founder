# Avorion Scripting Architecture

## 1. Creating Objects (Entities)

Entities in Avorion (ships, stations, gates, etc.) are created within a specific `Sector`. The `Sector` class provides methods for spawning entities.

### Key Methods
*   `Sector():createShip(faction, name, plan, position)`
*   `Sector():createStation(faction, name, plan, position)`
*   `Sector():createEntity(descriptor, arrivalType)` - More generic method using an `EntityDescriptor`.

### Example (from `gatefounder.lua`)
```lua
local desc = EntityDescriptor()
desc:addComponents(
    ComponentType.Plan,
    ComponentType.BspTree,
    ComponentType.Intersection,
    ComponentType.Asleep,
    ComponentType.DamageContributors,
    ComponentType.BoundingSphere,
    ComponentType.BoundingBox,
    ComponentType.Velocity,
    ComponentType.Physics,
    ComponentType.Scripts,
    ComponentType.ScriptCallback,
    ComponentType.Title,
    ComponentType.Owner,
    ComponentType.Durability,
    ComponentType.WormHole
)
-- ... configuration of components ...
Sector():createEntity(desc, EntityArrivalType.Default)
```

## 2. Script Execution & Separation

Scripts in Avorion are often shared between Client and Server, but their execution paths diverge.

### The `initialize()` Function
*   **Called on BOTH**: server and client.
*   **Order**: Always calls on **Server** first.
*   **Data Passing**: Arguments passed to `Entity():addScript(script, arg1, arg2)` are received by `initialize(arg1, arg2)`.

### Client/Server Split
You must explicitly separate logic using checks or file separation.

#### Approach 1: `onServer()` / `onClient()` Checks
```lua
function MyScript.initialize()
    if onServer() then
        -- Server initialization (e.g., load data)
    else
        -- Client initialization (e.g., request data)
    end
end
```

#### Approach 2: Module Separation (Recommended)
This keeps code clean, as seen in `gatesettings.lua`.
```lua
-- main.lua
local Server = include("server")
local Client = include("client")

function MyScript.initialize()
    if onServer() then
        Server.initialize()
    else
        Client.initialize()
    end
end
```

### Communication
*   **Client -> Server**: `invokeServerFunction("funcName", args...)`
*   **Server -> Client**: `invokeClientFunction(player, "funcName", args...)`
*   **Security**: You must use `callable(Namespace, "funcName")` to allow remote calls.

## 3. How Scripts Start on the Client

1.  **Server Side**: Script is added to an entity (e.g., `Entity():addScript(...)`).
2.  **Replication**: The game engine replicates this entity to clients who are in the sector.
3.  **Client Side**: 
    *   The engine sees the script is attached.
    *   It loads the script file.
    *   It calls `initialize()` on the client instance.
4.  **UI Initialization**: If the player interacts with the entity, the engine calls `initUI()` (Client only).

### Client-Only Callbacks
These functions are **never** called on the server:
*   `initUI()`
*   `onInteract()`
*   `onShowWindow()`
*   `renderUI()`

### Summary
*   **Logic**: Shared file, split execution paths.
*   **State**: Not shared automatically. You must sync data manually using `invokeClientFunction`.
*   **UI**: Purely client-side, but triggers server actions via remote calls.

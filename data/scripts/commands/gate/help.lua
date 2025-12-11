package.path = package.path .. ";data/scripts/lib/?.lua"

local function help(playerIndex, args)
    local helpText = [[
Gate Founder Commands:

[User Commands:]
  /gate list              - List your gates
  /gate info <x> <y>      - Get gate information
  /gate create <x> <y>    - Create a new gate pair
  /gate toggle <x> <y>    - Enable/disable your gate
  /gate destroy <x> <y>   - Destroy your gate

[Admin Commands:]
  /gate admin list        - List all gates on server
  /gate admin tp <x> <y>  - Teleport to gate location
  /gate admin destroy <x> <y> - Force destroy any gate
  /gate admin transfer <x> <y> <owner> - Transfer ownership
  /gate config            - View/modify settings
  /gate config reload     - Reload configuration

[Examples:]
  /gate create 50 -30           - Show price for gate to (50, -30)
  /gate create 50 -30 confirm   - Create gate (pay and build)
  /gate info 50 -30             - Show gate details
  /gate toggle 50 -30           - Toggle gate on/off

Type "/gate help <command>" for detailed help on a specific command.
]]
    return 0, "", helpText
end

return help

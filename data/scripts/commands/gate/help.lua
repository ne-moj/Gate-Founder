if onClient() then return end

local function help(playerIndex, args)
  local helpText = ""

  local player = Player(playerIndex)

  -- if player is not found, then run from console
  if player then
    helpText = [[
Gate Founder Commands:

[User Commands]:
  /gate list [options]    - List your gates
  /gate info <x> <y>      - Get gate information
  /gate cost <x> <y>      - Get gate founding cost
  /gate create <x> <y>    - Create a new gate pair
  /gate toggle <x> <y>    - Enable/disable your gate
  /gate destroy <x> <y>   - Destroy your gate

]]
  end

  -- Check admin privileges
  if not player or Server():hasAdminPrivileges(player) then
    helpText = helpText .. [[
[Admin Commands]:
  /gate admin list                 - List all gates on server
  /gate admin tp <x> <y>           - Teleport to gate location
  /gate admin destroy <x> <y>      - Force destroy any gate
  /gate admin transfer <x> <y> <owner> - Transfer ownership
  /gate config                     - View/modify settings
  /gate config reload              - Reload configuration

]]
  end

  -- if player is not found, then run from console
  if player then
    helpText = helpText .. [[
[Examples]:
  /gate list                  - List your gates
  /gate cost 50 -30           - Show price for gate to (50, -30)
  /gate create 50 -30         - Create gate (pay and build)
  /gate info 50 -30           - Show gate details
  /gate toggle 50 -30         - Toggle gate on/off
  /gate destroy 50 -30        - Destroy your gate

]]
  else
    helpText = helpText .. [[
[Examples]:
  /gate admin list                 - List all gates on server
  /gate admin tp 50 -30            - Teleport to gate location
  /gate admin destroy 50 -30       - Destroy any gate
  /gate admin transfer 50 -30 user - Transfer ownership
  /gate config                     - View/modify settings
  /gate config reload              - Reload configuration

]]
  end
  helpText = helpText .. [[
Type "/gate <command> help" for detailed help on a specific command.
]]

  return 0, "", helpText
end

return help

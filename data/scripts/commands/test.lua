package.path = package.path .. ";data/scripts/lib/?.lua"

local Ini = include("ini")

function execute(playerIndex, commandName, param)
	if playerIndex == nil then
		-- invokeFactionFunction(nil, true, "test.lua", "found", x, y, con, true)
		return 0, "", "Приветствую Хозяин, мое почтение!"
	end
	
    local player = Player(playerIndex)
    if not player then
        return 1, "Игрока не существует", "Вы кто таки? Я вас не звал идие на..."
    end

    if not player.craft then
        return 1, "You're not in a ship!", "Ты чё бездомный штоле? Где корабль потерял"
    end
    
    local x, y = player:getSectorCoordinates()
    --Entity():addScript("lib/test.lua")
    --invokeClientFunction(player, "createGate", x, y)
    print(x, y)

	-- Загрузить данные
	local loadedData = Ini:loadData("./moddata/gatesettings.ini")
	print(loadedData.Settings.version)


    return 0, "", ""
end

function getDescription()
    return "Тестовая функция."
end

function getHelp()
    return [[Allows to found gates. Usage:
    /test - тестовая функция]]
end

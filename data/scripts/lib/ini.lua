-- Класс для работы с Ini файлами

local Ini = {}

--- сохранить данные в ini-файл
--- @param filename string
--- @param data table
--- @return void
function Ini.saveData(filename, data)
	local file = io.open(filename, "w")
	if file then
		if data ~= nil then
			for section, values in pairs(data) do
				file:write("[" .. section .. "]\n")
				for key, value in pairs(values) do
					file:write(key .. " = " .. tostring(value) .. "\n")
				end
			end
		else
			file:write("")
		end
		file:close()
	else
		print("Ошибка: Не удалось открыть файл для записи")
	end
end

--- загрузить данные с ini-файла
--- @param filename string
--- @return table
function Ini.loadData(filename)
	local file = io.open(filename, "r")
	if not file then return nil end

	local data, section = {}, nil
	for line in file:lines() do
		local s = line:match("^%[(.+)%]$")
		if s then
			section = s
			data[section] = {}
		elseif section then
			local key, value = line:match("^(.-)%s*=%s*(.+)$")
			if key and value then
				data[section][key] = value
			end
		end
	end
	file:close()
	return data
end

return Ini

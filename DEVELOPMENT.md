# Gate Founder 2.0 - Полная документация разработки

## Обзор проекта

**Gate Founder 2.0** - это мод для Avorion, который позволяет игрокам и альянсам создавать варп-ворота между секторами. Мод основан на оригинальном Gate Founder и добавляет расширенную систему управления и настройки.

### Текущая версия конфигурации: 1.3

---

## НОВОЕ: Архитектура Client-Server

### Что такое Client и Server в Avorion?

Avorion использует **клиент-серверную архитектуру** даже в одиночной игре:

#### Server (Сервер)
- **Авторитетный источник данных** - хранит истинное состояние игры
- **Выполняет игровую логику** - расчеты, проверки, физику
- **Управляет сохранениями** - записывает и читает данные
- **Работает всегда** - даже в single-player режиме

#### Client (Клиент)
- **Отображает UI** - все окна, кнопки, меню
- **Отправляет запросы** - действия игрока отправляются на сервер
- **Получает обновления** - сервер отправляет изменения для отображения
- **Не хранит данные** - все данные на сервере

### Проверка стороны выполнения

```lua
if onServer() then
    -- Этот код выполняется ТОЛЬКО на сервере
    -- Здесь: расчеты, проверки, сохранение данных
end

if onClient() then
    -- Этот код выполняется ТОЛЬКО на клиенте
    -- Здесь: UI, отображение, пользовательский ввод
end
```

### Синхронизация Client ↔ Server

#### Вызов с клиента на сервер:
```lua
-- CLIENT: Игрок нажал кнопку
function MyMod.onButtonClick()
    if onClient() then
        invokeServerFunction("processAction", arg1, arg2)
        return
    end
end

-- SERVER: Обработка действия
function MyMod.processAction(arg1, arg2)
    local player = Player(callingPlayer)  -- Кто вызвал
    -- ... логика ...
    invokeClientFunction(player, "showResult", result)
end
callable(MyMod, "processAction")  -- ОБЯЗАТЕЛЬНО!
```

#### Вызов с сервера на клиент:
```lua
-- SERVER: Отправка данных клиенту
function MyMod.sendDataToClient()
    local player = Player(callingPlayer)
    local data = { value = 123 }
    invokeClientFunction(player, "receiveData", data)
end

-- CLIENT: Получение и отображение
function MyMod.receiveData(data)
    if onClient() then
        -- Обновить UI
        myLabel.caption = tostring(data.value)
    end
end
callable(MyMod, "receiveData")  -- ОБЯЗАТЕЛЬНО!
```

### Важные правила

1. **Никогда не доверяйте клиенту** - всегда проверяйте данные на сервере
2. **Данные только на сервере** - клиент не должен хранить критичные данные
3. **UI только на клиенте** - сервер не создает окна
4. **callable() обязателен** - без него функция не будет вызываться

---

## НОВОЕ: Система хранения данных

### Нет SQL базы данных!

Avorion **НЕ использует SQL** или реляционные базы данных. Вместо этого используется **key-value хранилище**.

### Три типа хранилищ

#### 1. Server Values (Глобальные данные сервера)

**Назначение**: Временные данные для синхронизации между секторами

```lua
-- Сохранение
local server = Server()
server:setValue("my_key", "my_value")

-- Чтение
local value = server:getValue("my_key")

-- Удаление
server:setValue("my_key")  -- nil = удалить
```

**Использование в моде**:
- Хранение "todo list" для незагруженных секторов
- Ключ: `gateFounder_X_Y` (координаты сектора)
- Значение: строка с действиями `"action,faction,fromX,fromY;action2,..."`

**Пример**:
```lua
-- galaxy/gatefounder.lua
local key = 'gateFounder_100_200'
local value = '1,12345,50,60'  -- action=1 (found), faction=12345, from=(50,60)
Server():setValue(key, value)
```

**⚠️ Важно**: 
- Данные **НЕ сохраняются** при перезапуске сервера
- Используются только для временной синхронизации
- Очищаются после обработки

#### 2. Faction Values (Данные фракции)

**Назначение**: Постоянные данные, привязанные к фракции/игроку

```lua
-- Сохранение
local faction = Faction()
faction:setValue("gates_founded", 5)

-- Чтение
local gateCount = faction:getValue("gates_founded") or 0

-- Работает для Player тоже (Player наследует Faction)
local player = Player()
player:setValue("my_data", "value")
```

**Использование в моде**:
- `gates_founded` - количество построенных ворот фракцией
- Сохраняется в базе данных галактики
- **Переживает перезапуск сервера**

**Пример**:
```lua
-- player/gatefounder.lua
local buyer = Faction(factionIndex)
local gateCount = buyer:getValue("gates_founded") or 0
buyer:setValue("gates_founded", gateCount + 1)
```

#### 3. Entity Values (Данные сущности)

**Назначение**: Данные, привязанные к конкретному объекту (корабль, станция, ворота)

```lua
-- Сохранение
local entity = Entity()
entity:setValue("custom_data", 123)

-- Чтение
local data = entity:getValue("custom_data")
```

**Использование в моде**:
- `gateFounder_origFaction` - индекс фракции, которая построила ворота
- Сохраняется вместе с сущностью
- **Переживает перезапуск сервера**

**Пример**:
```lua
-- entity/gate.lua
local entity = Entity()
local originalOwner = entity:getValue("gateFounder_origFaction")
if originalOwner then
    -- Это ворота, построенные игроком
end
```

#### 4. Configs (Файловое хранилище)

**Назначение**: Настройки мода, конфигурация

```lua
-- lib/configs.lua
local Configs = include("configs"):new("ModuleName")

-- Сохранение
local data = {
    Settings = {
        MaxDistance = 45,
        MaxGatesPerFaction = 5
    }
}
Configs:save(data)

-- Загрузка
local data = Configs:load()
```

**Расположение файла**: `mods/ModuleName/moddata/ModuleName.lua`

**Использование в моде**:
- Настройки из UI админа (`gatesettings.lua`)
- Сохраняются в файл
- **Переживают перезапуск сервера**

### Сравнение хранилищ

|       Тип      |  Постоянство  | Область видимости | Использование |
|----------------|---------------|-------------------|---------------|
| Server Values  | ❌ Временные  | Весь сервер       | Синхронизация между секторами |
| Faction Values | ✅ Постоянные | Одна фракция      | Статистика игрока/альянса |
| Entity Values  | ✅ Постоянные | Одна сущность     | Метаданные объекта |
| Configs        | ✅ Постоянные | Весь мод          | Настройки мода |

### Масштабируемость

**Вопрос**: Что если будет 1000+ ворот?

**Ответ**: Система Avorion справится:

1. **Entity Values** - каждые ворота хранят свои данные отдельно
2. **Faction Values** - только счетчик (1 число на фракцию)
3. **Server Values** - очищаются после обработки
4. **Configs** - маленький файл с настройками

**Оптимизация не требуется** для разумного количества ворот (до 10,000+).

Если нужна более сложная БД:
- Можно использовать SQLite через LuaSQL
- Или JSON файлы для сложных структур
- Но для этого мода **не нужно**

---

## НОВОЕ: Тестирование мода

### Подготовка к тестированию

#### 1. Установка мода

**Способ 1: Локальная разработка**
```
1. Скопировать папку мода в:
   C:\Users\<USER>\AppData\Roaming\Avorion\mods\Gate-Founder-2.0\

2. Структура должна быть:
   mods/
   └── Gate-Founder-2.0/
       ├── modinfo.lua
       └── data/
           └── scripts/
               └── ...
```

**Способ 2: Через Steam Workshop** (для публикации)
```
1. В игре: Mods → Upload Mod
2. Выбрать папку мода
3. Заполнить описание
4. Опубликовать
```

#### 2. Включение мода

```
1. Запустить Avorion
2. Mods → Installed Mods
3. Найти "Gate Founder v2.0"
4. Поставить галочку
5. Restart Required → Перезапустить игру
```

#### 3. Проверка загрузки

```
1. Запустить игру
2. Открыть консоль (~ или F12)
3. Проверить логи:
   - Нет ошибок Lua
   - Мод загружен
```

### Тестирование в Single Player

#### Тест 1: Создание ворот через команду

```
1. Создать новую игру или загрузить сохранение
2. Построить корабль с гипердвигателем
3. Прыгнуть в любой сектор (например, 10:10)
4. Открыть консоль (~)
5. Ввести: /foundgate 20 20
   → Должна показаться цена
6. Ввести: /foundgate 20 20 confirm
   → Должны создаться ворота
7. Проверить:
   - Ворота появились в секторе
   - Можно взаимодействовать (F)
   - Показывают координаты назначения
8. Прыгнуть в сектор 20:20
9. Проверить:
   - Ворота появились автоматически
   - Ведут обратно в 10:10
```

#### Тест 2: Создание через Station Founder

```
1. Найти верфь (Shipyard)
2. Построить Station Founder корабль
3. Выбрать опцию "Gate" вместо станции
4. В окне ввести координаты (например, 30:30)
5. Нажать "Transform"
6. Проверить:
   - Корабль исчез
   - Ворота появились
   - Парные ворота в 30:30
```

#### Тест 3: Управление воротами

```
1. Подлететь к воротам
2. Нажать F → "Manage gates"
3. Проверить доступные действия:
   - Toggle on/off
   - Destroy
4. Выбрать "Toggle off"
5. Попробовать пройти через ворота
   → Должен быть отказ
6. Toggle on
7. Пройти через ворота
   → Должен телепортироваться
```

#### Тест 4: UI настроек (для админа)

```
1. Построить любой корабль/станцию
2. Добавить скрипт через консоль:
   /run Entity():addScript("data/scripts/entity/gatesettings.lua")
3. Нажать F → должна быть опция "Gate Settings"
4. Открыть окно настроек
5. Проверить вкладки:
   - Main: ✅ Должна работать
   - Access: ✅ Должна работать
   - Price: ❌ Отсутствует
   - Additional: ❌ Отсутствует
6. Изменить MaxDistance на вкладке Main
7. Нажать "Save Settings"
8. Перезапустить игру
9. Проверить, что настройка сохранилась
```

#### Тест 5: Конфигурация через файл

```
1. Закрыть игру
2. Открыть файл:
   mods/GateFounder/config.ini
3. Изменить параметр:
   MaxDistance = 100
4. Сохранить файл
5. Запустить игру
6. Попробовать создать ворота на расстоянии > 45
   → Должно разрешить (если < 100)
```

### Тестирование в Multiplayer

#### Настройка тестового сервера

```
1. Запустить Avorion
2. Multiplayer → Start Server
3. Настройки:
   - Server Name: "Test Gate Founder"
   - Password: (опционально)
   - Mods: Включить Gate Founder
4. Start Server
```

#### Тест 1: Синхронизация между игроками

```
Игрок 1:
1. Создать ворота в секторе 10:10 → 20:20
2. Остаться в секторе 10:10

Игрок 2:
1. Подключиться к серверу
2. Прыгнуть в сектор 20:20
3. Проверить:
   - Ворота появились автоматически
   - Ведут в 10:10

Игрок 1:
4. Toggle off ворота

Игрок 2:
5. Попробовать пройти
   → Должен быть отказ (синхронизация работает)
```

#### Тест 2: Права альянса

```
1. Создать альянс
2. Пригласить второго игрока
3. Игрок 1 (лидер):
   - Создать ворота
4. Игрок 2 (член):
   - Попробовать Toggle
   → Должен быть отказ (нет прав)
5. Игрок 1:
   - Дать права "Manage Stations"
6. Игрок 2:
   - Попробовать Toggle снова
   → Должно работать
```

#### Тест 3: Админские команды

```
Админ:
1. Открыть консоль
2. /foundgate 50 50 cheat
   → Создать ворота бесплатно
3. /foundgate 60 60 cheat PlayerName
   → Создать ворота для другого игрока
4. Проверить:
   - Ворота созданы
   - Принадлежат указанному игроку
```

### Проверка логов

#### Где найти логи:

```
C:\Users\<USER>\AppData\Roaming\Avorion\logs\
```

#### Что искать:

```
1. Ошибки Lua:
   [ERROR] ... attempt to index nil value

2. Логи мода (если LogLevel >= 3):
   [GateFounder][INFO] Player:GateFounder - found
   [GateFounder][DEBUG] Spawn a gate back for faction...

3. Предупреждения:
   [WARNING] Failed to mark gate for creation
```

### Автоматизация тестирования

#### Создание тестового скрипта

```lua
-- data/scripts/commands/testgates.lua
function execute(sender, commandName)
    local player = Player(sender)
    local x, y = Sector():getCoordinates()
    
    -- Тест 1: Создание ворот
    print("Test 1: Creating gates...")
    player:invokeFunction("gatefounder.lua", "found", x+10, y+10, "cheat")
    
    -- Тест 2: Проверка количества
    local count = player:getValue("gates_founded") or 0
    print("Gates founded:", count)
    
    -- Тест 3: Toggle
    print("Test 3: Toggling gates...")
    -- ... и т.д.
    
    return 0, "", "Tests completed!"
end
```

---

## НОВОЕ: Список всех команд

### Команды игрока

#### `/foundgate x y`
**Описание**: Показать стоимость создания ворот  
**Параметры**:
- `x` - координата X назначения
- `y` - координата Y назначения

**Пример**:
```
/foundgate 100 200
→ "Founding a gate from (10:10) to (100:200) will cost 450000 credits. Repeat command with additional 'confirm' in the end to found a gate."
```

**Проверки**:
- Игрок в корабле
- Расстояние <= MaxDistance
- Не в рифт
- Не через барьер (если запрещено)
- Не к центру (0:0) (если запрещено)
- Фракция не достигла лимита ворот
- Нет существующих ворот в этом направлении

---

#### `/foundgate x y confirm`
**Описание**: Создать пару ворот (платно)  
**Параметры**:
- `x` - координата X назначения
- `y` - координата Y назначения
- `confirm` - подтверждение

**Пример**:
```
/foundgate 100 200 confirm
→ Списывает кредиты, создает ворота
→ "Successfully founded a gate from (10:10) to (100:200)."
```

**Эффекты**:
- Списывает кредиты с фракции
- Создает ворота в текущем секторе
- Создает парные ворота в целевом секторе (или помечает для создания)
- Увеличивает счетчик `gates_founded`

---

#### `/foundgate x y cheat` (только админ)
**Описание**: Создать ворота бесплатно, игнорируя ограничения  
**Параметры**:
- `x` - координата X назначения
- `y` - координата Y назначения
- `cheat` - режим админа

**Пример**:
```
/foundgate 0 0 cheat
→ Создает ворота к центру галактики (обычно запрещено)
```

**Игнорируемые проверки**:
- Стоимость (бесплатно)
- MaxDistance
- Барьер
- Центр галактики
- Лимит ворот
- Владение сектором
- Необходимость корабля в целевом секторе

---

#### `/foundgate x y cheat <faction_index|player_name>` (только админ)
**Описание**: Создать ворота для другой фракции/игрока  
**Параметры**:
- `x` - координата X назначения
- `y` - координата Y назначения
- `cheat` - режим админа
- `faction_index` - индекс фракции (число)
- `player_name` - имя онлайн игрока (строка)

**Примеры**:
```
/foundgate 50 50 cheat 12345
→ Создает ворота для фракции с индексом 12345

/foundgate 50 50 cheat "PlayerName"
→ Создает ворота для игрока PlayerName (должен быть онлайн)
```

---

### Взаимодействие с воротами (UI)

#### "Manage gates"
**Доступ**: Нажать F на воротах  
**Действия**:

1. **Toggle on/off**
   - Требует: AlliancePrivilege.ManageStations (или админ)
   - Эффект: Включает/выключает ворота
   - Заблокировано если: ворота заблокированы админом

2. **Destroy**
   - Требует: AlliancePrivilege.FoundStations (или админ)
   - Эффект: Уничтожает пару ворот
   - Уменьшает счетчик `gates_founded`
   - Заблокировано если: ворота заблокированы админом
   - Ограничения:
     - Если `CapturedBuiltGatesCanBeDestroyed = false`: только оригинальный строитель
     - Если `CapturedNPCGatesCanBeDestroyed = false`: нельзя уничтожить захваченные NPC ворота

3. **Lock/Unlock** (только админ)
   - Эффект: Блокирует/разблокирует ворота от изменений владельцами
   - Заблокированные ворота нельзя Toggle или Destroy

---

### Тестовые команды (для разработки)

#### `/hellostation`
**Описание**: Тестовая команда для создания станции с скриптом  
**Файл**: `commands/hellostation.lua`  
**Использование**: Для тестирования скриптов на станциях

---

#### `/test`
**Описание**: Тестовая команда для загрузки INI файла  
**Файл**: `commands/test.lua`  
**Использование**: Для тестирования системы конфигурации

---

## НОВОЕ: Создание консольных команд

### Текущая ситуация

Сейчас есть только **одна команда**: `/foundgate`

Все остальные действия через **UI взаимодействие** (нажать F на воротах).

### Предложение: Добавить консольные команды

#### 1. `/gatelist` - Список ворот игрока

**Назначение**: Показать все ворота, построенные игроком/альянсом

**Реализация**:
```lua
-- data/scripts/commands/gatelist.lua
function execute(sender, commandName)
    local player = Player(sender)
    local faction = player.alliance or player
    
    -- Получить все сектора с воротами
    local gates = {}
    -- ... поиск ворот в галактике ...
    
    -- Вывод списка
    player:sendChatMessage("", 0, "Your gates:")
    for i, gate in ipairs(gates) do
        player:sendChatMessage("", 0, "%i. (%i:%i) → (%i:%i)", 
            i, gate.fromX, gate.fromY, gate.toX, gate.toY)
    end
    
    return 0, "", ""
end

function getDescription()
    return "List all gates founded by your faction"
end

function getHelp()
    return "Usage: /gatelist"
end
```

**Проблема**: Нет простого способа найти все ворота в галактике без загрузки всех секторов.

**Решение**: Хранить список ворот в Faction Values:
```lua
-- При создании ворот
local gatesList = faction:getValue("gates_list") or ""
gatesList = gatesList .. string.format("%i,%i,%i,%i;", x, y, tx, ty)
faction:setValue("gates_list", gatesList)
```

---

#### 2. `/gatetoggle x y` - Toggle ворот через команду

**Назначение**: Включить/выключить ворота без UI

**Реализация**:
```lua
-- data/scripts/commands/gatetoggle.lua
function execute(sender, commandName, x, y)
    local player = Player(sender)
    x = tonumber(x)
    y = tonumber(y)
    
    if not x or not y then
        return 1, "", "Usage: /gatetoggle x y"
    end
    
    -- Проверить, что сектор загружен
    if not Galaxy():sectorLoaded(x, y) then
        return 1, "", "Sector not loaded. Jump there first."
    end
    
    -- Вызвать функцию toggle
    invokeSectorFunction(x, y, true, "gatefounder.lua", "toggleGateByCoords", 
        player.index, x, y)
    
    return 0, "", "Gate toggled"
end
```

**Новая функция в sector/gatefounder.lua**:
```lua
function GateFounder.toggleGateByCoords(playerIndex, tx, ty)
    local player = Player(playerIndex)
    local faction = player.alliance or player
    
    -- Найти ворота в текущем секторе, ведущие в tx:ty
    local gates = {Sector():getEntitiesByScript("gate.lua")}
    for _, gate in pairs(gates) do
        local wh = WormHole(gate)
        local gx, gy = wh:getTargetCoordinates()
        if gx == tx and gy == ty then
            -- Проверить права
            if checkEntityInteractionPermissions(gate, AlliancePrivilege.ManageStations) then
                local newPower = not Gate.getPower()
                gate:invokeFunction("gate.lua", "setPower", newPower)
                player:sendChatMessage("", 0, "Gate toggled %s", 
                    newPower and "on" or "off")
                return
            else
                player:sendChatMessage("", 1, "No permissions")
                return
            end
        end
    end
    
    player:sendChatMessage("", 1, "Gate not found")
end
```

---

#### 3. `/gatedestroy x y` - Уничтожение ворот через команду

**Назначение**: Уничтожить ворота без UI

**Реализация**: Аналогично `/gatetoggle`, но вызывает `gateFounder_onDestroy`

---

#### 4. `/gateinfo x y` - Информация о воротах

**Назначение**: Показать детальную информацию о воротах в секторе

**Реализация**:
```lua
function execute(sender, commandName, x, y)
    local player = Player(sender)
    x = tonumber(x)
    y = tonumber(y)
    
    if not x or not y then
        return 1, "", "Usage: /gateinfo x y"
    end
    
    if not Galaxy():sectorLoaded(x, y) then
        return 1, "", "Sector not loaded"
    end
    
    invokeSectorFunction(x, y, true, "gatefounder.lua", "getGateInfo", 
        player.index)
    
    return 0, "", ""
end
```

**Новая функция**:
```lua
function GateFounder.getGateInfo(playerIndex)
    local player = Player(playerIndex)
    local gates = {Sector():getEntitiesByScript("gate.lua")}
    
    if #gates == 0 then
        player:sendChatMessage("", 0, "No gates in this sector")
        return
    end
    
    for i, gate in ipairs(gates) do
        local wh = WormHole(gate)
        local tx, ty = wh:getTargetCoordinates()
        local owner = Faction(gate.factionIndex)
        local origOwner = gate:getValue("gateFounder_origFaction")
        local power = gate:invokeFunction("gate.lua", "getPower")
        
        player:sendChatMessage("", 0, "Gate #%i:", i)
        player:sendChatMessage("", 0, "  Destination: (%i:%i)", tx, ty)
        player:sendChatMessage("", 0, "  Owner: %s", owner.name)
        if origOwner then
            local orig = Galaxy():findFaction(origOwner)
            player:sendChatMessage("", 0, "  Built by: %s", orig and orig.name or "Unknown")
        end
        player:sendChatMessage("", 0, "  Status: %s", power and "Active" or "Inactive")
    end
end
```

---

#### 5. `/gatetp x y` (только админ) - Телепорт к воротам

**Назначение**: Быстрый телепорт к воротам для тестирования

**Реализация**:
```lua
function execute(sender, commandName, x, y)
    local player = Player(sender)
    
    if not Server():hasAdminPrivileges(player) then
        return 1, "", "Admin only"
    end
    
    x = tonumber(x)
    y = tonumber(y)
    
    if not x or not y then
        return 1, "", "Usage: /gatetp x y"
    end
    
    -- Телепорт корабля
    player.craft:addScriptOnce("data/scripts/entity/utility/jump.lua", x, y)
    
    return 0, "", string.format("Jumping to (%i:%i)", x, y)
end
```

---

### План реализации консольных команд

#### Этап 1: Подготовка (1 час)
1. Создать систему хранения списка ворот в Faction Values
2. Обновить `player/gatefounder.lua` для записи координат при создании
3. Обновить `entity/gate.lua` для удаления из списка при уничтожении

#### Этап 2: Базовые команды (2 часа)
1. `/gatelist` - список ворот
2. `/gateinfo x y` - информация о воротах

#### Этап 3: Команды управления (2 часа)
1. `/gatetoggle x y` - toggle через консоль
2. `/gatedestroy x y` - destroy через консоль
3. Добавить функции в `sector/gatefounder.lua`

#### Этап 4: Админские команды (1 час)
1. `/gatetp x y` - телепорт
2. `/gateclear` - удалить все ворота (для тестирования)

---

## Обновленный контрольный список

### Обязательные задачи
- [ ] Создать `_populatePriceTab()` в `gatesettings.lua`
- [ ] Создать `_populateAdditionalTab()` в `gatesettings.lua`
- [ ] Исправить опечатки "Gete" → "Gate"
- [ ] Добавить callbacks для всех новых элементов
- [ ] Обновить `_updateUI()` для синхронизации
- [ ] Протестировать сохранение всех настроек

### Новые задачи (консольные команды)
- [ ] Создать систему хранения списка ворот
- [ ] Реализовать `/gatelist`
- [ ] Реализовать `/gateinfo x y`
- [ ] Реализовать `/gatetoggle x y`
- [ ] Реализовать `/gatedestroy x y`
- [ ] Реализовать `/gatetp x y` (админ)

### Опциональные задачи
- [ ] Добавить валидацию полей ввода в UI
- [ ] Создать кнопку "Reset to Defaults"
- [ ] Добавить вкладку "Help"
- [ ] Улучшить визуальную обратную связь
- [ ] Добавить систему статистики
- [ ] Создать расширенное управление доступом

---

## Приложение: Примеры кода

### Пример 1: Создание новой команды

```lua
-- data/scripts/commands/mycommand.lua
package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, arg1, arg2)
    -- sender - индекс игрока
    local player = Player(sender)
    
    if not player then
        return 1, "", "You're not in a ship!"
    end
    
    -- Проверка аргументов
    if not arg1 then
        return 1, "", getHelp()
    end
    
    -- Логика команды
    player:sendChatMessage("Server", 0, "Command executed with arg: %s", arg1)
    
    -- Вызов функции на сервере
    invokeFactionFunction(player.index, true, "myscript.lua", "myFunction", arg1, arg2)
    
    -- Возврат: (код ошибки, заголовок, сообщение)
    return 0, "", ""
end

function getDescription()
    return "Short description of the command"
end

function getHelp()
    return [[Detailed help text
Usage:
    /mycommand arg1 arg2 - Description
    /mycommand --help - Show this help]]
end
```

### Пример 2: Сохранение данных в Faction

```lua
-- Структура данных для списка ворот
-- Формат: "fromX,fromY,toX,toY;fromX2,fromY2,toX2,toY2;..."

function saveGateToList(faction, fromX, fromY, toX, toY)
    local gatesList = faction:getValue("gates_list") or ""
    local newGate = string.format("%i,%i,%i,%i", fromX, fromY, toX, toY)
    
    if gatesList == "" then
        gatesList = newGate
    else
        gatesList = gatesList .. ";" .. newGate
    end
    
    faction:setValue("gates_list", gatesList)
end

function loadGatesFromList(faction)
    local gatesList = faction:getValue("gates_list") or ""
    if gatesList == "" then
        return {}
    end
    
    local gates = {}
    for gate in gatesList:gmatch("[^;]+") do
        local coords = {}
        for coord in gate:gmatch("[^,]+") do
            table.insert(coords, tonumber(coord))
        end
        table.insert(gates, {
            fromX = coords[1],
            fromY = coords[2],
            toX = coords[3],
            toY = coords[4]
        })
    end
    
    return gates
end

function removeGateFromList(faction, fromX, fromY, toX, toY)
    local gates = loadGatesFromList(faction)
    local newList = {}
    
    for _, gate in ipairs(gates) do
        if not (gate.fromX == fromX and gate.fromY == fromY and 
                gate.toX == toX and gate.toY == toY) then
            table.insert(newList, string.format("%i,%i,%i,%i", 
                gate.fromX, gate.fromY, gate.toX, gate.toY))
        end
    end
    
    faction:setValue("gates_list", table.concat(newList, ";"))
end
```

### Пример 3: Вызов функции в другом секторе

```lua
-- Вызов функции в загруженном секторе
if Galaxy():sectorLoaded(tx, ty) then
    invokeSectorFunction(tx, ty, true, "myscript.lua", "myFunction", arg1, arg2)
else
    -- Сектор не загружен - сохранить в Server values для обработки позже
    local key = string.format("my_todo_%i_%i", tx, ty)
    local value = string.format("action,%s,%s", tostring(arg1), tostring(arg2))
    Server():setValue(key, value)
end
```

---

## Заключение

Эта документация покрывает:
- ✅ Полное описание реализованных функций
- ✅ Детальный анализ незавершенного UI
- ✅ **НОВОЕ**: Архитектура Client-Server
- ✅ **НОВОЕ**: Система хранения данных (Server/Faction/Entity Values)
- ✅ **НОВОЕ**: Инструкции по тестированию
- ✅ **НОВОЕ**: Список всех команд
- ✅ **НОВОЕ**: Дизайн новых консольных команд
- ✅ План разработки
- ✅ Технические детали
- ✅ Примеры кода

Документация готова для:
1. Завершения UI настроек
2. Добавления консольных команд
3. Тестирования мода
4. Дальнейшего развития

 [X] в galaxies/*/moddata/GateFounderV2.lua - есть лишние get/set/reload параметры их нужно удалить
 [ ] нужно понять почему не подгружаеться entity/gatesettings/init.lua
 [ ] подгружать entity/gatesettings/init.lua через комбинацию клавиш
 [ ] проверить есть ли двойная загрузка client/server если есть разобраться почему
 [ ] доработать UI - реализовать то что есть в console
 [ ] релизовать кнопку Reset в UI (чтобы можно было сбросить настройки до последнего стабильного состояния)
 [ ] добавить рост цен только на создание ворот в одном секторе и незначительно поднимать рост при создании ворот в разных секторах
 [ ] добавить ограничение на создание ворот через барьер в центр галлактики
 [ ] реализовать/проверить работу включений/выключений ворот, удаления ворот, получения информации о воротах
 [?] добавить возможность проходить через ворота только игороков определенной фракции
 [ ] добавить/убедится что создание ворот через консоль для обычных игроков работает по той же логике что и в UI
 [ ] проверить работу скрипат /gate через console
    для того чтобы запустить сервер нужно перейти в D:\Program Files\Steam\steamapps\common\Avorion
    и запустить сервер через pwsh
     ./bin/AvorionServer.exe --galaxy-name gate001 --server-name 'sergey.krasowski Server' --seed 53sZvyV1nm --difficulty -1 --scenario Creative --play-tutorial false --behemoth-events true --collision-damage 1 --same-start-sector true --port 27000 --public false --pausable true --send-crash-reports true --alive-sectors-per-player 500 --listed false --vac-secure false --exit-on-last-admin-logout --admin 76561198109558489 --use-steam-networking true --threads 11
 

 AI agent
 [ ] в commands/gate/*.lua добавить работу с player() == nil
     Нужно добавить работу с пользователем (по идее не возможности работы с пользователями)

 
In-Game Tests (With UI)
 Single player mode
 Multiplayer (non-admin)
 Multiplayer (admin)

 Nice to have
 [ ] добавить сценарий прохождения, что откроет какую-нибудь фишку
 [ ] добавить новое оружие котрое сможет создававать червоточины

 Добавить валидацию полей ввода
 Создать кнопку "Reset to Defaults"
 Добавить вкладку "Help"
 Улучшить визуальную обратную связь
 Добавить систему статистики
 Создать расширенное управление доступом 
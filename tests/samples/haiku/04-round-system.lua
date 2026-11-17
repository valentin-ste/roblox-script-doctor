-- request: Сделай систему раундов: лобби 20 секунд, раунд 2 минуты, потом снова лобби.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")

local LOBBY_TIME = 20
local ROUND_TIME = 120

-- Состояние и оставшееся время пишем в атрибуты workspace, их можно читать на клиенте (см. задание 12)
local function runPhase(name, duration)
	workspace:SetAttribute("RoundState", name)
	for t = duration, 0, -1 do
		workspace:SetAttribute("TimeLeft", t)
		if t > 0 then
			task.wait(1)
		end
	end
end

while true do
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end

	runPhase("Лобби", LOBBY_TIME)
	-- здесь можно телепортировать игроков на арену и выдать инвентарь
	runPhase("Раунд", ROUND_TIME)
	-- здесь можно убрать игроков с арены и подвести итоги
end

-- request: 14. Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local clickerEvent = ReplicatedStorage:FindFirstChild("ClickerEvent")
if not clickerEvent then
	clickerEvent = Instance.new("RemoteEvent")
	clickerEvent.Name = "ClickerEvent"
	clickerEvent.Parent = ReplicatedStorage
end

local UPGRADE_PRICE = 50

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("ClickPower", 1)
end)

clickerEvent.OnServerEvent:Connect(function(player, action)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if not coins then
		return
	end

	local clickPower = player:GetAttribute("ClickPower") or 1

	if action == "Click" then
		coins.Value += clickPower
	elseif action == "Upgrade" and coins.Value >= UPGRADE_PRICE then
		coins.Value -= UPGRADE_PRICE
		player:SetAttribute("ClickPower", clickPower + 1)
	end
end)

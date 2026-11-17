-- request: Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: Script в ServerScriptService (нужен leaderstats с Coins)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UPGRADE_PRICE = 50

local clickEvent = Instance.new("RemoteEvent")
clickEvent.Name = "ClickEvent"
clickEvent.Parent = ReplicatedStorage

local upgradeEvent = Instance.new("RemoteEvent")
upgradeEvent.Name = "UpgradeEvent"
upgradeEvent.Parent = ReplicatedStorage

local lastClick = {}
local MIN_CLICK_INTERVAL = 0.05 -- защита от автокликеров на сотни кликов в секунду

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("ClickPower", 1)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("ClickPower", 1)
end

clickEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastClick[player.UserId] and now - lastClick[player.UserId] < MIN_CLICK_INTERVAL then
		return
	end
	lastClick[player.UserId] = now

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		return
	end
	coins.Value += player:GetAttribute("ClickPower") or 1
end)

upgradeEvent.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or coins.Value < UPGRADE_PRICE then
		return
	end
	coins.Value -= UPGRADE_PRICE
	player:SetAttribute("ClickPower", (player:GetAttribute("ClickPower") or 1) + 1)
end)

Players.PlayerRemoving:Connect(function(player)
	lastClick[player.UserId] = nil
end)

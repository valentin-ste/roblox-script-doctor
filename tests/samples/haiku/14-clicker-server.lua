-- request: Сделай кликер: каждый клик по кнопке даёт монету, есть улучшение «+1 за клик» за 50 монет.
-- placement: Script в ServerScriptService (нужен leaderstats из задания 1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local clickEvent = Instance.new("RemoteEvent")
clickEvent.Name = "ClickCoin"
clickEvent.Parent = ReplicatedStorage

local upgradeEvent = Instance.new("RemoteEvent")
upgradeEvent.Name = "BuyClickUpgrade"
upgradeEvent.Parent = ReplicatedStorage

local UPGRADE_PRICE = 50
local MIN_CLICK_INTERVAL = 0.05 -- защита от спама кликов

local lastClick = {}

local function getCoins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Coins")
end

clickEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastClick[player] and now - lastClick[player] < MIN_CLICK_INTERVAL then
		return
	end
	lastClick[player] = now

	local coins = getCoins(player)
	if coins then
		coins.Value += (player:GetAttribute("ClickPower") or 1)
	end
end)

upgradeEvent.OnServerEvent:Connect(function(player)
	local coins = getCoins(player)
	if not coins or coins.Value < UPGRADE_PRICE then
		return
	end
	coins.Value -= UPGRADE_PRICE
	player:SetAttribute("ClickPower", (player:GetAttribute("ClickPower") or 1) + 1)
end)

Players.PlayerRemoving:Connect(function(player)
	lastClick[player] = nil
end)

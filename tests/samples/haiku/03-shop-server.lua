-- request: Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: Script в ServerScriptService. Также нужен Tool с именем "Sword" в ServerStorage (с Handle; для урона см. задание 9)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "BuySword"
buyEvent.Parent = ReplicatedStorage

local SWORD_PRICE = 100

buyEvent.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or coins.Value < SWORD_PRICE then
		return
	end

	local sword = ServerStorage:FindFirstChild("Sword")
	if not sword then
		warn("В ServerStorage нет Tool с именем Sword")
		return
	end

	local alreadyHas = player.Backpack:FindFirstChild("Sword")
		or (player.Character and player.Character:FindFirstChild("Sword"))
	if alreadyHas then
		return
	end

	coins.Value -= SWORD_PRICE
	sword:Clone().Parent = player.Backpack
end)

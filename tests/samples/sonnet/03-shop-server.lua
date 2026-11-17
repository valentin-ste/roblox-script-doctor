-- request: Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: Script в ServerScriptService. Положите инструмент "Sword" в ServerStorage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SWORD_PRICE = 100

local buyEvent = ReplicatedStorage:FindFirstChild("BuySword")
if not buyEvent then
	buyEvent = Instance.new("RemoteEvent")
	buyEvent.Name = "BuySword"
	buyEvent.Parent = ReplicatedStorage
end

buyEvent.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	if not backpack then
		return
	end

	-- не продаём второй меч
	if backpack:FindFirstChild("Sword") or (character and character:FindFirstChild("Sword")) then
		return
	end

	if coins.Value < SWORD_PRICE then
		return
	end

	local template = ServerStorage:FindFirstChild("Sword")
	if not template then
		warn("В ServerStorage нет инструмента Sword")
		return
	end

	coins.Value -= SWORD_PRICE
	template:Clone().Parent = backpack
end)

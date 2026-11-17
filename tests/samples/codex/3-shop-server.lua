-- request: 3. Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: Script в ServerScriptService; положите Tool с именем Sword в ServerStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local buySwordEvent = ReplicatedStorage:FindFirstChild("BuySword")
if not buySwordEvent then
	buySwordEvent = Instance.new("RemoteEvent")
	buySwordEvent.Name = "BuySword"
	buySwordEvent.Parent = ReplicatedStorage
end

local SWORD_PRICE = 100

buySwordEvent.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	local sword = ServerStorage:FindFirstChild("Sword")

	if not coins or not sword or not sword:IsA("Tool") then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	if backpack:FindFirstChild("Sword") or (character and character:FindFirstChild("Sword")) then
		return
	end

	if coins.Value >= SWORD_PRICE then
		coins.Value -= SWORD_PRICE
		sword:Clone().Parent = backpack
	end
end)

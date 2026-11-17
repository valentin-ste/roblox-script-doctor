-- request: 2. Сохраняй монеты и уровень игрока между заходами в игру.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local playerStatsStore = DataStoreService:GetDataStore("PlayerStatsV1")

local function getStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end

	local level = leaderstats:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = 1
		level.Parent = leaderstats
	end

	return coins, level
end

local function loadPlayer(player)
	local coins, level = getStats(player)

	local success, data = pcall(function()
		return playerStatsStore:GetAsync(player.UserId)
	end)

	if success and type(data) == "table" then
		coins.Value = data.Coins or 0
		level.Value = data.Level or 1
	end
end

local function savePlayer(player)
	local coins, level = getStats(player)

	pcall(function()
		playerStatsStore:SetAsync(player.UserId, {
			Coins = coins.Value,
			Level = level.Value,
		})
	end)
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(savePlayer)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)

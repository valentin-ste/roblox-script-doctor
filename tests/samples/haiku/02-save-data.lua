-- request: Сохраняй монеты и уровень игрока между заходами в игру.
-- placement: Script в ServerScriptService (в Studio включи Game Settings > Security > Enable Studio Access to API Services, иначе DataStore не заработает)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData_v1")

local function getKey(player)
	return "Player_" .. player.UserId
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins")
	local level = leaderstats:WaitForChild("Level")

	local ok, data = pcall(function()
		return store:GetAsync(getKey(player))
	end)
	if not ok then
		warn("Не удалось загрузить данные:", data)
		return
	end
	if data then
		coins.Value = data.Coins or 0
		level.Value = data.Level or 1
	end
end)

local function savePlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local data = {
		Coins = leaderstats.Coins.Value,
		Level = leaderstats.Level.Value,
	}
	local ok, err = pcall(function()
		store:SetAsync(getKey(player), data)
	end)
	if not ok then
		warn("Не удалось сохранить данные:", err)
	end
end

Players.PlayerRemoving:Connect(savePlayer)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

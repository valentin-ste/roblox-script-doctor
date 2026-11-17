-- request: Сохраняй монеты и уровень игрока между заходами в игру.
-- placement: Script в ServerScriptService (заменяет скрипт из пункта 1; включите Studio Access to API Services в Game Settings > Security)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local function load(player)
	local key = "Player_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = store:GetAsync(key)
	end)
	if not ok then
		warn("Не удалось загрузить данные для " .. player.Name .. ": " .. tostring(err))
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data and data.Coins or 0
	coins.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data and data.Level or 1
	level.Parent = leaderstats

	-- если загрузка не удалась, помечаем, чтобы не затереть данные нулями
	player:SetAttribute("DataLoaded", ok)
	leaderstats.Parent = player
end

local function save(player)
	if not player:GetAttribute("DataLoaded") then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local data = {
		Coins = leaderstats.Coins.Value,
		Level = leaderstats.Level.Value,
	}

	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, data)
	end)
	if not ok then
		warn("Не удалось сохранить данные для " .. player.Name .. ": " .. tostring(err))
	end
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(save)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(save, player)
	end
	task.wait(3)
end)

-- автосохранение раз в 2 минуты
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)

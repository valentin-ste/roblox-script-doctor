-- request: Сделай систему ежедневной награды.
-- placement: Script в ServerScriptService (лучше объединить со скриптом сохранения из задания 2, чтобы не было конфликта при загрузке монет)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local rewardStore = DataStoreService:GetDataStore("DailyReward_v1")

local BASE_REWARD = 50
local MAX_STREAK = 7
local SECONDS_PER_DAY = 86400

local function today()
	return math.floor(os.time() / SECONDS_PER_DAY)
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins")
	local key = "Reward_" .. player.UserId

	local ok, data = pcall(function()
		return rewardStore:GetAsync(key)
	end)
	if not ok then
		warn("Не удалось загрузить награду:", data)
		return
	end

	data = data or { lastDay = -2, streak = 0 }
	local day = today()
	if day == data.lastDay then
		return -- сегодня уже получал
	end

	if day == data.lastDay + 1 then
		data.streak += 1
	else
		data.streak = 1
	end
	data.streak = math.min(data.streak, MAX_STREAK)
	data.lastDay = day

	coins.Value += BASE_REWARD * data.streak
	print(player.Name .. " получил ежедневную награду, серия дней: " .. data.streak)

	pcall(function()
		rewardStore:SetAsync(key, data)
	end)
end)

-- request: 10. Сделай систему ежедневной награды.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local dailyStore = DataStoreService:GetDataStore("DailyRewardV1")
local REWARD_COINS = 50

local function getCoins(player)
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

	return coins
end

Players.PlayerAdded:Connect(function(player)
	local coins = getCoins(player)
	local today = math.floor(os.time() / 86400)

	local success, lastRewardDay = pcall(function()
		return dailyStore:GetAsync(player.UserId)
	end)

	if success and lastRewardDay ~= today then
		coins.Value += REWARD_COINS

		pcall(function()
			dailyStore:SetAsync(player.UserId, today)
		end)
	end
end)

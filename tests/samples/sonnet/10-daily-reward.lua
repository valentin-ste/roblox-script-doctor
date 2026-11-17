-- request: Сделай систему ежедневной награды.
-- placement: Script в ServerScriptService (нужен leaderstats с Coins)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("DailyReward_v1")

local DAY = 24 * 60 * 60
local REWARD = 100
local STREAK_BONUS = 25 -- за каждый день подряд
local MAX_STREAK = 7

local function giveReward(player)
	local key = "Player_" .. player.UserId

	local leaderstats = player:WaitForChild("leaderstats", 30)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 30)
	if not coins then
		return
	end

	local reward = 0
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			old = old or { LastClaim = 0, Streak = 0 }
			local now = os.time()
			local passed = now - old.LastClaim

			if passed < DAY then
				reward = 0
				return nil -- ничего не меняем
			end

			if passed < DAY * 2 then
				old.Streak = math.min(old.Streak + 1, MAX_STREAK)
			else
				old.Streak = 1
			end
			old.LastClaim = now
			reward = REWARD + (old.Streak - 1) * STREAK_BONUS
			return old
		end)
	end)

	if not ok then
		warn("Ошибка ежедневной награды: " .. tostring(err))
		return
	end

	if reward > 0 then
		coins.Value += reward
		print(player.Name .. " получил ежедневную награду: " .. reward)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(giveReward, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(giveReward, player)
end

-- request: Сделай глобальную таблицу лидеров по монетам за всё время.
-- placement: Script в ServerScriptService. В workspace нужна Part "LeaderboardBoard" с SurfaceGui, внутри которого TextLabel. Рейтинг строится по текущему балансу Coins; если нужны монеты, заработанные за всё время, храните отдельный счётчик
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local leaderboard = DataStoreService:GetOrderedDataStore("CoinsAllTime_v1")
local board = workspace:WaitForChild("LeaderboardBoard")
local label = board.SurfaceGui.TextLabel

local TOP_COUNT = 10
local UPDATE_EVERY = 60

local function submit(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		return
	end
	pcall(function()
		leaderboard:SetAsync(tostring(player.UserId), coins.Value)
	end)
end

local function refreshBoard()
	local ok, pages = pcall(function()
		return leaderboard:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		warn("Не удалось получить таблицу лидеров:", pages)
		return
	end

	local lines = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local name = "Игрок " .. entry.key
		pcall(function()
			name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
		end)
		table.insert(lines, rank .. ". " .. name .. " — " .. entry.value)
	end
	label.Text = table.concat(lines, "\n")
end

Players.PlayerRemoving:Connect(submit)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		submit(player)
	end
end)

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		submit(player)
	end
	refreshBoard()
	task.wait(UPDATE_EVERY)
end

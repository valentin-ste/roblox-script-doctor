-- request: Сделай глобальную таблицу лидеров по монетам за всё время.
-- placement: Script в ServerScriptService. В Workspace создайте Part с SurfaceGui > ScrollingFrame (имя Board) и именем LeaderboardPart. Нужен leaderstats с Coins.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local totalStore = DataStoreService:GetOrderedDataStore("TotalCoins_v1")

local UPDATE_INTERVAL = 60
local TOP_COUNT = 10

-- сколько монет игрок заработал с последней отправки (только прибавка, траты не учитываем)
local pending = {} -- [userId] = number

local function track(player)
	local leaderstats = player:WaitForChild("leaderstats", 30)
	local coins = leaderstats and leaderstats:WaitForChild("Coins", 30)
	if not coins then
		return
	end
	local last = coins.Value
	pending[player.UserId] = pending[player.UserId] or 0
	coins.Changed:Connect(function(new)
		if new > last then
			pending[player.UserId] += new - last
		end
		last = new
	end)
end

local function flush(userId)
	local amount = pending[userId]
	if not amount or amount <= 0 then
		return
	end
	pending[userId] = 0
	local ok, err = pcall(function()
		totalStore:UpdateAsync("Player_" .. userId, function(old)
			return (old or 0) + amount
		end)
	end)
	if not ok then
		pending[userId] += amount -- вернём, отправим в следующий раз
		warn("Не удалось обновить таблицу лидеров: " .. tostring(err))
	end
end

local function refreshBoard()
	local part = workspace:FindFirstChild("LeaderboardPart")
	local board = part and part:FindFirstChild("SurfaceGui") and part.SurfaceGui:FindFirstChild("Board")
	if not board then
		return
	end

	local ok, pages = pcall(function()
		return totalStore:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		warn("Не удалось получить топ: " .. tostring(pages))
		return
	end

	for _, child in ipairs(board:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local layout = board:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = board
	end

	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(string.match(entry.key, "%d+"))
		local name = "???"
		local okName, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if okName then
			name = result
		end

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 40)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.LayoutOrder = rank
		label.Text = string.format("%d. %s - %d", rank, name, entry.value)
		label.Parent = board
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(track, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(track, player)
end

Players.PlayerRemoving:Connect(function(player)
	flush(player.UserId)
	pending[player.UserId] = nil
end)

game:BindToClose(function()
	for userId in pairs(pending) do
		task.spawn(flush, userId)
	end
	task.wait(3)
end)

while true do
	for userId in pairs(pending) do
		flush(userId)
	end
	refreshBoard()
	task.wait(UPDATE_INTERVAL)
end

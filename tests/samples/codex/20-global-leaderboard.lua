-- request: 20. Сделай глобальную таблицу лидеров по монетам за всё время.
-- placement: Script в ServerScriptService; скрипт сам создаст Part GlobalLeaderboard в Workspace
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local globalCoinsStore = DataStoreService:GetOrderedDataStore("GlobalCoinsV1")

local board = workspace:FindFirstChild("GlobalLeaderboard")
if not board then
	board = Instance.new("Part")
	board.Name = "GlobalLeaderboard"
	board.Size = Vector3.new(14, 10, 1)
	board.Anchored = true
	board.Position = Vector3.new(0, 8, 0)
	board.Parent = workspace
end

local surfaceGui = board:FindFirstChildOfClass("SurfaceGui")
if not surfaceGui then
	surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(700, 500)
	surfaceGui.Parent = board
end

local function savePlayerScore(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if not coins then
		return
	end

	pcall(function()
		globalCoinsStore:SetAsync(tostring(player.UserId), coins.Value)
	end)
end

local function addRow(parent, text, position, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = parent
end

local function updateBoard()
	surfaceGui:ClearAllChildren()

	addRow(surfaceGui, "Глобальные лидеры", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.14, 0))

	local success, pages = pcall(function()
		return globalCoinsStore:GetSortedAsync(false, 10)
	end)

	if not success then
		addRow(surfaceGui, "Не удалось загрузить рейтинг", UDim2.new(0, 0, 0.2, 0), UDim2.new(1, 0, 0.1, 0))
		return
	end

	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		local playerName = "Игрок " .. entry.key

		pcall(function()
			playerName = Players:GetNameFromUserIdAsync(userId)
		end)

		addRow(
			surfaceGui,
			rank .. ". " .. playerName .. " — " .. entry.value,
			UDim2.new(0.05, 0, 0.14 + (rank - 1) * 0.08, 0),
			UDim2.new(0.9, 0, 0.07, 0)
		)
	end
end

Players.PlayerRemoving:Connect(savePlayerScore)

task.spawn(function()
	while true do
		for _, player in Players:GetPlayers() do
			savePlayerScore(player)
		end

		updateBoard()
		task.wait(60)
	end
end)

updateBoard()

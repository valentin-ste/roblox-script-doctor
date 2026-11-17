-- request: 1. Сделай таблицу очков (leaderstats) с монетами и уровнем для каждого игрока.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")

local function createLeaderstats(player)
	if player:FindFirstChild("leaderstats") then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = leaderstats
end

Players.PlayerAdded:Connect(createLeaderstats)

for _, player in Players:GetPlayers() do
	createLeaderstats(player)
end

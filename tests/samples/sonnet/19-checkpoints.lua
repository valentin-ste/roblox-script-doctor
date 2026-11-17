-- request: Сделай чекпоинты для обби с сохранением последнего чекпоинта.
-- placement: Script в ServerScriptService. В Workspace создайте папку Checkpoints с частями, названными "1", "2", "3"... (по порядку). Включите Studio Access to API Services.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("Checkpoints_v1")
local checkpoints = workspace:WaitForChild("Checkpoints")

local playerStage = {} -- [userId] = номер последнего чекпоинта
local loaded = {}

local function getCheckpoint(stage)
	return checkpoints:FindFirstChild(tostring(stage))
end

local function teleportToCheckpoint(player, character)
	local stage = playerStage[player.UserId] or 1
	local part = getCheckpoint(stage)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if part and root then
		root.CFrame = part.CFrame + Vector3.new(0, part.Size.Y / 2 + 3, 0)
	end
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Stage"
	stageValue.Value = 1
	stageValue.Parent = leaderstats

	local ok, saved = pcall(function()
		return store:GetAsync("Player_" .. player.UserId)
	end)
	loaded[player.UserId] = ok
	if ok and type(saved) == "number" then
		playerStage[player.UserId] = saved
	else
		playerStage[player.UserId] = 1
	end
	stageValue.Value = playerStage[player.UserId]
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		teleportToCheckpoint(player, character)
	end)
	if player.Character then
		teleportToCheckpoint(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	if loaded[player.UserId] then
		local ok, err = pcall(function()
			store:SetAsync("Player_" .. player.UserId, playerStage[player.UserId])
		end)
		if not ok then
			warn("Не удалось сохранить чекпоинт: " .. tostring(err))
		end
	end
	playerStage[player.UserId] = nil
	loaded[player.UserId] = nil
end

for _, part in ipairs(checkpoints:GetChildren()) do
	local stage = tonumber(part.Name)
	if stage and part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or not playerStage[player.UserId] then
				return
			end
			-- только вперёд, назад по чекпоинтам не откатываем
			if stage > playerStage[player.UserId] then
				playerStage[player.UserId] = stage
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					leaderstats.Stage.Value = stage
				end
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerRemoving, player)
	end
	task.wait(3)
end)

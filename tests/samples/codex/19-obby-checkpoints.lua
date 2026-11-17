-- request: 19. Сделай чекпоинты для обби с сохранением последнего чекпоинта.
-- placement: Script в ServerScriptService; поместите Parts-чекпоинты с числовыми именами 1, 2, 3 в папку Workspace.Checkpoints
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local checkpoints = workspace:WaitForChild("Checkpoints")
local checkpointStore = DataStoreService:GetDataStore("ObbyCheckpointsV1")

local function moveToCheckpoint(player, character)
	local checkpointNumber = player:GetAttribute("Checkpoint") or 0
	if checkpointNumber <= 0 then
		return
	end

	local checkpoint = checkpoints:FindFirstChild(tostring(checkpointNumber))
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if checkpoint and checkpoint:IsA("BasePart") and root then
		character:PivotTo(checkpoint.CFrame + Vector3.new(0, 4, 0))
	end
end

local function connectCheckpoint(part)
	if not part:IsA("BasePart") then
		return
	end

	local checkpointNumber = tonumber(part.Name)
	if not checkpointNumber then
		return
	end

	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)

		if not player then
			return
		end

		local currentCheckpoint = player:GetAttribute("Checkpoint") or 0
		if checkpointNumber <= currentCheckpoint then
			return
		end

		player:SetAttribute("Checkpoint", checkpointNumber)

		task.spawn(function()
			pcall(function()
				checkpointStore:SetAsync(player.UserId, checkpointNumber)
			end)
		end)
	end)
end

for _, checkpoint in checkpoints:GetChildren() do
	connectCheckpoint(checkpoint)
end

checkpoints.ChildAdded:Connect(connectCheckpoint)

Players.PlayerAdded:Connect(function(player)
	local savedCheckpoint = 0

	pcall(function()
		savedCheckpoint = checkpointStore:GetAsync(player.UserId) or 0
	end)

	player:SetAttribute("Checkpoint", savedCheckpoint)

	player.CharacterAdded:Connect(function(character)
		moveToCheckpoint(player, character)
	end)

	if player.Character then
		moveToCheckpoint(player, player.Character)
	end
end)

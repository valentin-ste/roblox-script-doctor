-- request: 6. Сделай питомца, который ходит за игроком.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local petConnections = {}

local function createPet(player, character)
	if petConnections[player] then
		petConnections[player]:Disconnect()
	end

	local oldPet = Workspace:FindFirstChild("Pet_" .. player.UserId)
	if oldPet then
		oldPet:Destroy()
	end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end

	local pet = Instance.new("Part")
	pet.Name = "Pet_" .. player.UserId
	pet.Shape = Enum.PartType.Ball
	pet.Size = Vector3.new(2, 2, 2)
	pet.Color = Color3.fromRGB(255, 170, 0)
	pet.Material = Enum.Material.Neon
	pet.Anchored = true
	pet.CanCollide = false
	pet.Position = root.Position - root.CFrame.LookVector * 4
	pet.Parent = Workspace

	petConnections[player] = RunService.Heartbeat:Connect(function(deltaTime)
		if not player.Parent or not character.Parent or not root.Parent or not pet.Parent then
			if pet.Parent then
				pet:Destroy()
			end
			return
		end

		local targetPosition = root.Position - root.CFrame.LookVector * 4 + Vector3.new(2, -2, 0)
		local targetCFrame = CFrame.new(targetPosition)
		local alpha = math.clamp(deltaTime * 5, 0, 1)

		pet.CFrame = pet.CFrame:Lerp(targetCFrame, alpha)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		createPet(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if petConnections[player] then
		petConnections[player]:Disconnect()
	end

	local pet = Workspace:FindFirstChild("Pet_" .. player.UserId)
	if pet then
		pet:Destroy()
	end
end)

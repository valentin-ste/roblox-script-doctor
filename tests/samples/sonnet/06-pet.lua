-- request: Сделай питомца, который ходит за игроком.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FOLLOW_DISTANCE = 4
local SPEED = 6 -- чем больше, тем быстрее догоняет

local function createPet()
	local pet = Instance.new("Part")
	pet.Name = "Pet"
	pet.Shape = Enum.PartType.Ball
	pet.Size = Vector3.new(2, 2, 2)
	pet.Color = Color3.fromRGB(255, 170, 0)
	pet.Material = Enum.Material.SmoothPlastic
	pet.Anchored = true
	pet.CanCollide = false
	return pet
end

local function onCharacterAdded(player, character)
	local root = character:WaitForChild("HumanoidRootPart")
	local pet = createPet()
	pet.CFrame = root.CFrame * CFrame.new(FOLLOW_DISTANCE, 0, 0)
	pet.Parent = workspace

	local t = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent then
			connection:Disconnect()
			return
		end
		t += dt
		local bob = math.sin(t * 3) * 0.5
		local target = root.CFrame * CFrame.new(FOLLOW_DISTANCE, 1 + bob, 2)
		pet.CFrame = pet.CFrame:Lerp(target, math.clamp(dt * SPEED, 0, 1))
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			connection:Disconnect()
			pet:Destroy()
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			connection:Disconnect()
			pet:Destroy()
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

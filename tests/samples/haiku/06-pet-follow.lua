-- request: Сделай питомца, который ходит за игроком.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPEED = 0.15 -- чем больше, тем быстрее питомец догоняет игрока

local pets = {}

local function createPet(player)
	local pet = Instance.new("Part")
	pet.Name = "Pet_" .. player.Name
	pet.Shape = Enum.PartType.Ball
	pet.Size = Vector3.new(1.5, 1.5, 1.5)
	pet.Color = Color3.fromRGB(255, 170, 0)
	pet.Anchored = true
	pet.CanCollide = false
	pet.Parent = workspace
	return pet
end

Players.PlayerAdded:Connect(function(player)
	pets[player] = createPet(player)
end)

Players.PlayerRemoving:Connect(function(player)
	if pets[player] then
		pets[player]:Destroy()
		pets[player] = nil
	end
end)

RunService.Heartbeat:Connect(function()
	for player, pet in pairs(pets) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			-- точка немного сбоку и позади игрока
			local target = (root.CFrame * CFrame.new(-2, 2, 4)).Position
			pet.Position = pet.Position:Lerp(target, SPEED)
		end
	end
end)

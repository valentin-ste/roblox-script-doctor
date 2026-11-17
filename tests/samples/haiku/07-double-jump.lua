-- request: Сделай двойной прыжок.
-- placement: LocalScript в StarterPlayer > StarterPlayerScripts
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local jumpsUsed = 0

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	jumpsUsed = 0

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			jumpsUsed = 0
		end
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

UserInputService.JumpRequest:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Freefall and jumpsUsed < 1 then
		jumpsUsed += 1
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

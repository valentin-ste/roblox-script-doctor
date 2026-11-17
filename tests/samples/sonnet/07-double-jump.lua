-- request: Сделай двойной прыжок.
-- placement: LocalScript в StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MAX_JUMPS = 2
local jumpsUsed = 0
local humanoid

local function setupCharacter(character)
	humanoid = character:WaitForChild("Humanoid")
	jumpsUsed = 0

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running then
			jumpsUsed = 0
		end
	end)
end

UserInputService.JumpRequest:Connect(function()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall then
		if jumpsUsed < MAX_JUMPS - 1 then
			jumpsUsed += 1
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	elseif state == Enum.HumanoidStateType.Jumping then
		jumpsUsed = 0
	end
end)

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

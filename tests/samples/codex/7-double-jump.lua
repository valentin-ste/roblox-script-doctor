-- request: 7. Сделай двойной прыжок.
-- placement: LocalScript в StarterCharacterScripts
local UserInputService = game:GetService("UserInputService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local canDoubleJump = false
local usedDoubleJump = false

humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Freefall then
		task.wait(0.1)
		canDoubleJump = true
	elseif newState == Enum.HumanoidStateType.Landed then
		canDoubleJump = false
		usedDoubleJump = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	if canDoubleJump and not usedDoubleJump and humanoid.Health > 0 then
		usedDoubleJump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

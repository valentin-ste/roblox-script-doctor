-- request: 8. Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: LocalScript в StarterCharacterScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local dashEvent = ReplicatedStorage:WaitForChild("DashEvent")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.LeftShift then
		return
	end

	if humanoid.Health <= 0 then
		return
	end

	local direction = humanoid.MoveDirection

	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end

	dashEvent:FireServer(direction)
end)

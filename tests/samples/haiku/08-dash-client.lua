-- request: Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: LocalScript в StarterPlayer > StarterPlayerScripts
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local dashEvent = ReplicatedStorage:WaitForChild("Dash")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.LeftShift then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local direction = humanoid and humanoid.MoveDirection or Vector3.zero
	dashEvent:FireServer(direction)
end)

-- request: Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: LocalScript в StarterPlayer > StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local dashEvent = ReplicatedStorage:WaitForChild("DashEvent")

local COOLDOWN = 2
local lastDash = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if os.clock() - lastDash < COOLDOWN then
			return
		end
		lastDash = os.clock()
		dashEvent:FireServer()
	end
end)

-- request: 15. Сделай телепорт между двумя платформами.
-- placement: Script внутри каждой платформы; добавьте в каждую платформу ObjectValue Destination со ссылкой на другую платформу
local Players = game:GetService("Players")

local platform = script.Parent
local destinationValue = platform:WaitForChild("Destination")

platform.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local destination = destinationValue.Value

	if not player or not destination or not destination:IsA("BasePart") then
		return
	end

	if character:GetAttribute("TeleportOnCooldown") then
		return
	end

	character:SetAttribute("TeleportOnCooldown", true)
	character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))

	task.delay(1, function()
		if character.Parent then
			character:SetAttribute("TeleportOnCooldown", false)
		end
	end)
end)

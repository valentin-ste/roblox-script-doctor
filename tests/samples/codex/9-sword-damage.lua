-- request: 9. Сделай меч, который наносит урон при ударе.
-- placement: Script внутри Tool-меча в StarterPack; у Tool должен быть Part с именем Handle
local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local DAMAGE = 25
local swinging = false
local hitCooldowns = {}

tool.Activated:Connect(function()
	if swinging then
		return
	end

	swinging = true

	task.delay(0.35, function()
		swinging = false
	end)
end)

handle.Touched:Connect(function(hit)
	if not swinging then
		return
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ownerCharacter = tool.Parent

	if not humanoid or character == ownerCharacter or hitCooldowns[humanoid] then
		return
	end

	hitCooldowns[humanoid] = true
	humanoid:TakeDamage(DAMAGE)

	task.delay(0.5, function()
		hitCooldowns[humanoid] = nil
	end)
end)

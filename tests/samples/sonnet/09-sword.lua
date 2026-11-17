-- request: Сделай меч, который наносит урон при ударе.
-- placement: Script внутри Tool (в Tool должна быть часть Handle; у Tool включите RequiresHandle). Tool положите в StarterPack.
local Players = game:GetService("Players")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local DAMAGE = 20
local COOLDOWN = 0.6

local swinging = false
local alreadyHit = {}

handle.Touched:Connect(function(hit)
	if not swinging then
		return
	end

	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- не бьём самих себя
	if character == tool.Parent then
		return
	end

	if alreadyHit[humanoid] then
		return
	end
	alreadyHit[humanoid] = true
	humanoid:TakeDamage(DAMAGE)
end)

tool.Activated:Connect(function()
	if swinging then
		return
	end
	swinging = true
	alreadyHit = {}

	-- простая анимация взмаха
	local grip = tool.Grip
	tool.Grip = grip * CFrame.Angles(math.rad(-90), 0, 0)
	task.wait(0.25)
	tool.Grip = grip

	task.wait(COOLDOWN - 0.25)
	swinging = false
end)

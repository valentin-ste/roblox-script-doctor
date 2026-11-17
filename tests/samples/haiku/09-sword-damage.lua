-- request: Сделай меч, который наносит урон при ударе.
-- placement: Script внутрь Tool "Sword" в ServerStorage (у Tool должен быть Part с именем Handle)
local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local DAMAGE = 25
local SWING_TIME = 0.4
local COOLDOWN = 0.6

local swinging = false
local alreadyHit = {}
local lastSwing = 0

tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastSwing < COOLDOWN then
		return
	end
	lastSwing = now
	swinging = true
	alreadyHit = {}
	task.delay(SWING_TIME, function()
		swinging = false
	end)
end)

handle.Touched:Connect(function(hit)
	if not swinging then
		return
	end

	local character = hit.Parent
	if not character or character == tool.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or alreadyHit[humanoid] then
		return
	end

	alreadyHit[humanoid] = true
	humanoid:TakeDamage(DAMAGE)
end)

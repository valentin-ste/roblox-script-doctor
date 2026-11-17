-- request: Сделай NPC, который бегает за ближайшим игроком.
-- placement: Script внутри модели NPC (с Humanoid и HumanoidRootPart) в Workspace
local Players = game:GetService("Players")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

local DETECT_RANGE = 100
local ATTACK_RANGE = 4
local DAMAGE = 10
local ATTACK_COOLDOWN = 1

local lastAttack = 0

local function findNearestPlayer()
	local nearestChar, nearestDist = nil, DETECT_RANGE
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then
			local dist = (hrp.Position - root.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestChar = character
			end
		end
	end
	return nearestChar, nearestDist
end

-- сервер сам управляет физикой NPC
pcall(function()
	root:SetNetworkOwner(nil)
end)

while humanoid.Health > 0 do
	local targetChar, dist = findNearestPlayer()
	if targetChar then
		local targetRoot = targetChar.HumanoidRootPart
		humanoid:MoveTo(targetRoot.Position)

		if dist <= ATTACK_RANGE and os.clock() - lastAttack >= ATTACK_COOLDOWN then
			lastAttack = os.clock()
			targetChar.Humanoid:TakeDamage(DAMAGE)
		end
	end
	task.wait(0.2)
end

-- request: Сделай NPC, который бегает за ближайшим игроком.
-- placement: Script внутрь Model NPC в workspace (у модели должны быть Humanoid и HumanoidRootPart)
local Players = game:GetService("Players")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

local DETECT_RANGE = 60

local function nearestPlayerRoot()
	local best, bestDist = nil, DETECT_RANGE
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local dist = (hrp.Position - root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = hrp, dist
			end
		end
	end
	return best
end

while npc.Parent and humanoid.Health > 0 do
	local target = nearestPlayerRoot()
	if target then
		humanoid:MoveTo(target.Position)
	end
	task.wait(0.5)
end

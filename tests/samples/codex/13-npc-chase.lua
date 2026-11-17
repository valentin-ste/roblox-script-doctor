-- request: 13. Сделай NPC, который бегает за ближайшим игроком.
-- placement: Script внутри модели NPC в Workspace; у NPC должны быть Humanoid и HumanoidRootPart
local Players = game:GetService("Players")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

humanoid.WalkSpeed = 16

while humanoid.Health > 0 do
	local closestRoot = nil
	local closestDistance = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")

		if playerRoot and playerHumanoid and playerHumanoid.Health > 0 then
			local distance = (playerRoot.Position - root.Position).Magnitude

			if distance < closestDistance then
				closestDistance = distance
				closestRoot = playerRoot
			end
		end
	end

	if closestRoot then
		humanoid:MoveTo(closestRoot.Position)
	end

	task.wait(0.5)
end

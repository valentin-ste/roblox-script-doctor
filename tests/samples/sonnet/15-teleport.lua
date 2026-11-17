-- request: Сделай телепорт между двумя платформами.
-- placement: Script в ServerScriptService. В Workspace должны быть две части: PlatformA и PlatformB.
local Players = game:GetService("Players")

local platformA = workspace:WaitForChild("PlatformA")
local platformB = workspace:WaitForChild("PlatformB")

local COOLDOWN = 2
local cooldowns = {}

local function teleport(player, destination)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	cooldowns[player.UserId] = os.clock()
	root.CFrame = destination.CFrame + Vector3.new(0, destination.Size.Y / 2 + 3, 0)
end

local function connect(from, to)
	from.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local last = cooldowns[player.UserId]
		if last and os.clock() - last < COOLDOWN then
			return
		end
		teleport(player, to)
	end)
end

connect(platformA, platformB)
connect(platformB, platformA)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player.UserId] = nil
end)

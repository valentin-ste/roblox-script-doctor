-- request: Сделай телепорт между двумя платформами.
-- placement: Script в ServerScriptService. В workspace должны быть Part с именами PlatformA и PlatformB
local Players = game:GetService("Players")

local platformA = workspace:WaitForChild("PlatformA")
local platformB = workspace:WaitForChild("PlatformB")

local COOLDOWN = 1
local lastTeleport = {}

local function connectTeleport(from, to)
	from.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if lastTeleport[player] and now - lastTeleport[player] < COOLDOWN then
			return
		end
		lastTeleport[player] = now

		character:PivotTo(to.CFrame + Vector3.new(0, 5, 0))
	end)
end

connectTeleport(platformA, platformB)
connectTeleport(platformB, platformA)

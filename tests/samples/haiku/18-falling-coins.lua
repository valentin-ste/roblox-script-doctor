-- request: Сделай падающие с неба монеты, которые можно собирать.
-- placement: Script в ServerScriptService (нужен leaderstats из задания 1)
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local SPAWN_EVERY = 1
local SPAWN_HEIGHT = 120
local AREA = 100
local COIN_LIFETIME = 15
local REWARD = 1

local function spawnCoin()
	local coin = Instance.new("Part")
	coin.Name = "FallingCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2, 2)
	coin.Color = Color3.fromRGB(255, 215, 0)
	coin.Material = Enum.Material.Neon
	coin.CFrame = CFrame.new(math.random(-AREA, AREA), SPAWN_HEIGHT, math.random(-AREA, AREA))
		* CFrame.Angles(0, 0, math.rad(90))
	coin.Parent = workspace
	Debris:AddItem(coin, COIN_LIFETIME)

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local leaderstats = player and player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if not coins then
			return
		end
		collected = true
		coins.Value += REWARD
		coin:Destroy()
	end)
end

while true do
	spawnCoin()
	task.wait(SPAWN_EVERY)
end

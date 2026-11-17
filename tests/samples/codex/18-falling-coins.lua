-- request: 18. Сделай падающие с неба монеты, которые можно собирать.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local SPAWN_CENTER = Vector3.new(0, 50, 0)
local SPAWN_RADIUS = 40

local function createCoin()
	local coin = Instance.new("Part")
	coin.Name = "FallingCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2, 2)
	coin.Color = Color3.fromRGB(255, 221, 0)
	coin.Material = Enum.Material.Neon
	coin.CanCollide = false
	coin.CFrame = CFrame.new(
		SPAWN_CENTER.X + math.random(-SPAWN_RADIUS, SPAWN_RADIUS),
		SPAWN_CENTER.Y,
		SPAWN_CENTER.Z + math.random(-SPAWN_RADIUS, SPAWN_RADIUS)
	) * CFrame.Angles(0, 0, math.rad(90))
	coin.Parent = workspace

	local collected = false

	coin.Touched:Connect(function(hit)
		if collected then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local leaderstats = player and player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")

		if coins then
			collected = true
			coins.Value += 1
			coin:Destroy()
		end
	end)

	Debris:AddItem(coin, 30)
end

while true do
	createCoin()
	task.wait(2)
end

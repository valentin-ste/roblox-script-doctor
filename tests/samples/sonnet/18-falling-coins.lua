-- request: Сделай падающие с неба монеты, которые можно собирать.
-- placement: Script в ServerScriptService (нужен leaderstats с Coins)
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local SPAWN_INTERVAL = 1.5
local SPAWN_HEIGHT = 80
local AREA_SIZE = 100 -- квадрат вокруг начала координат
local COIN_VALUE = 1
local LIFETIME = 30

local function spawnCoin()
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 3, 3)
	coin.Color = Color3.fromRGB(255, 215, 0)
	coin.Material = Enum.Material.Metal
	coin.Position = Vector3.new(
		math.random(-AREA_SIZE / 2, AREA_SIZE / 2),
		SPAWN_HEIGHT,
		math.random(-AREA_SIZE / 2, AREA_SIZE / 2)
	)
	coin.Orientation = Vector3.new(0, 0, 90)
	coin.CanCollide = false
	coin.Parent = workspace

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins")
		if not coins then
			return
		end
		collected = true
		coins.Value += COIN_VALUE
		coin:Destroy()
	end)

	Debris:AddItem(coin, LIFETIME)
end

while true do
	spawnCoin()
	task.wait(SPAWN_INTERVAL)
end

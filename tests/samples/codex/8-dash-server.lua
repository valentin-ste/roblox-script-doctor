-- request: 8. Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: Script в ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dashEvent = ReplicatedStorage:FindFirstChild("DashEvent")
if not dashEvent then
	dashEvent = Instance.new("RemoteEvent")
	dashEvent.Name = "DashEvent"
	dashEvent.Parent = ReplicatedStorage
end

local DASH_COOLDOWN = 1
local DASH_SPEED = 70
local lastDash = {}

dashEvent.OnServerEvent:Connect(function(player, direction)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		return
	end

	local now = os.clock()
	if lastDash[player.UserId] and now - lastDash[player.UserId] < DASH_COOLDOWN then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.1 then
		return
	end

	lastDash[player.UserId] = now
	flatDirection = flatDirection.Unit

	root.AssemblyLinearVelocity = Vector3.new(
		flatDirection.X * DASH_SPEED,
		root.AssemblyLinearVelocity.Y,
		flatDirection.Z * DASH_SPEED
	)
end)

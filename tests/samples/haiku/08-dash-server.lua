-- request: Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: Script в ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dashEvent = Instance.new("RemoteEvent")
dashEvent.Name = "Dash"
dashEvent.Parent = ReplicatedStorage

local DASH_SPEED = 80
local COOLDOWN = 1.5
local lastDash = {}

dashEvent.OnServerEvent:Connect(function(player, direction)
	-- проверяем тип и не даём клиенту задавать произвольные значения
	if typeof(direction) ~= "Vector3" then
		return
	end

	local now = os.clock()
	if lastDash[player] and now - lastDash[player] < COOLDOWN then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- берём только горизонтальное направление; если игрок стоит на месте, рывок вперёд
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if flat.Magnitude < 0.01 then
		return
	end

	lastDash[player] = now
	local vy = root.AssemblyLinearVelocity.Y
	root.AssemblyLinearVelocity = flat.Unit * DASH_SPEED + Vector3.new(0, vy, 0)
end)

Players.PlayerRemoving:Connect(function(player)
	lastDash[player] = nil
end)

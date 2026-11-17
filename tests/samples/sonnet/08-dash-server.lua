-- request: Сделай рывок (dash) по клавише Shift на клиенте с проверкой на сервере.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COOLDOWN = 2
local DASH_FORCE = 80

local dashEvent = Instance.new("RemoteEvent")
dashEvent.Name = "DashEvent"
dashEvent.Parent = ReplicatedStorage

local lastDash = {}

dashEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastDash[player.UserId] and now - lastDash[player.UserId] < COOLDOWN - 0.1 then
		return -- слишком рано, игнорируем
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	lastDash[player.UserId] = now

	local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit

	root:ApplyImpulse(direction * DASH_FORCE * root.AssemblyMass)
end)

Players.PlayerRemoving:Connect(function(player)
	lastDash[player.UserId] = nil
end)

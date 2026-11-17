-- request: Сделай античит, который кикает игрока, если он двигается слишком быстро.
-- placement: Script в ServerScriptService. Это простая проверка, она не защищает от всех читов
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_SPEED = 50 -- студий в секунду по горизонтали (обычная ходьба около 16)
local STRIKES_TO_KICK = 3
local CHECK_INTERVAL = 0.5

local tracker = {}

local function check(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		tracker[player] = nil
		return
	end

	local now = os.clock()
	local data = tracker[player]
	if not data or data.character ~= character then
		tracker[player] = { character = character, pos = root.Position, time = now, strikes = 0 }
		return
	end

	local dt = now - data.time
	if dt < CHECK_INTERVAL then
		return
	end

	local delta = root.Position - data.pos
	local speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt

	if speed > MAX_SPEED then
		data.strikes += 1
		if data.strikes >= STRIKES_TO_KICK then
			player:Kick("Слишком высокая скорость движения")
			return
		end
	else
		data.strikes = math.max(0, data.strikes - 1)
	end

	data.pos = root.Position
	data.time = now
end

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		check(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	tracker[player] = nil
end)

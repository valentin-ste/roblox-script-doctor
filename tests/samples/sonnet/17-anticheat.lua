-- request: Сделай античит, который кикает игрока, если он двигается слишком быстро.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CHECK_INTERVAL = 1
local MAX_SPEED = 60 -- студов в секунду (с запасом на падение и рывки)
local MAX_VIOLATIONS = 3

local data = {} -- [player] = { pos, time, violations }

local function track(player)
	data[player] = { pos = nil, violations = 0 }
end

Players.PlayerAdded:Connect(track)
for _, player in ipairs(Players:GetPlayers()) do
	track(player)
end

Players.PlayerRemoving:Connect(function(player)
	data[player] = nil
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < CHECK_INTERVAL then
		return
	end
	local elapsed = accumulator
	accumulator = 0

	for player, info in pairs(data) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if root and humanoid and humanoid.Health > 0 then
			local pos = root.Position
			if info.pos then
				-- вертикаль не учитываем: падение может быть очень быстрым
				local delta = (pos - info.pos) * Vector3.new(1, 0, 1)
				local speed = delta.Magnitude / elapsed

				if speed > MAX_SPEED then
					info.violations += 1
					warn(player.Name .. " слишком быстрый: " .. math.floor(speed))
					if info.violations >= MAX_VIOLATIONS then
						player:Kick("Обнаружено подозрительное перемещение.")
					end
				else
					info.violations = math.max(0, info.violations - 1)
				end
			end
			info.pos = pos
		else
			-- персонаж умер или загружается: сбрасываем отсчёт (чтобы респавн не считался телепортом)
			info.pos = nil
		end
	end
end)

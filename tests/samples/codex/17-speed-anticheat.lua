-- request: 17. Сделай античит, который кикает игрока, если он двигается слишком быстро.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")

local MAX_HORIZONTAL_SPEED = 80
local SAMPLE_TIME = 0.25

local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if not humanoid or not root then
		return
	end

	task.wait(3)

	local lastPosition = root.Position
	local lastTime = os.clock()

	while player.Parent and character.Parent and humanoid.Health > 0 do
		task.wait(SAMPLE_TIME)

		local now = os.clock()
		local currentPosition = root.Position
		local elapsed = now - lastTime

		local movement = currentPosition - lastPosition
		local horizontalMovement = Vector3.new(movement.X, 0, movement.Z)
		local speed = horizontalMovement.Magnitude / elapsed

		if speed > MAX_HORIZONTAL_SPEED then
			player:Kick("Слишком высокая скорость передвижения")
			break
		end

		lastPosition = currentPosition
		lastTime = now
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(watchCharacter, player, character)
	end)
end)

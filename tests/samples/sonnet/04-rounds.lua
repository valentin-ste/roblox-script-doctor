-- request: Сделай систему раундов: лобби 20 секунд, раунд 2 минуты, потом снова лобби.
-- placement: Script в ServerScriptService. Создайте в Workspace части LobbySpawn и ArenaSpawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOBBY_TIME = 20
local ROUND_TIME = 120
local MIN_PLAYERS = 1

local lobbySpawn = workspace:WaitForChild("LobbySpawn")
local arenaSpawn = workspace:WaitForChild("ArenaSpawn")

local status = Instance.new("StringValue")
status.Name = "RoundStatus"
status.Value = "Lobby"
status.Parent = ReplicatedStorage

local timeLeft = Instance.new("IntValue")
timeLeft.Name = "TimeLeft"
timeLeft.Value = 0
timeLeft.Parent = ReplicatedStorage

local function teleportAll(spawnPart)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = spawnPart.CFrame + Vector3.new(math.random(-5, 5), 4, math.random(-5, 5))
		end
	end
end

local function countdown(seconds)
	for i = seconds, 0, -1 do
		timeLeft.Value = i
		task.wait(1)
	end
end

while true do
	-- лобби
	status.Value = "Lobby"
	countdown(LOBBY_TIME)

	if #Players:GetPlayers() >= MIN_PLAYERS then
		-- раунд
		status.Value = "Round"
		teleportAll(arenaSpawn)
		countdown(ROUND_TIME)

		-- возврат в лобби
		status.Value = "Lobby"
		teleportAll(lobbySpawn)
	end
end

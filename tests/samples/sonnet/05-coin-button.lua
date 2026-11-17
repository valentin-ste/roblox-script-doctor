-- request: Сделай кнопку, которая при касании даёт игроку 10 монет, но не чаще раза в 5 секунд.
-- placement: Script внутри Part (кнопки) в Workspace. Нужен leaderstats с Coins.
local Players = game:GetService("Players")

local button = script.Parent
local REWARD = 10
local COOLDOWN = 5

local lastUse = {} -- [userId] = os.clock()

button.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	local last = lastUse[player.UserId]
	if last and now - last < COOLDOWN then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		return
	end

	lastUse[player.UserId] = now
	coins.Value += REWARD
end)

Players.PlayerRemoving:Connect(function(player)
	lastUse[player.UserId] = nil
end)

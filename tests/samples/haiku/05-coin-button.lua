-- request: Сделай кнопку, которая при касании даёт игроку 10 монет, но не чаще раза в 5 секунд.
-- placement: Script внутрь Part-кнопки в workspace (нужен leaderstats из задания 1)
local Players = game:GetService("Players")

local part = script.Parent
local COOLDOWN = 5
local REWARD = 10
local lastGiven = {}

part.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then
		return
	end

	local now = os.clock()
	if lastGiven[player] and now - lastGiven[player] < COOLDOWN then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins then
		return
	end

	lastGiven[player] = now
	coins.Value += REWARD
end)

Players.PlayerRemoving:Connect(function(player)
	lastGiven[player] = nil
end)

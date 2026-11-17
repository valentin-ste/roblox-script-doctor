-- request: 5. Сделай кнопку, которая при касании даёт игроку 10 монет, но не чаще раза в 5 секунд.
-- placement: Script внутри Part-кнопки в Workspace
local Players = game:GetService("Players")

local button = script.Parent
local cooldowns = {}

button.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)

	if not player or cooldowns[player.UserId] then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")

	if not coins then
		return
	end

	cooldowns[player.UserId] = true
	coins.Value += 10

	task.delay(5, function()
		cooldowns[player.UserId] = nil
	end)
end)

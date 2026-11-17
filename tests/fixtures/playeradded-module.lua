-- Fixture: a ModuleScript connects PlayerAdded whenever it is first required.
local Players = game:GetService("Players")
local Leaderboard = {}

Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players@bug
	Leaderboard[player] = 0
end)

return Leaderboard

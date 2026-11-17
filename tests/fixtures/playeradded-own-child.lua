-- Fixture: waiting for the script's own child does not pause it, so this stays advice.
local Players = game:GetService("Players")
local config = script:WaitForChild("Config")

Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players@advice
	print(player, config)
end)

-- Fixture: a client module (say, in StarterPlayerScripts) that never mentions LocalPlayer.
-- The plugin knows the kind from where the script lives; no finding expected.
--# scriptKind: client
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	print(player.Name, "joined")
end)

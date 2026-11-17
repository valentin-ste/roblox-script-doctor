-- Fixture: on the client PlayerAdded is used for other players; no finding expected.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

Players.PlayerAdded:Connect(function(player)
	print(player.Name, "joined", localPlayer.Name)
end)

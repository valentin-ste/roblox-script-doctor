-- Fixture: PlayerAdded connected after code that can pause the script.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players@bug
	print(player, remotes)
end)

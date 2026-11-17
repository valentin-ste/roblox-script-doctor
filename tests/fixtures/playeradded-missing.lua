-- Fixture: PlayerAdded without handling players who are already in the game.
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
end)

-- GetPlayers inside BindToClose or a repeating loop does not count.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		print(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			print(player)
		end
	end
end)

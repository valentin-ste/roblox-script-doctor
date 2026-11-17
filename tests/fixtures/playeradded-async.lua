-- Fixture: a DataStore request above the connection pauses the script, even inside pcall.
local Players = game:GetService("Players")
local store = game:GetService("DataStoreService"):GetDataStore("Settings")
local ok, settings = pcall(function()
	return store:GetAsync("settings")
end)

Players.PlayerAdded:Connect(function(player) --! playeradded-no-existing-players@bug
	print(player, ok, settings)
end)

-- Fixture: DataStore without pcall, no BindToClose.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Fixture")

local function load(player)
	local coins = store:GetAsync(player.UserId) or 0 --! datastore-no-pcall
	return coins
end

local function save(player)
	store:SetAsync(player.UserId, 5) --! datastore-no-pcall
end

local function safeSave(player)
	local ok, err = pcall(function()
		store:UpdateAsync(player.UserId, function(old)
			return (old or 0) + 1
		end)
	end)
	return ok, err
end

for _, player in Players:GetPlayers() do
	load(player)
end
Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(player) --! datastore-no-bindtoclose
	save(player)
	safeSave(player)
end)

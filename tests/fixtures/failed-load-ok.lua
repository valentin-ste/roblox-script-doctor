-- Fixture: correct ways to remember a failed load. No findings expected in this file.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Fixture")
local data = {}
local loaded = {}

-- the flag is stored directly
local function loadA(player)
	local ok, saved = pcall(function()
		return store:GetAsync("a" .. player.UserId)
	end)
	loaded[player] = ok
	data[player] = saved
end

-- the flag is stored as an attribute
local function loadB(player)
	local ok, saved = pcall(function()
		return store:GetAsync("b" .. player.UserId)
	end)
	if not ok then
		warn("load failed", saved)
	end
	player:SetAttribute("DataLoaded", ok)
end

-- the flag is stored through true / false
local function loadC(player)
	local ok, saved = pcall(function()
		return store:GetAsync("c" .. player.UserId)
	end)
	if ok then
		data[player] = saved
		loaded[player] = true
	else
		loaded[player] = false
	end
end

-- the player is removed when the load fails
local function loadD(player)
	local ok, saved = pcall(function()
		return store:GetAsync("d" .. player.UserId)
	end)
	if not ok then
		player:Kick("Could not load your data, please rejoin.")
		return
	end
	data[player] = saved
end

-- leaves before the stats exist, so there is nothing to save later
local function loadE(player)
	local ok, saved = pcall(function()
		return store:GetAsync("e" .. player.UserId)
	end)
	if not ok then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	data[player] = saved
end

-- the caller gets the flag
local function loadF(player)
	local ok, saved = pcall(function()
		return store:GetAsync("f" .. player.UserId)
	end)
	return ok, saved
end

-- load and save in the same function (daily reward style): nothing is overwritten later
local function daily(player)
	local ok, last = pcall(function()
		return store:GetAsync("day" .. player.UserId)
	end)
	if ok and last ~= 1 then
		pcall(function()
			store:SetAsync("day" .. player.UserId, 1)
		end)
	end
end

local function save(player)
	if not loaded[player] then
		return
	end
	for _, prefix in { "a", "b", "c", "d", "e", "f" } do
		pcall(function()
			store:SetAsync(prefix .. player.UserId, data[player])
		end)
	end
end

for _, player in Players:GetPlayers() do
	loadA(player)
end
Players.PlayerAdded:Connect(function(player)
	loadA(player)
	loadB(player)
	loadC(player)
	loadD(player)
	loadE(player)
	loadF(player)
	daily(player)
end)
Players.PlayerRemoving:Connect(save)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

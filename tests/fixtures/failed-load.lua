-- Fixture: a failed DataStore load that is forgotten, so a later save overwrites real data.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Fixture")
local data = {}

-- Bug: the result of pcall is only used to skip applying the data.
local function loadA(player)
	local ok, saved = pcall(function()
		return store:GetAsync("a" .. player.UserId) --! datastore-save-after-failed-load
	end)
	if ok and saved then
		data[player] = saved
	end
end

-- Bug: the result of pcall is thrown away.
local function loadB(player)
	local saved = 0
	pcall(function()
		saved = store:GetAsync("b" .. player.UserId) or 0 --! datastore-save-after-failed-load
	end)
	data[player] = saved
end

-- Bug: failure silently becomes a default value.
local function loadC(player)
	local ok, saved = pcall(function()
		return store:GetAsync("c" .. player.UserId) --! datastore-save-after-failed-load
	end)
	data[player] = (ok and tonumber(saved)) or 0
end

-- Bug: warns and leaves, but the stats were created elsewhere and will still be saved.
local function loadD(player)
	local ok, saved = pcall(function()
		return store:GetAsync("d" .. player.UserId) --! datastore-save-after-failed-load
	end)
	if not ok then
		warn("load failed", saved)
		return
	end
	data[player] = saved
end

-- Bug: xpcall is no different from pcall here.
local function loadE(player)
	local ok, saved = xpcall(function()
		return store:GetAsync("e" .. player.UserId) --! datastore-save-after-failed-load
	end, warn)
	if ok and saved then
		data[player] = saved
	end
end

local function save(player)
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
end)
Players.PlayerRemoving:Connect(save)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

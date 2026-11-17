-- Fixture: correct code that looks suspicious. No findings expected anywhere in this file.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Fixture")

-- in a comment: wait(1), spawn(f), loadstring("x"), require(123), part:connect(f), store:GetAsync("k")
--[[ block comment
	wait(5)
	require(1234567)
]]
local text = "use wait(1) or spawn(f); never require(123) or loadstring(code); x:connect(y)"
local long = [[
wait(5)
store:GetAsync("key")
Instance.new("Part", workspace)
]]
local interpolated = `wait({text}) :connect(`

-- a local alias named wait is the author's own function
local wait = task.wait
wait(1)

-- the author's own signal class with lowercase methods
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:connect(handler)
	table.insert(self.handlers, handler)
end
function Signal:destroy()
	table.clear(self.handlers)
end
local signal = Signal.new()
signal:connect(print)
signal:destroy()

local helper = { wait = function() end, spawn = function() end, delay = 5 }
helper.wait()
helper.spawn()

-- DataStore calls protected in different ways
local ok, value = pcall(function()
	return store:GetAsync("key")
end)
local ok2, err = pcall(store.SetAsync, store, "key", 1)
local function saveAll()
	for _, player in Players:GetPlayers() do
		store:SetAsync(tostring(player.UserId), 1)
	end
end
pcall(saveAll)
local function retryAsync(callback)
	for _ = 1, 3 do
		local success, result = pcall(callback)
		if success then
			return result
		end
		task.wait(1)
	end
	return nil
end
local third = retryAsync(function()
	return store:GetAsync("other")
end)

-- if-expressions must not break block tracking
local mode = if ok then "loaded" else if ok2 then "saved" else "none"
local label = if value then tostring(value) elseif third then "third" else "empty"

-- existing players handled, shutdown waits for saves
local function onPlayerAdded(player)
	print(player, mode, label)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	print(player)
end)
game:BindToClose(function()
	pcall(saveAll)
end)

local part = Instance.new("Part")
part.Size = Vector3.new(1, 1, 1)
part.Parent = workspace
part:Destroy()

RunService.Heartbeat:Connect(function() end)
local Module = require(script.Parent.Module)
print(text, long, interpolated, err, Module)

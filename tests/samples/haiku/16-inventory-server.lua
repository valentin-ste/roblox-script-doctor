-- request: Сделай систему инвентаря на 10 слотов с сохранением.
-- placement: Script в ServerScriptService. Создаёт RemoteEvent-ы InventoryUpdate и InventoryRequest в ReplicatedStorage
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SLOT_COUNT = 10
local store = DataStoreService:GetDataStore("Inventory_v1")
local inventories = {}

local updateEvent = Instance.new("RemoteEvent")
updateEvent.Name = "InventoryUpdate"
updateEvent.Parent = ReplicatedStorage

local requestEvent = Instance.new("RemoteEvent")
requestEvent.Name = "InventoryRequest"
requestEvent.Parent = ReplicatedStorage

local function sync(player)
	local inv = inventories[player]
	if inv then
		updateEvent:FireClient(player, inv)
	end
end

-- добавляет предмет в первый свободный слот; для вызова из других скриптов вынесите в ModuleScript
local function addItem(player, itemName)
	local inv = inventories[player]
	if not inv then
		return false
	end
	for i = 1, SLOT_COUNT do
		if not inv[i] then
			inv[i] = itemName
			sync(player)
			return true
		end
	end
	return false -- инвентарь полон
end

local function removeSlot(player, slot)
	local inv = inventories[player]
	if not inv or not inv[slot] then
		return
	end
	inv[slot] = false
	sync(player)
end

Players.PlayerAdded:Connect(function(player)
	local inv = {}
	for i = 1, SLOT_COUNT do
		inv[i] = false
	end

	local ok, data = pcall(function()
		return store:GetAsync("Inv_" .. player.UserId)
	end)
	if ok and data then
		for i = 1, SLOT_COUNT do
			inv[i] = data[i] or false
		end
	end
	inventories[player] = inv
end)

requestEvent.OnServerEvent:Connect(sync)

local function save(player)
	local inv = inventories[player]
	if not inv then
		return
	end
	pcall(function()
		store:SetAsync("Inv_" .. player.UserId, inv)
	end)
	inventories[player] = nil
end

Players.PlayerRemoving:Connect(save)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

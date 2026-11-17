-- request: Сделай систему инвентаря на 10 слотов с сохранением.
-- placement: ModuleScript с именем InventoryService в ServerScriptService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("Inventory_v1")

local MAX_SLOTS = 10

local InventoryService = {}
InventoryService.MAX_SLOTS = MAX_SLOTS

local inventories = {} -- [userId] = { [slot] = itemName | false }
local loaded = {}

local function emptyInventory()
	local inv = {}
	for i = 1, MAX_SLOTS do
		inv[i] = false
	end
	return inv
end

function InventoryService.Load(player)
	local inv = emptyInventory()
	local ok, data = pcall(function()
		return store:GetAsync("Player_" .. player.UserId)
	end)

	if ok then
		if type(data) == "table" then
			for i = 1, MAX_SLOTS do
				inv[i] = data[i] or false
			end
		end
		loaded[player.UserId] = true
	else
		warn("Не удалось загрузить инвентарь: " .. tostring(data))
		loaded[player.UserId] = false
	end

	inventories[player.UserId] = inv
	return inv
end

function InventoryService.Save(player)
	local inv = inventories[player.UserId]
	if not inv or not loaded[player.UserId] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, inv)
	end)
	if not ok then
		warn("Не удалось сохранить инвентарь: " .. tostring(err))
	end
end

function InventoryService.GetInventory(player)
	return inventories[player.UserId]
end

-- возвращает true, номер слота при успехе
function InventoryService.AddItem(player, itemName)
	local inv = inventories[player.UserId]
	if not inv then
		return false
	end
	for i = 1, MAX_SLOTS do
		if not inv[i] then
			inv[i] = itemName
			return true, i
		end
	end
	return false -- инвентарь полон
end

function InventoryService.RemoveItem(player, slot)
	local inv = inventories[player.UserId]
	if not inv or not inv[slot] then
		return false
	end
	inv[slot] = false
	return true
end

function InventoryService.Cleanup(player)
	inventories[player.UserId] = nil
	loaded[player.UserId] = nil
end

return InventoryService

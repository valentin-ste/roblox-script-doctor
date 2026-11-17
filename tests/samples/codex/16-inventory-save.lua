-- request: 16. Сделай систему инвентаря на 10 слотов с сохранением.
-- placement: Script в ServerScriptService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local inventoryStore = DataStoreService:GetDataStore("InventoriesV1")
local SLOT_COUNT = 10

local function createInventory(player, savedItems)
	local oldInventory = player:FindFirstChild("Inventory")
	if oldInventory then
		oldInventory:Destroy()
	end

	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = player

	for slotNumber = 1, SLOT_COUNT do
		local slot = Instance.new("StringValue")
		slot.Name = "Slot" .. slotNumber
		slot.Value = type(savedItems) == "table" and (savedItems[slotNumber] or "") or ""
		slot.Parent = inventory
	end
end

local function loadInventory(player)
	local savedItems = nil

	pcall(function()
		savedItems = inventoryStore:GetAsync(player.UserId)
	end)

	if player.Parent then
		createInventory(player, savedItems)
	end
end

local function saveInventory(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then
		return
	end

	local savedItems = {}

	for slotNumber = 1, SLOT_COUNT do
		local slot = inventory:FindFirstChild("Slot" .. slotNumber)
		savedItems[slotNumber] = slot and slot.Value or ""
	end

	pcall(function()
		inventoryStore:SetAsync(player.UserId, savedItems)
	end)
end

Players.PlayerAdded:Connect(loadInventory)
Players.PlayerRemoving:Connect(saveInventory)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveInventory(player)
	end
end)

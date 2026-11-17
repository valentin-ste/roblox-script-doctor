-- request: Сделай систему инвентаря на 10 слотов с сохранением.
-- placement: Script в ServerScriptService (рядом с ModuleScript InventoryService)
local Players = game:GetService("Players")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

Players.PlayerAdded:Connect(function(player)
	InventoryService.Load(player)

	-- пример: выдаём стартовый предмет новому игроку
	local inv = InventoryService.GetInventory(player)
	local empty = true
	for i = 1, InventoryService.MAX_SLOTS do
		if inv[i] then
			empty = false
			break
		end
	end
	if empty then
		InventoryService.AddItem(player, "Wooden Sword")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	InventoryService.Save(player)
	InventoryService.Cleanup(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		InventoryService.Load(player)
	end)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(InventoryService.Save, player)
	end
	task.wait(3)
end)

-- автосохранение
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			InventoryService.Save(player)
		end
	end
end)

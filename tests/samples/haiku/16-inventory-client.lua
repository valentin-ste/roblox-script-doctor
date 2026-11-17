-- request: Сделай систему инвентаря на 10 слотов с сохранением.
-- placement: LocalScript внутрь ScreenGui (StarterGui), в ScreenGui должны быть TextLabel с именами Slot1..Slot10
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local updateEvent = ReplicatedStorage:WaitForChild("InventoryUpdate")
local requestEvent = ReplicatedStorage:WaitForChild("InventoryRequest")
local gui = script.Parent

updateEvent.OnClientEvent:Connect(function(inv)
	for i = 1, 10 do
		local slot = gui:FindFirstChild("Slot" .. i)
		if slot then
			slot.Text = inv[i] or ""
		end
	end
end)

requestEvent:FireServer()

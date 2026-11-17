-- request: Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: LocalScript внутрь TextButton "BuyButton" в ScreenGui, который лежит в StarterGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local button = script.Parent
local buyEvent = ReplicatedStorage:WaitForChild("BuySword")

button.Activated:Connect(function()
	buyEvent:FireServer()
end)

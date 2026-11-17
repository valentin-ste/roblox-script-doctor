-- request: Сделай магазин: кнопка в интерфейсе покупает меч за 100 монет.
-- placement: LocalScript внутри TextButton (ScreenGui > TextButton) в StarterGui
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local button = script.Parent
local buyEvent = ReplicatedStorage:WaitForChild("BuySword")

button.Text = "Купить меч (100)"

button.MouseButton1Click:Connect(function()
	buyEvent:FireServer()
end)
